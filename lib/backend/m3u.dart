import 'dart:convert';
import 'dart:io';

import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/channel_http_headers.dart';
import 'package:smart_iptv_pro/models/channel_preserve.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:http/http.dart' as http;

final nameRegex = RegExp(r'tvg-name="([^"]*)"');
final nameRegexAlt = RegExp(r'^(.*),([^,\n\r\t]*)$');
final idRegex = RegExp(r'tvg-id="([^"]*)"');
final logoRegex = RegExp(r'tvg-logo="([^"]*)"');
final groupRegex = RegExp(r'group-title="([^"]*)"');
final logoRegex2 = RegExp(r'tvg-logo="?([^",\n\r]*)"?');
final groupRegex2 = RegExp(r'group-title="?([^",\n\r]*)"?');
final httpOriginRegex = RegExp(r'http-origin=(.+)');
final httpReferrerRegex = RegExp(r'http-referrer=(.+)');
final httpUserAgentRegex = RegExp(r'http-user-agent=(.+)');

Future<void> processM3U(Source source, bool wipe, [String? path]) async {
  path ??= source.url;
  List<ChannelPreserve>? preserve;
  var file = File(path!)
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
      statements = [];
  statements.add(Sql.getOrCreateSourceByName(source));
  if (wipe) {
    preserve = await Sql.getChannelsPreserve(source.id!);
    statements.add(Sql.wipeSource(source.id!));
  }
  String? lastLine;
  String? channelLine;
  ChannelHttpHeaders? headers;
  var httpHeadersSet = false;
  final List<String> bufferedUrls = [];
  
  await for (var line in file) {
    final lineUpper = line.toUpperCase();
    final trimmedLine = line.trim();
    
    if (trimmedLine.contains("DITV") || trimmedLine.contains("Зачарован") ||
        (bufferedUrls.any((u) => u.contains("n7b990d24")))) {
      print("DEBUG PARSING: Line: '$trimmedLine'");
      print("DEBUG PARSING: State - channelLine: ${channelLine != null ? 'SET' : 'NULL'}, bufferedUrl: ${bufferedUrls.isNotEmpty ? 'SET' : 'NULL'}");
    }
    
    if (channelLine == null && 
        !lineUpper.startsWith("#") && 
        (trimmedLine.startsWith("http") || 
         trimmedLine.contains(".m3u8") || 
         trimmedLine.contains(".mp4") ||
         trimmedLine.contains("cdn.") ||
         trimmedLine.contains("://"))) {
      bufferedUrls.add(line);
      print("DEBUG PARSING: Detected URL before EXTINF (malformed), buffering: '$trimmedLine'");
      continue;
    }
    
    if (lineUpper.startsWith("#EXTINF")) {
      // Process any pending channel from previous iteration
      if (channelLine != null && lastLine != null && lastLine.trim().isNotEmpty) {
        commitChannel(channelLine, lastLine, httpHeadersSet ? headers : null,
            statements);
      }
      
      if (bufferedUrls.isNotEmpty) {
        final useUrl = bufferedUrls.removeLast();
        print("DEBUG PARSING: Using buffered URL for EXTINF: '$useUrl'");
        lastLine = useUrl;
      } else {
        lastLine = null;
      }
      
      channelLine = line;
      httpHeadersSet = false;
      headers = null;
    } else if (lineUpper.startsWith("#EXTVLCOPT")) {
      headers ??= ChannelHttpHeaders();
      if (setChannelHeaders(line, headers)) {
        httpHeadersSet = true;
      }
    } else if (lineUpper.startsWith("#EXTGRP")) {
      // Ignore standalone group lines; handled via EXTINF parsing
      continue;
    } else if (channelLine != null && lastLine == null) {
      // This is the line immediately after EXTINF - could be continuation or URL
      if (trimmedLine.isEmpty) {
        // Empty line, skip it
        continue;
      }
      
      // Check if this looks like a URL (starts with http, contains .m3u8, or looks like a stream URL)
      final isUrl = trimmedLine.startsWith("http") || 
                   trimmedLine.contains(".m3u8") || 
                   trimmedLine.contains(".mp4") ||
                   trimmedLine.contains("cdn.") ||
                   trimmedLine.contains("://");
      
      if (!isUrl) {
        // This is a continuation of the channel name
        channelLine = channelLine + line;
        print("DEBUG PARSING: Detected split channel name, joined: '$channelLine'");
        
        // Check if there's more continuation on the same line (after #EXTGRP)
        if (trimmedLine.contains("#EXTGRP:")) {
          final parts = trimmedLine.split("#EXTGRP:");
          if (parts.length > 1 && parts[0].trim().isNotEmpty) {
            // The part before #EXTGRP is the continuation of the name
            final nameContinuation = parts[0].trim();
            if (nameContinuation.isNotEmpty) {
              channelLine = channelLine.substring(0, channelLine.length - line.length) + 
                           line.substring(0, line.indexOf("#EXTGRP:")).trim();
              print("DEBUG PARSING: Extracted name continuation before #EXTGRP: '$channelLine'");
            }
          }
        }
      } else {
        // This is the URL
        lastLine = line;
      }
    } else {
      // Only consider non-metadata lines as URL candidates
      if (!lineUpper.startsWith("#")) {
        lastLine = line;
      }
    }
  }
  
  // Process any remaining channel
  if (channelLine != null && lastLine != null && lastLine.trim().isNotEmpty) {
    commitChannel(channelLine, lastLine, httpHeadersSet ? headers : null, statements);
  }
  statements.add(Sql.updateGroups());
  if (preserve != null) {
    statements.add(Sql.restorePreserve(preserve));
  }
  await Sql.commitWrite(statements);
}

