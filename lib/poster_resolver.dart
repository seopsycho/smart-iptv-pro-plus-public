import 'dart:collection';
import 'package:smart_iptv_pro/backend/omdb.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/services/tmdb_service.dart';

class PosterResolver {
  static final Map<int, String?> _cacheById = HashMap();
  static final Map<String, String?> _cacheByTitle = HashMap();

  static Future<String?> resolveBestPoster(Channel c) async {
    // Cache by channel id if available, else by title
    final cacheKeyId = c.id;
    if (cacheKeyId != null && _cacheById.containsKey(cacheKeyId)) {
      return _cacheById[cacheKeyId];
    }
    final titleKey = c.name.toLowerCase().trim();
    if (_cacheByTitle.containsKey(titleKey)) {
      final v = _cacheByTitle[titleKey];
      if (cacheKeyId != null) _cacheById[cacheKeyId] = v;
      return v;
    }

    // 1) OMDB
    String? url = await OmdbApi.getPosterByTitle(c.name);
    if (_isValid(url)) {
      _remember(cacheKeyId, titleKey, url);
      return url;
    }

    // 2) TMDB
    try {
      final settings = await SettingsService.getSettings();
      if (settings.tmdbApiKey.isNotEmpty) {
        final tmdb = TmdbService(apiKey: settings.tmdbApiKey);
        if (c.mediaType == MediaType.serie) {
          final item = await tmdb.searchSeries(c.name);
          url = item?.posterUrl;
        } else if (c.mediaType == MediaType.movie) {
          final item = await tmdb.searchMovie(c.name);
          url = item?.posterUrl;
        }
        if (_isValid(url)) {
          _remember(cacheKeyId, titleKey, url);
          return url;
        }
      }
    } catch (_) {}

    // 3) Fallback to channel image (Xtream/M3U)
    url = c.image?.trim();
    if (_isValid(url)) {
      _remember(cacheKeyId, titleKey, url);
      return url;
    }

    // No image
    _remember(cacheKeyId, titleKey, null);
    return null;
  }

  static bool _isValid(String? url) {
    return url != null && url.trim().isNotEmpty;
  }

  static void _remember(int? id, String titleKey, String? url) {
    _cacheByTitle[titleKey] = url;
    if (id != null) _cacheById[id] = url;
  }
}
