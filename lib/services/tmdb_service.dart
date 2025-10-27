import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:open_tv/models/tmdb_item.dart';

class TmdbService {
  final String apiKey;
  final http.Client client;
  final Duration ttl;

  // simple in-memory cache
  final Map<String, _CacheEntry> _cache = HashMap();

  TmdbService({required this.apiKey, http.Client? client, Duration? ttl})
      : client = client ?? http.Client(),
        ttl = ttl ?? const Duration(minutes: 10);

  Future<List<TmdbItem>> trendingMovies() async {
    return _getList('/trending/movie/day');
  }

  Future<TmdbItem?> searchMovie(String query) async {
    final path = '/search/movie';
    final cacheKey = 'search:movie:$query';
    final cached = _getCache(cacheKey);
    if (cached != null) return cached as TmdbItem?;
    try {
      final uri = _uri(path, {'language': 'en-US', 'query': query});
      final res = await client.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List);
      if (results.isEmpty) return null;
      final m = results.first as Map<String, dynamic>;
      final item = TmdbItem(
        id: m['id'],
        title: m['title'] ?? '',
        overview: m['overview'] ?? '',
        posterUrl: m['poster_path'] != null
            ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
            : null,
        isSeries: false,
      );
      _setCache(cacheKey, item);
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<TmdbItem?> searchSeries(String query) async {
    final path = '/search/tv';
    final cacheKey = 'search:tv:$query';
    final cached = _getCache(cacheKey);
    if (cached != null) return cached as TmdbItem?;
    try {
      final uri = _uri(path, {'language': 'en-US', 'query': query});
      final res = await client.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List);
      if (results.isEmpty) return null;
      final m = results.first as Map<String, dynamic>;
      final item = TmdbItem(
        id: m['id'],
        title: m['name'] ?? '',
        overview: m['overview'] ?? '',
        posterUrl: m['poster_path'] != null
            ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
            : null,
        isSeries: true,
      );
      _setCache(cacheKey, item);
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<List<TmdbItem>> trendingSeries() async {
    return _getList('/trending/tv/day', isSeries: true);
  }

  Future<String?> getTrailerYoutubeKey(int id, {required bool isSeries}) async {
    final path = '/${isSeries ? 'tv' : 'movie'}/$id/videos';
    final key = 'videos:$path';
    final cached = _getCache(key);
    if (cached != null) return cached as String?;
    try {
      final uri = _uri(path, {'language': 'en-US'});
      final res = await client.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      for (final v in (data['results'] as List)) {
        final mv = v as Map<String, dynamic>;
        if ((mv['site'] == 'YouTube') && (mv['type'] == 'Trailer')) {
          _setCache(key, mv['key']);
          return mv['key'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<TmdbItem>> _getList(String path, {bool isSeries = false}) async {
    final key = 'list:$path';
    final cached = _getCache(key);
    if (cached != null) return cached as List<TmdbItem>;
    try {
      final uri = _uri(path, {'language': 'en-US'});
      final res = await client.get(uri);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List).cast<Map<String, dynamic>>();
      final items = results
          .map((m) => TmdbItem(
                id: m['id'],
                title: (isSeries ? (m['name'] ?? m['title']) : (m['title'] ?? m['name'])) ?? '',
                overview: m['overview'] ?? '',
                posterUrl: m['poster_path'] != null
                    ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
                    : null,
                isSeries: isSeries,
              ))
          .toList();
      _setCache(key, items);
      return items;
    } catch (_) {
      return const [];
    }
  }

  Uri _uri(String path, Map<String, String> params) {
    return Uri.parse('https://api.themoviedb.org/3$path')
        .replace(queryParameters: {'api_key': apiKey, ...params});
  }

  dynamic _getCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  void _setCache(String key, dynamic value) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
}
