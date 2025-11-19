import 'dart:async';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/download_item.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class DownloadsService {
  static bool _initialized = false;
  static final Map<int, String> _activeTasks = {};
  static final StreamController<DownloadUpdate> _updateController =
      StreamController<DownloadUpdate>.broadcast();

  static Stream<DownloadUpdate> get updates => _updateController.stream;

  static Future<void> init() async {
    if (_initialized) return;

    // Initialize flutter_downloader
    await FlutterDownloader.initialize(
      debug: false, // Set to true for debugging
      ignoreSsl: true, // Ignore SSL certificate errors
    );

    // Listen for updates
    FlutterDownloader.registerCallback(_downloadCallback);

    _initialized = true;
  }

  static Future<void> enqueue(Channel channel) async {
    await init();

    if (channel.id == null || channel.url == null) return;

    // Get downloads directory
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(path.join(directory.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    // Create filename from channel name
    final safeName = channel.name?.replaceAll(RegExp(r'[<>:"/\|?*]'), '_') ??
        'channel_${channel.id}';
    final filename = '$safeName.mp4';
    final filePath = path.join(downloadsDir.path, filename);

    // Mark as pending in database
    await Sql.upsertDownload(
      channelId: channel.id!,
      filePath: filePath,
      status: 0, // pending
      bytes: 0,
      totalBytes: 0,
    );

    try {
      // Create download task
      final taskId = await FlutterDownloader.enqueue(
        url: channel.url!,
        savedDir: downloadsDir.path,
        fileName: filename,
        showNotification: true,
        openFileFromNotification: false,
      );

      if (taskId != null) {
        _activeTasks[channel.id!] = taskId;
      }

      // Update database with task ID
      await Sql.upsertDownload(
        channelId: channel.id!,
        filePath: filePath,
        status: 1, // downloading
        bytes: 0,
        totalBytes: 0,
      );
    } catch (e) {
      // Mark as failed if enqueue fails
      await Sql.updateDownloadStatusReason(
        channel.id!,
        2, // failed
        e.toString(),
      );
    }
  }

  static void setMaxConcurrent(int n) {
    // flutter_downloader handles this automatically
  }

  static Future<void> cancel(int channelId) async {
    final taskId = _activeTasks[channelId];
    if (taskId != null) {
      await FlutterDownloader.cancel(taskId: taskId);
      _activeTasks.remove(channelId);
    }
  }

  static Future<void> cancelAll() async {
    await FlutterDownloader.cancelAll();
    _activeTasks.clear();
  }

  static Future<void> startDownload(Channel channel) async {
    await enqueue(channel);
  }

  static Future<void> removeDownload(int channelId) async {
    await cancel(channelId);
    await Sql.deleteDownload(channelId);
  }

  static Future<void> clearAllDownloads() async {
    await cancelAll();
    await Sql.deleteAllDownloads();
  }

  static Future<List<DownloadItem>> getAllDownloads() async {
    return await Sql.getAllDownloads();
  }

  static Future<DownloadItem?> getDownload(int channelId) async {
    return await Sql.getDownload(channelId);
  }

  // Static callback function for flutter_downloader
  @pragma('vm:entry-point')
  static void _downloadCallback(String id, int status, int progress) {
    // Find channel ID from task ID
    final channelId = _findChannelIdByTaskId(id);
    if (channelId == null) return;

    int dbStatus = 0; // pending
    String? failReason;

    switch (status) {
      case 1: // DownloadTaskStatus.running
        dbStatus = 1; // downloading
        break;
      case 2: // DownloadTaskStatus.complete
        dbStatus = 3; // completed
        break;
      case 3: // DownloadTaskStatus.failed
        dbStatus = 2; // failed
        failReason = 'Download failed';
        break;
      case 4: // DownloadTaskStatus.canceled
        dbStatus = 4; // canceled
        break;
      case 5: // DownloadTaskStatus.paused
        dbStatus = 5; // paused
        break;
      default:
        break;
    }

    // Update database using appropriate method
    if (failReason != null) {
      Sql.updateDownloadStatusReason(channelId, dbStatus, failReason).then((_) {
        // Notify listeners
        _updateController.add(DownloadUpdate(
          channelId: channelId,
          status: dbStatus,
          progress: progress / 100.0,
          failReason: failReason,
        ));
      });
    } else {
      Sql.upsertDownload(
        channelId: channelId,
        filePath: '', // Will be updated when task completes
        status: dbStatus,
        bytes: 0,
        totalBytes: 0,
      ).then((_) {
        // Notify listeners
        _updateController.add(DownloadUpdate(
          channelId: channelId,
          status: dbStatus,
          progress: progress / 100.0,
        ));
      });
    }

    // Clean up active task if complete/failed/canceled
    if (status >= 2) {
      _activeTasks.remove(channelId);
    }
  }

  static int? _findChannelIdByTaskId(String taskId) {
    for (final entry in _activeTasks.entries) {
      if (entry.value == taskId) {
        return entry.key;
      }
    }
    return null;
  }

  static void dispose() {
    _updateController.close();
  }
}

class DownloadUpdate {
  final int channelId;
  final int status;
  final double progress;
  final String? failReason;

  DownloadUpdate({
    required this.channelId,
    required this.status,
    required this.progress,
    this.failReason,
  });
}
