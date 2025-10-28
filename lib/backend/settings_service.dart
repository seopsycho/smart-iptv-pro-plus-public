import 'dart:collection';

import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

const defaultView = "defaultView";
const refreshOnStart = "refreshOnStart";
const showLivestreams = "showLivestreams";
const showMovies = "showMovies";
const showSeries = "showSeries";
const lastSeenVersion = "lastSeenVersion";
const hasSeenOnboarding = "hasSeenOnboarding";
const tmdbApiKey = "tmdbApiKey";
const metadataProvider = "metadataProvider"; // 'omdb' or 'tmdb'

class SettingsService {
  static Future<Settings> getSettings() async {
    var settingsMap = await Sql.getSettings();
    var settings = Settings();
    var view = settingsMap[defaultView];
    var refresh = settingsMap[refreshOnStart];
    var live = settingsMap[showLivestreams];
    var movies = settingsMap[showMovies];
    var series = settingsMap[showSeries];
    if (view != null) {
      settings.defaultView = ViewType.values[int.parse(view)];
    }
    if (refresh != null) {
      settings.refreshOnStart = int.parse(refresh) == 1;
    }
    if (live != null) {
      settings.showLivestreams = int.parse(live) == 1;
    }
    if (movies != null) {
      settings.showMovies = int.parse(movies) == 1;
    }
    if (series != null) {
      settings.showSeries = int.parse(series) == 1;
    }
    final tmdbFromEnv = dotenv.dotenv.isInitialized
        ? dotenv.dotenv.env['TMDB_API_KEY']
        : null;
    final tmdb = settingsMap[tmdbApiKey] ?? tmdbFromEnv;
    if (tmdb != null && tmdb.isNotEmpty) {
      settings.tmdbApiKey = tmdb;
    }
    final provider = settingsMap[metadataProvider];
    if (provider != null && provider.isNotEmpty) {
      settings.metadataProvider = provider;
    }
    return settings;
  }

  static Future<void> updateSettings(Settings settings) async {
    HashMap<String, String> settingsMap = HashMap();
    settingsMap[defaultView] = settings.defaultView.index.toString();
    settingsMap[refreshOnStart] = (settings.refreshOnStart ? 1 : 0).toString();
    settingsMap[showLivestreams] =
        (settings.showLivestreams ? 1 : 0).toString();
    settingsMap[showMovies] = (settings.showMovies ? 1 : 0).toString();
    settingsMap[showSeries] = (settings.showSeries ? 1 : 0).toString();
    settingsMap[tmdbApiKey] = settings.tmdbApiKey;
    settingsMap[tmdbApiKey] = settings.tmdbApiKey;
    settingsMap[metadataProvider] = settings.metadataProvider;
    await Sql.updateSettings(settingsMap);
  }

  static Future<void> updateLastSeenVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    HashMap<String, String> lastSeenMap = HashMap();
    lastSeenMap[lastSeenVersion] = packageInfo.version;
    await Sql.updateSettings(lastSeenMap);
  }

  static Future<String?> shouldShowWhatsNew() async {
    final String version = (await PackageInfo.fromPlatform()).version;
    return (await Sql.getSettings())[lastSeenVersion] != version
        ? version
        : null;
  }

  static Future<void> setHasSeenOnboarding() async {
    HashMap<String, String> map = HashMap();
    map[hasSeenOnboarding] = "1";
    await Sql.updateSettings(map);
  }

  static Future<bool> getHasSeenOnboarding() async {
    final settingsMap = await Sql.getSettings();
    return settingsMap[hasSeenOnboarding] == "1";
  }
}
