import 'dart:io';
import 'package:smart_iptv_pro/backend/m3u.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/xtream.dart';
import 'package:smart_iptv_pro/memory.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/models/source_type.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Utils {
  static String? _appDir;
  static Future<String> get appDir async {
    _appDir ??= (await getApplicationSupportDirectory()).path;
    return _appDir!;
  }

  static Future<String> getTempPath(String fileName) async {
    final path = await appDir;
    final tempDir = join(path, "temp");
    await Directory(tempDir).create(recursive: true);
    return join(tempDir, fileName);
  }

  static Future<String> getDownloadsDir() async {
    final path = await appDir;
    final dlDir = join(path, "downloads");
    await Directory(dlDir).create(recursive: true);
    return dlDir;
  }

  static Future<void> refreshSource(Source source) async {
    refreshedSeries.clear();
    await processSource(source, true, null);
  }

  static Future<void> processSource(Source source,
      [bool wipe = false, void Function(String, bool)? onProgress]) async {
    switch (source.sourceType) {
      case SourceType.m3u:
        onProgress?.call("Fetching Information", false);
        await processM3U(source, wipe);
        onProgress?.call("Fetching Information", true);
        break;
      case SourceType.m3uUrl:
        onProgress?.call("Fetching Information", false);
        await processM3UUrl(source, wipe);
        onProgress?.call("Fetching Information", true);
        break;
      case SourceType.xtream:
        await getXtream(source, wipe, onProgress);
        break;
    }
  }

  static Future<void> refreshAllSources() async {
    var sources = await Sql.getSources();
    for (var source in sources) {
      await refreshSource(source);
    }
    await SettingsService.updateLastRefreshToNow();
  }
}
