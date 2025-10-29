import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/models/channel.dart';

class DownloadsService {
  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r"[^A-Za-z0-9\-_. ]+"), "").trim();
  }

  static Future<File> _targetFileFor(Channel channel) async {
    final dir = await Utils.getDownloadsDir();
    final uri = Uri.tryParse(channel.url ?? "");
    final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : null;
    final ext = (last != null && p.extension(last).isNotEmpty) ? p.extension(last) : ".mp4";
    final base = _sanitize(channel.name.isNotEmpty ? channel.name : "download");
    final fileName = channel.streamId != null ? "${base}_${channel.streamId}$ext" : "$base$ext";
    return File(p.join(dir, fileName));
  }

  static Future<void> startDownload(Channel channel) async {
    if (channel.id == null || channel.url == null) return;
    final headers = await Sql.getChannelHeaders(channel.id!);
    final uri = Uri.parse(channel.url!);
    final req = http.Request('GET', uri);
    if (headers != null) {
      if (headers.referrer != null) req.headers['Referer'] = headers.referrer!;
      if (headers.httpOrigin != null) req.headers['Origin'] = headers.httpOrigin!;
      if (headers.userAgent != null) req.headers['User-Agent'] = headers.userAgent!;
    }
    final file = await _targetFileFor(channel);
    final client = http.Client();
    late http.StreamedResponse resp;
    try {
      await Sql.upsertDownload(
        channelId: channel.id!,
        filePath: file.path,
        status: 0,
        bytes: 0,
        totalBytes: 0,
      );
      resp = await client.send(req);
      final total = resp.contentLength ?? 0;
      final sink = file.openWrite();
      int received = 0;
      final StreamSubscription<List<int>> sub = resp.stream.listen(
        (chunk) async {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            await Sql.updateDownloadProgress(channel.id!, received, total);
          } else {
            await Sql.updateDownloadProgress(channel.id!, received, received);
          }
        },
        onError: (e) async {
          await sink.flush();
          await sink.close();
          await Sql.updateDownloadStatus(channel.id!, 2);
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          await Sql.updateDownloadProgress(channel.id!, received, total > 0 ? total : received);
          await Sql.updateDownloadStatus(channel.id!, 1);
        },
        cancelOnError: true,
      );
      await sub.asFuture();
    } catch (e) {
      await Sql.updateDownloadStatus(channel.id!, 2);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> removeDownload(int channelId) async {
    final di = await Sql.getDownload(channelId);
    if (di != null) {
      try {
        final f = File(di.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    await Sql.deleteDownload(channelId);
  }

  static Future<void> clearAllDownloads() async {
    try {
      final dirPath = await Utils.getDownloadsDir();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final f in dir.list()) {
          if (f is File) {
            try { await f.delete(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
    await Sql.deleteAllDownloads();
  }
}
