import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/media_type.dart';

class ChromecastService {
  static const MethodChannel _ch =
      MethodChannel('com.smartiptv.pro/chromecast');

  static Future<bool> load({
    required String url,
    required String title,
    String? contentType,
    String? subtitle,
    String? imageUrl,
    Duration? startPosition,
    MediaType? mediaType,
    Map<String, String>? headers,
  }) async {
    final streamType =
        (mediaType == MediaType.livestream) ? 'live' : 'buffered';
    final pos = startPosition?.inSeconds.toDouble() ?? 0.0;
    final effectiveUrl = await _maybePickHlsVariant(url, headers);
    final ct = contentType ?? _guessContentType(effectiveUrl);
    final args = {
      'url': effectiveUrl,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'startSeconds': pos,
      'contentType': ct,
      'streamType': streamType,
      if (headers != null) 'headers': headers,
    };
    final res = await _ch.invokeMethod('load', args);
    return res == true;
  }

  static Future<void> play() => _ch.invokeMethod('play');
  static Future<void> pause() => _ch.invokeMethod('pause');
  static Future<void> stop() => _ch.invokeMethod('stop');
  static Future<void> seek(Duration position) => _ch.invokeMethod('seek', {
        'positionSeconds': position.inSeconds.toDouble(),
      });

  static String _guessContentType(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'application/x-mpegURL';
    if (u.contains('.mpd')) return 'application/dash+xml';
    if (u.contains('.mp4')) return 'video/mp4';
    if (u.contains('.ts')) return 'video/MP2T';
    return 'application/octet-stream';
  }

  static Future<String> _maybePickHlsVariant(
      String url, Map<String, String>? headers) async {
    try {
      final lower = url.toLowerCase();
      if (!lower.endsWith('.m3u8')) return url;
      final resp = await http.get(Uri.parse(url), headers: headers);
      if (resp.statusCode != 200) return url;
      final text = resp.body;
      if (!text.contains('#EXT-X-STREAM-INF')) return url;
      final lines = text.split('\n');
      String? bestUrl;
      int bestScore = -1;
      for (int i = 0; i < lines.length - 1; i++) {
        final l = lines[i].trim();
        if (!l.startsWith('#EXT-X-STREAM-INF')) continue;
        final codecsIdx = l.indexOf('CODECS=');
        String codecs = '';
        if (codecsIdx != -1) {
          final start = l.indexOf('"', codecsIdx);
          final end = l.indexOf('"', start + 1);
          if (start != -1 && end != -1) codecs = l.substring(start + 1, end);
        }
        if (!codecs.contains('avc1')) continue; // prefer H.264
        int score = 0;
        final resIdx = l.indexOf('RESOLUTION=');
        if (resIdx != -1) {
          final comma = l.indexOf(',', resIdx);
          final part = l.substring(
              resIdx + 'RESOLUTION='.length, comma == -1 ? l.length : comma);
          final xIdx = part.indexOf('x');
          if (xIdx != -1) {
            final width = int.tryParse(part.substring(0, xIdx)) ?? 0;
            final height = int.tryParse(part.substring(xIdx + 1)) ?? 0;
            score = width * height;
          }
        }
        final next = lines[i + 1].trim();
        if (next.isEmpty || next.startsWith('#')) continue;
        final variantUrl = _resolveUrl(url, next);
        if (score > bestScore) {
          bestScore = score;
          bestUrl = variantUrl;
        }
      }
      return bestUrl ?? url;
    } catch (_) {
      return url;
    }
  }

  static String _resolveUrl(String master, String child) {
    final childUri = Uri.parse(child);
    if (childUri.hasScheme) return child;
    final base = Uri.parse(master);
    return base.resolveUri(childUri).toString();
  }

  static Future<bool> loadChannel(Channel c,
      {Map<String, String>? headers, Duration? start}) async {
    if (c.url == null || c.url!.isEmpty) return false;
    return load(
      url: c.url!,
      title: c.name,
      contentType: _guessContentType(c.url!),
      imageUrl: c.image,
      startPosition: start,
      mediaType: c.mediaType,
      headers: headers,
    );
  }
}
