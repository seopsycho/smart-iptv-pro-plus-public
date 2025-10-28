import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_iptv_pro/models/tmdb_item.dart';

class TmdbApi {
  static const String _base = 'https://api.themoviedb.org/3';
  static const String _img = 'https://image.tmdb.org/t/p/w500';

  static Future<List<TmdbItem>> trendingMovies(String apiKey) async {
    final uri = Uri.parse('$_base/trending/movie/day').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'en-US'
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return results
        .map((m) => TmdbItem(
              id: m['id'],
              title: m['title'] ?? m['name'] ?? '',
              overview: m['overview'] ?? '',
              posterUrl:
                  m['poster_path'] != null ? '$_img${m['poster_path']}' : null,
              isSeries: false,
            ))
        .toList();
  }

  static Future<List<TmdbItem>> trendingSeries(String apiKey) async {
    final uri = Uri.parse('$_base/trending/tv/day').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'en-US'
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return results
        .map((m) => TmdbItem(
              id: m['id'],
              title: m['name'] ?? m['title'] ?? '',
              overview: m['overview'] ?? '',
              posterUrl:
                  m['poster_path'] != null ? '$_img${m['poster_path']}' : null,
              isSeries: true,
            ))
        .toList();
  }

  static Future<TmdbItem?> searchMovie(String apiKey, String query) async {
    final uri = Uri.parse('$_base/search/movie').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'en-US',
      'query': query
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List);
    if (results.isEmpty) return null;
    final m = results.first as Map<String, dynamic>;
    return TmdbItem(
      id: m['id'],
      title: m['title'] ?? '',
      overview: m['overview'] ?? '',
      posterUrl: m['poster_path'] != null ? '$_img${m['poster_path']}' : null,
      isSeries: false,
    );
  }

  static Future<TmdbItem?> searchSeries(String apiKey, String query) async {
    final uri = Uri.parse('$_base/search/tv').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'en-US',
      'query': query
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List);
    if (results.isEmpty) return null;
    final m = results.first as Map<String, dynamic>;
    return TmdbItem(
      id: m['id'],
      title: m['name'] ?? '',
      overview: m['overview'] ?? '',
      posterUrl: m['poster_path'] != null ? '$_img${m['poster_path']}' : null,
      isSeries: true,
    );
  }

  static Future<String?> getTrailerYoutubeKey(
      String apiKey, int id, bool isSeries) async {
    final path = isSeries ? 'tv' : 'movie';
    final uri = Uri.parse('$_base/$path/$id/videos')
        .replace(queryParameters: {'api_key': apiKey, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    for (final v in (data['results'] as List)) {
      final mv = v as Map<String, dynamic>;
      if ((mv['site'] == 'YouTube') && (mv['type'] == 'Trailer')) {
        return mv['key'] as String?;
      }
    }
    return null;
  }
}
