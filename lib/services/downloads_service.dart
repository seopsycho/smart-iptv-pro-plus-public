import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:background_downloader/background_downloader.dart' as bg;

class DownloadsService {
  static final List<Channel> _queue = [];
  static final Set<int> _activeIds = {};
  static final Map<int, void Function()> _activeCancel = {};
  static final Map<int, String> _bgTaskIds = {};
  static StreamSubscription? _bgUpdatesSub;
  static bool _useBg = true; // prefer background_downloader
  static int _active = 0;
  static int _maxConcurrent = 1;
  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r"[^A-Za-z0-9\-_. ]+"), "").trim();
  }

  static Future<void> init() async {
    if (_bgUpdatesSub != null) return;
    try { await bg.FileDownloader().start(); } catch (_) {}
    _bgUpdatesSub = bg.FileDownloader().updates.listen((update) async {
      try {
        final meta = update.task.metaData ?? '';
        int? channelId;
        if (meta.isNotEmpty) {
          try {
            final m = json.decode(meta);
            if (m is Map && m['channelId'] is int) channelId = m['channelId'] as int;
          } catch (_) {}
        }
        if (channelId == null) return;
        if (update is bg.TaskProgressUpdate) {
          final hasSize = update.hasExpectedFileSize;
          final total = hasSize ? update.expectedFileSize : 0;
          final bytes = hasSize ? (update.progress * update.expectedFileSize).round() : (update.progress >= 0 ? 0 : 0);
          await Sql.updateDownloadProgress(channelId, bytes, total);
          return;
        }
        if (update is bg.TaskStatusUpdate) {
          switch (update.status) {
            case bg.TaskStatus.enqueued:
              // If our pump has started this task, show as running; otherwise queued
              if (_activeIds.contains(channelId)) {
                await Sql.updateDownloadStatus(channelId, 0);
              } else {
                await Sql.updateDownloadStatus(channelId, 3);
              }
              break;
            case bg.TaskStatus.running:
              await Sql.updateDownloadStatus(channelId, 0);
              break;
            case bg.TaskStatus.complete:
              // Mark full size if known
              final total = update.responseHeaders?['content-length'] != null
                  ? int.tryParse(update.responseHeaders!['content-length']!) ?? 0
                  : 0;
              if (total > 0) {
                await Sql.updateDownloadProgress(channelId, total, total);
              }
              await Sql.updateDownloadStatus(channelId, 1);
              break;
            case bg.TaskStatus.failed:
            case bg.TaskStatus.canceled:
            case bg.TaskStatus.notFound:
              await Sql.updateDownloadStatus(channelId, 2);
              break;
            case bg.TaskStatus.waitingToRetry:
            case bg.TaskStatus.paused:
              // keep as running to show spinner
              await Sql.updateDownloadStatus(channelId, 0);
              break;
          }
        }
      } catch (_) {}
    });
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
      status: 3, // queued (shown in UI)
      bytes: existing,
      totalBytes: 0,
    );
    if (!_queue.any((c) => c.id == channel.id) && !_activeIds.contains(channel.id)) {
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
      if (ch.id == null) continue;
      if (_activeIds.contains(ch.id)) continue;
      _active += 1;
      _activeIds.add(ch.id!);
      unawaited(WakelockPlus.enable());
      unawaited(() async {
        try {
          await Sql.updateDownloadStatus(ch.id!, 0); // downloading
        } catch (_) {}
        try {
          if (_useBg) {
            await _runBgDownloadTask(ch);
          } else {
            await _runDownloadTask(ch);
          }
        } finally {
          _active = (_active - 1).clamp(0, 1 << 30);
          _activeIds.remove(ch.id);
          _activeCancel.remove(ch.id);
          if (_active <= 0) {
            try { await WakelockPlus.disable(); } catch (_) {}
          }
          _pumpQueue();
        }
      }());
    }
  }

  static Future<void> _runBgDownloadTask(Channel channel) async {
    final file = await _targetFileFor(channel);
    final headers = await Sql.getChannelHeaders(channel.id!);
    final task = bg.DownloadTask(
      url: channel.url!,
      filename: p.basename(file.path),
      directory: 'downloads',
      baseDirectory: bg.BaseDirectory.applicationSupport,
      updates: bg.Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      metaData: json.encode({'channelId': channel.id}),
      headers: {
        if (headers?.referrer != null) 'Referer': headers!.referrer!,
        if (headers?.httpOrigin != null) 'Origin': headers!.httpOrigin!,
        if (headers?.userAgent != null) 'User-Agent': headers!.userAgent!,
      },
    );
    _bgTaskIds[channel.id!] = task.taskId;
    // Allow cancel
    _activeCancel[channel.id!] = () async {
      try { await bg.FileDownloader().cancelTasksWithIds([task.taskId]); } catch (_) {}
    };
    try {
      final result = await bg.FileDownloader().download(task);
      if (result.status != bg.TaskStatus.complete) {
        try { await _runDownloadTask(channel); return; } catch (_) {}
        await Sql.updateDownloadStatus(channel.id!, 2);
      }
    } catch (_) {
      try { await _runDownloadTask(channel); return; } catch (_) {}
      await Sql.updateDownloadStatus(channel.id!, 2);
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
      final client = http.Client();
      IOSink? sink;
      StreamSubscription<List<int>>? sub;
      Timer? watchdog;
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
          if (headers.referrer != null) req.headers['Referer'] = headers.referrer!;
          if (headers.httpOrigin != null) req.headers['Origin'] = headers.httpOrigin!;
          if (headers.userAgent != null) req.headers['User-Agent'] = headers.userAgent!;
        }
        if (existing > 0) {
          req.headers['Range'] = 'bytes=' + existing.toString() + '-';
        }
        final resp = await client.send(req).timeout(connectTimeout);
        if (resp.statusCode == 416) {
          // Already fully downloaded
          await Sql.updateDownloadProgress(channel.id!, existing, existing);
          await Sql.updateDownloadStatus(channel.id!, 1);
          return;
        }
        final append = existing > 0 && resp.statusCode == 206;
        int received = append ? existing : 0;
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
          total = append ? existing + cl : cl;
        }
        sink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
        final completer = Completer<void>();
        void resetWatchdog() {
          watchdog?.cancel();
          watchdog = Timer(inactivity, () async {
            try { await sub?.cancel(); } catch (_) {}
            try { await sink?.flush(); } catch (_) {}
            try { await sink?.close(); } catch (_) {}
            if (!completer.isCompleted) completer.completeError(TimeoutException('inactivity'));
          });
        }
        sub = resp.stream.listen(
          (chunk) async {
            received += chunk.length;
            sink!.add(chunk);
            await Sql.updateDownloadProgress(channel.id!, received, total);
            resetWatchdog();
          },
          onError: (e) async {
            try { watchdog?.cancel(); } catch (_) {}
            try { await sink?.flush(); } catch (_) {}
            try { await sink?.close(); } catch (_) {}
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () async {
            try { watchdog?.cancel(); } catch (_) {}
            try { await sink?.flush(); } catch (_) {}
            try { await sink?.close(); } catch (_) {}
            await Sql.updateDownloadProgress(channel.id!, received, total > 0 ? total : received);
            await Sql.updateDownloadStatus(channel.id!, 1);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
        // Register cancel handler for this active task
        _activeCancel[channel.id!] = () async {
          try { await sub?.cancel(); } catch (_) {}
          try { await sink?.flush(); } catch (_) {}
          try { await sink?.close(); } catch (_) {}
          try { client.close(); } catch (_) {}
        };
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
        try { watchdog?.cancel(); } catch (_) {}
        try { await sub?.cancel(); } catch (_) {}
        try { await sink?.flush(); } catch (_) {}
        try { await sink?.close(); } catch (_) {}
        client.close();
      }
    }
  }

  static Future<void> cancelDownload(int channelId) async {
    // Remove from queue if present
    _queue.removeWhere((c) => c.id == channelId);
    if (_useBg) {
      try {
        String? tid = _bgTaskIds[channelId];
        if (tid == null) {
          final tasks = await bg.FileDownloader().allTasks();
          for (final t in tasks) {
            try {
              final m = t.metaData;
              if (m != null) {
                final obj = json.decode(m);
                if (obj is Map && obj['channelId'] == channelId) { tid = t.taskId; break; }
              }
            } catch (_) {}
          }
        }
        if (tid != null) {
          await bg.FileDownloader().cancelTasksWithIds([tid]);
        }
      } catch (_) {}
    }
    // Cancel active if running
    final cancel = _activeCancel[channelId];
    if (cancel != null) {
      try { cancel(); } catch (_) {}
    }
    await Sql.updateDownloadStatus(channelId, 2);
    // Continue with remaining queued items
    _pumpQueue();
  }

  static Future<void> removeDownload(int channelId) async {
    // Cancel if active or queued
    await cancelDownload(channelId);
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
    _pumpQueue();
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
    // Cancel any active & clear queue
    for (final entry in _activeCancel.entries) {
      try { entry.value(); } catch (_) {}
    }
    _activeCancel.clear();
    _queue.clear();
    await Sql.deleteAllDownloads();
  }
}