void commitChannel(
    String l1,
    String last,
    ChannelHttpHeaders? headers,
    List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
        statements) {
  bool isValidUrl(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('rtmp://') ||
        t.startsWith('rtsp://') ||
        t.startsWith('udp://') ||
        t.startsWith('mms://');
  }
  if (!isValidUrl(last)) {
    print("DEBUG PARSING: Skipping channel due to invalid URL: '${last.trim()}'");
    return;
  }
  var channel = getChannelFromLines(l1, last);
  if (channel == null) return;
  statements.add(Sql.insertChannel(channel));
  if (headers != null) {
    statements.add(Sql.insertChannelHeaders(headers));
  }
}

MediaType getMediaType(String url) {
  if (url.endsWith('.mp4') || url.endsWith('.mkv')) {
    return MediaType.movie;
  }
  return MediaType.livestream;
}

Channel? getChannelFromLines(String l1, String last) {
  var name = getName(l1)?.trim();
  if (name == null) {
    final preview = l1.replaceAll('\n', ' ').substring(0, l1.length > 120 ? 120 : l1.length);
    print("DEBUG PARSING: Skipping EXTINF with missing name. Line: '$preview'");
    return null;
  }
  // Debug: log when we see a target channel name during parsing
  if (name.toLowerCase().contains("зачарованные")) {
    print("DEBUG PARSING: Found target channel in M3U: '$name'");
    print("DEBUG PARSING: Full EXTINF line: $l1");
    print("DEBUG PARSING: URL: $last");
  }
  // Also log any channel with Cyrillic characters for inspection
  if (name.contains(RegExp(r'[а-яё]'))) {
    print("DEBUG PARSING: Cyrillic channel found: '$name'");
  }
  String normalizeText(String s) {
    return s
        .replaceAll('\u00A0', ' ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll(RegExp("[‘’]"), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  String? getAttr(String s, RegExp quoted, RegExp alt) {
    final m1 = quoted.firstMatch(s);
    var v = m1?.group(1) ?? alt.firstMatch(s)?.group(1);
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : normalizeText(t);
  }
  return Channel(
      name: normalizeText(name),
      group: getAttr(l1, groupRegex, groupRegex2),
      image: getAttr(l1, logoRegex, logoRegex2),
      favorite: false,
      mediaType: getMediaType(last),
      sourceId: -1,
      url: last);
}

String? getName(String l1) {
  var display = nameRegexAlt.firstMatch(l1)?[2];
  var name = (display != null && display.trim().isNotEmpty)
      ? display
      : nameRegex.firstMatch(l1)?[1];
  name ??= idRegex.firstMatch(l1)?[1];
  
  if (name != null) {
    // First, remove any #EXTGRP: content that might be inline
    if (name.contains("#EXTGRP:")) {
      name = name.split("#EXTGRP:")[0];
    }
    
    name = name
        .replaceAll('\u00A0', ' ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp('[“”]'), '"')
        .replaceAll(RegExp("[‘’]"), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Handle special case where name might be incomplete due to line breaks
    // Look for patterns like "Play-x " followed by continuation
    if (name.endsWith(' ') && l1.contains(',')) {
      // Extract the part after comma and check if it contains just whitespace
      final afterComma = l1.split(',').skip(1).join(',');
      if (afterComma.trim().isEmpty || afterComma.contains(RegExp(r'^\s*$'))) {
        // The name continues on the next line, but we've already joined it
        // So we need to extract the full name from the complete line
        final fullMatch = RegExp(r',(.+?)(?:#EXTGRP:|$)').firstMatch(l1);
        if (fullMatch != null) {
          name = fullMatch[1]?.replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
    }
    
    // Final cleanup - ensure we don't have trailing #EXTGRP content
    if (name != null && name.contains("#EXTGRP:")) {
      name = name.split("#EXTGRP:")[0].trim();
    }
  }
  
  return name;
}

bool setChannelHeaders(
  String headerLine,
  ChannelHttpHeaders headers,
) {
  final userAgent = httpUserAgentRegex.firstMatch(headerLine)?[1];
  if (userAgent != null) {
    headers.userAgent = userAgent;
    return true;
  }
  final referrer = httpReferrerRegex.firstMatch(headerLine)?[1];
  if (referrer != null) {
    headers.referrer = referrer;
    return true;
  }
  final origin = httpOriginRegex.firstMatch(headerLine)?[1];
  if (origin != null) {
    headers.httpOrigin = origin;
    return true;
  }
  return false;
}

Future<void> processM3UUrl(Source source, bool wipe) async {
  var path = await downloadM3U(source.url!);
  await processM3U(source, wipe, path);
}

Future<String> downloadM3U(String urlStr) async {
  final url = Uri.parse(urlStr);
  final client = http.Client();
  final request = http.Request('GET', url);
  // Add common headers to avoid server-side filtering or variant responses
  request.headers['User-Agent'] =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';
  request.headers['Accept'] = '*/*';
  request.headers['Accept-Language'] = 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7';
  final response = await client.send(request);
  if (response.statusCode != 200) {
    throw Exception('Failed to download file: ${response.statusCode}');
  }
  final path = await Utils.getTempPath("get.m3u");
  final file = File(path);
  final sink = file.openWrite();
  await for (var chunk in response.stream) {
    sink.add(chunk);
  }
  await sink.close();
  // Debug: confirm that the downloaded file contains target strings
  try {
    final content = await file.readAsString();
    final hasTarget = content.toLowerCase().contains('зачарованные');
    print("DEBUG DOWNLOAD: contains 'зачарованные': $hasTarget");
    // Check specifically for DITV channel
    final hasDITV = content.toLowerCase().contains('ditv');
    print("DEBUG DOWNLOAD: contains 'DITV': $hasDITV");
    if (hasDITV) {
      // Find all lines containing DITV for inspection
      final ditvLines = content.split('\n').where((line) => line.toLowerCase().contains('ditv')).toList();
      print("DEBUG DOWNLOAD: DITV lines found: ${ditvLines.length}");
      for (final line in ditvLines.take(5)) {
        print("DEBUG DOWNLOAD: DITV line: $line");
      }
    }
  } catch (_) {}
  client.close();
  return path;
}
