import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _isInitialized = false;

  // Initialize Analytics
  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (Firebase.apps.isEmpty) {
      _isInitialized = true;
      if (kDebugMode) {
        print('Analytics skipped: Firebase not initialized');
      }
      return;
    }
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      await _setUserProperties();
    } catch (e) {
      if (kDebugMode) print('Analytics init failed: $e');
    } finally {
      _isInitialized = true;
    }
  }

  // Getters for access
  static FirebaseAnalytics? get analytics => _analytics;
  static FirebaseAnalyticsObserver? get observer => _observer;
  static bool get isInitialized => _isInitialized;

  // Screen View Tracking
  static Future<void> logScreenView(String screenName, {String? screenClass}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log screen view: $e');
    }
  }

  // App Lifecycle Events
  static Future<void> logAppOpen() async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logAppOpen();
    } catch (e) {
      if (kDebugMode) print('Failed to log app open: $e');
    }
  }

  // User Engagement Events
  static Future<void> logLogin({String? method}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logLogin(loginMethod: method ?? '');
    } catch (e) {
      if (kDebugMode) print('Failed to log login: $e');
    }
  }

  static Future<void> logSignUp({String? method}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logSignUp(signUpMethod: method ?? '');
    } catch (e) {
      if (kDebugMode) print('Failed to log sign up: $e');
    }
  }

  // Content Playback Events
  static Future<void> logChannelPlay({
    required String channelId,
    required String channelName,
    required String sourceType,
    String? category,
    String? sourceName,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'channel_play',
        parameters: <String, Object>{
          'channel_id': channelId,
          'channel_name': channelName,
          'source_type': sourceType,
          if (category != null) 'category': category,
          if (sourceName != null) 'source_name': sourceName,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log channel play: $e');
    }
  }

  static Future<void> logVodPlay({
    required String vodId,
    required String vodTitle,
    required String sourceType,
    String? category,
    String? sourceName,
    int? duration,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'vod_play',
        parameters: <String, Object>{
          'vod_id': vodId,
          'vod_title': vodTitle,
          'source_type': sourceType,
          if (category != null) 'category': category,
          if (sourceName != null) 'source_name': sourceName,
          if (duration != null) 'duration_seconds': duration,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log VOD play: $e');
    }
  }

  static Future<void> logSeriesPlay({
    required String seriesId,
    required String seriesTitle,
    required String seasonId,
    required String episodeId,
    required String sourceType,
    String? sourceName,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'series_play',
        parameters: <String, Object>{
          'series_id': seriesId,
          'series_title': seriesTitle,
          'season_id': seasonId,
          'episode_id': episodeId,
          'source_type': sourceType,
          if (sourceName != null) 'source_name': sourceName,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log series play: $e');
    }
  }

  // Download Events
  static Future<void> logDownloadStart({
    required String contentType,
    required String contentId,
    required String contentTitle,
    String? sourceName,
    int? fileSize,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'download_start',
        parameters: <String, Object>{
          'content_type': contentType, // 'channel', 'vod', 'episode'
          'content_id': contentId,
          'content_title': contentTitle,
          if (sourceName != null) 'source_name': sourceName,
          if (fileSize != null) 'file_size_bytes': fileSize,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log download start: $e');
    }
  }

  static Future<void> logDownloadComplete({
    required String contentType,
    required String contentId,
    required String contentTitle,
    int? fileSize,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'download_complete',
        parameters: <String, Object>{
          'content_type': contentType,
          'content_id': contentId,
          'content_title': contentTitle,
          if (fileSize != null) 'file_size_bytes': fileSize,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log download complete: $e');
    }
  }

  static Future<void> logDownloadFailed({
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String failureReason,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'download_failed',
        parameters: <String, Object>{
          'content_type': contentType,
          'content_id': contentId,
          'content_title': contentTitle,
          'failure_reason': failureReason,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log download failed: $e');
    }
  }

  // Playlist Management Events
  static Future<void> logPlaylistAdd({
    required String sourceType,
    required String sourceName,
    required String urlType,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'playlist_add',
        parameters: <String, Object>{
          'source_type': sourceType,
          'source_name': sourceName,
          'url_type': urlType,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log playlist add: $e');
    }
  }

  static Future<void> logPlaylistRemove({
    required String sourceType,
    required String sourceName,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'playlist_remove',
        parameters: <String, Object>{
          'source_type': sourceType,
          'source_name': sourceName,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log playlist remove: $e');
    }
  }

  static Future<void> logPlaylistRefresh({
    required String sourceType,
    required String sourceName,
    required bool isSuccessful,
    String? errorMessage,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'playlist_refresh',
        parameters: <String, Object>{
          'source_type': sourceType,
          'source_name': sourceName,
          'is_successful': isSuccessful ? 1 : 0,
          if (errorMessage != null) 'error_message': errorMessage,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log playlist refresh: $e');
    }
  }

  // Search Events
  static Future<void> logSearch({
    required String searchTerm,
    String? searchType,
    int? resultCount,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logSearch(
        searchTerm: searchTerm,
      );
      
      // Additional custom search event for more details
      await _analytics!.logEvent(
        name: 'search_details',
        parameters: <String, Object>{
          'search_term': searchTerm,
          if (searchType != null) 'search_type': searchType,
          if (resultCount != null) 'result_count': resultCount,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log search: $e');
    }
  }

  // Settings Events
  static Future<void> logSettingChange({
    required String settingName,
    required String settingValue,
    String? settingCategory,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'setting_change',
        parameters: <String, Object>{
          'setting_name': settingName,
          'setting_value': settingValue,
          if (settingCategory != null) 'setting_category': settingCategory,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log setting change: $e');
    }
  }

  // UI Interaction Events
  static Future<void> logFilterApply({
    required String filterType,
    required String filterValue,
    String? contentType,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'filter_apply',
        parameters: <String, Object>{
          'filter_type': filterType,
          'filter_value': filterValue,
          if (contentType != null) 'content_type': contentType,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log filter apply: $e');
    }
  }

  static Future<void> logViewTypeChange({
    required String viewType,
    required String previousView,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'view_type_change',
        parameters: <String, Object>{
          'view_type': viewType,
          'previous_view': previousView,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log view type change: $e');
    }
  }

  static Future<void> logChannelAction({
    required String action,
    required String channelName,
    String? sourceName,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'channel_action',
        parameters: <String, Object>{
          'action': action, // 'hide_recent', 'hide_all', 'pin', 'unpin'
          'channel_name': channelName,
          if (sourceName != null) 'source_name': sourceName,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log channel action: $e');
    }
  }

  // Casting Events
  static Future<void> logCastStart({
    required String contentType,
    required String contentTitle,
    required String castDevice,
    String? castTechnology, // 'airplay', 'chromecast'
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'cast_start',
        parameters: <String, Object>{
          'content_type': contentType,
          'content_title': contentTitle,
          'cast_device': castDevice,
          if (castTechnology != null) 'cast_technology': castTechnology,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log cast start: $e');
    }
  }

  static Future<void> logCastEnd({
    required String contentType,
    required String contentTitle,
    required String castDevice,
    int? duration,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'cast_end',
        parameters: <String, Object>{
          'content_type': contentType,
          'content_title': contentTitle,
          'cast_device': castDevice,
          if (duration != null) 'duration_seconds': duration,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log cast end: $e');
    }
  }

  // Error Events
  static Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? context,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'app_error',
        parameters: <String, Object>{
          'error_type': errorType,
          'error_message': errorMessage,
          if (context != null) 'context': context,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log error: $e');
    }
  }

  // Performance Events
  static Future<void> logPerformance({
    required String metricName,
    required dynamic metricValue,
    String? category,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'performance_metric',
        parameters: <String, Object>{
          'metric_name': metricName,
          'metric_value': metricValue is bool ? (metricValue ? 1 : 0) : metricValue,
          if (category != null) 'category': category,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to log performance: $e');
    }
  }

  // Helper method to set user properties
  static Future<void> _setUserProperties() async {
    if (_analytics == null) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _analytics!.setUserProperty(name: 'app_version', value: packageInfo.version);
      await _analytics!.setUserProperty(name: 'app_build_number', value: packageInfo.buildNumber);
    } catch (e) {
      if (kDebugMode) print('Failed to set user properties: $e');
    }
  }

  // Helper method to set user ID if needed
  static Future<void> setUserId(String? userId) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: userId ?? '');
    } catch (e) {
      if (kDebugMode) print('Failed to set user ID: $e');
    }
  }
}
