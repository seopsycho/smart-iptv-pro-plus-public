import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DownloadsService {
  static final List<Channel> _queue = [];
  static final Set<int> _activeIds = {};
  static int _active = 0;
  static int _maxConcurrent = 1;
  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r"[^A-Za-z0-9\-_. ]+"), "").trim();
  }

  static Future<File> _targetFileFor(Channel channel) async {
    final dir = await Utils.getDownloadsDir();
    final uri = Uri.tryParse(channel.url ?? "");
    final last =
        uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : null;
    final ext = (last != null && p.extension(last).isNotEmpty)
        ? p.extension(last)
        : ".mp4";
    final base = _sanitize(channel.name.isNotEmpty ? channel.name : "download");
    final fileName = channel.streamId != null
        ? "${base}_${channel.streamId}$ext"
        : "$base$ext";
    return File(p.join(dir, fileName));
  }

  static Future<void> startDownload(Channel channel) async {
    if (channel.id == null || channel.url == null) return;
    final file = await _targetFileFor(channel);
    int existing = 0;
    try {
      if (await file.exists()) {
        existing = await file.length();
      }
    } catch (_) {}
    await Sql.upsertDownload(
      channelId: channel.id!,
      filePath: file.path,
      status: 3,
      bytes: existing,
      totalBytes: existing,
    );
    if (!_queue.any((c) => c.id == channel.id) &&
        !_activeIds.contains(channel.id)) {
      _queue.add(channel);
    }
    _pumpQueue();
  }

  static void setMaxConcurrent(int n) {
    _maxConcurrent = n < 1 ? 1 : n;
    _pumpQueue();
  }

  static void _pumpQueue() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final ch = _queue.removeAt(0);
      if (ch.id == null) {
        continue;
      }
      if (_activeIds.contains(ch.id)) {
        continue;
      }
      _active += 1;
      _activeIds.add(ch.id!);
      unawaited(WakelockPlus.enable());
      unawaited(() async {
        try {
          await Sql.updateDownloadStatus(ch.id!, 0);
        } catch (_) {}
        try {
          await _runDownloadTask(ch);
        } finally {
          _active -= 1;
          _activeIds.remove(ch.id);
          if (_active <= 0) {
            _active = 0;
            try {
              await WakelockPlus.disable();
            } catch (_) {}
          }
          _pumpQueue();
        }
      }());
    }
  }

  static Future<void> _runDownloadTask(Channel channel) async {
    const int maxRetries = 3;
    const Duration connectTimeout = Duration(seconds: 20);
    const Duration inactivity = Duration(seconds: 30);
    int attempt = 0;
    final file = await _targetFileFor(channel);
    while (true) {
      attempt += 1;
      http.Client client = http.Client();
      try {
        int existing = 0;
        try {
          if (await file.exists()) {
            existing = await file.length();
          } else {
            await file.create(recursive: true);
          }
        } catch (_) {}
        final headers = await Sql.getChannelHeaders(channel.id!);
        final req = http.Request('GET', Uri.parse(channel.url!));
        if (headers != null) {
          if (headers.referrer != null)
            req.headers['Referer'] = headers.referrer!;
          if (headers.httpOrigin != null)
            req.headers['Origin'] = headers.httpOrigin!;
          if (headers.userAgent != null)
            req.headers['User-Agent'] = headers.userAgent!;
        }
        if (existing > 0) {
          req.headers['Range'] = 'bytes=' + existing.toString() + '-';
        }
        final resp = await client.send(req).timeout(connectTimeout);
        int received = existing;
        int total = 0;
        final cr = resp.headers['content-range'];
        if (cr != null) {
          final slash = cr.lastIndexOf('/');
          if (slash != -1) {
            final t = int.tryParse(cr.substring(slash + 1).trim());
            if (t != null) total = t;
          }
        } else if (resp.contentLength != null) {
          final cl = resp.contentLength!;
          total = existing > 0 ? existing + cl : cl;
        }
        final sink = file.openWrite(
            mode: existing > 0 ? FileMode.append : FileMode.write);
        final completer = Completer<void>();
        Timer? watchdog;
        late StreamSubscription<List<int>> sub;
        void resetWatchdog() {
          watchdog?.cancel();
          watchdog = Timer(inactivity, () async {
            try {
              await sub.cancel();
            } catch (_) {}
            try {
              await sink.flush();
            } catch (_) {}
            try {
              await sink.close();
            } catch (_) {}
            if (!completer.isCompleted)
              completer.completeError(TimeoutException('inactivity'));
          });
        }

        sub = resp.stream.listen(
          (chunk) async {
            received += chunk.length;
            sink.add(chunk);
            await Sql.updateDownloadProgress(channel.id!, received, total);
            resetWatchdog();
          },
          onError: (e) async {
            try {
              watchdog?.cancel();
            } catch (_) {}
            try {
              await sink.flush();
            } catch (_) {}
            try {
              await sink.close();
            } catch (_) {}
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () async {
            try {
              watchdog?.cancel();
            } catch (_) {}
            try {
              await sink.flush();
            } catch (_) {}
            try {
              await sink.close();
            } catch (_) {}
            await Sql.updateDownloadProgress(
                channel.id!, received, total > 0 ? total : received);
            await Sql.updateDownloadStatus(channel.id!, 1);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
        resetWatchdog();
        await completer.future;
        return;
      } catch (e) {
        if (attempt >= maxRetries) {
          await Sql.updateDownloadStatus(channel.id!, 2);
          return;
        } else {
          final backoff = Duration(seconds: attempt * attempt);
          await Future.delayed(backoff);
        }
      } finally {
        client.close();
      }
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
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    await Sql.deleteAllDownloads();
  }
}
