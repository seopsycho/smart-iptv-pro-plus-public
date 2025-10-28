import 'dart:convert';
import 'package:http/http.dart' as http;

class OmdbApi {
  static const String _apiKey = 'c27281be';
  static const String _baseUrl = 'https://www.omdbapi.com/';
  static final Map<String, String?> _posterCache = {};

  static Future<String?> getPosterByTitle(String title) async {
    final key = title.toLowerCase().trim();
    if (_posterCache.containsKey(key)) return _posterCache[key];
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        't': title,
        'apikey': _apiKey,
      });
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        _posterCache[key] = null;
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['Response'] == 'True' && json['Poster'] != null && json['Poster'] != 'N/A') {
        final poster = json['Poster'] as String;
        _posterCache[key] = poster;
        return poster;
      }
    } catch (_) {}
    _posterCache[key] = null;
    return null;
  }

  static Future<OmdbDetails?> getDetailsByTitle(String title) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        't': title,
        'apikey': _apiKey,
        'plot': 'full',
      });
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['Response'] != 'True') return null;
      final runtimeStr = (json['Runtime'] as String?) ?? '';
      final minutes = runtimeStr.toLowerCase().contains('min')
          ? int.tryParse(runtimeStr.split(' ').first)
          : null;
      return OmdbDetails(
        title: json['Title'] ?? title,
        year: int.tryParse((json['Year'] ?? '').toString().substring(0, 4)),
        duration: minutes,
        genres: ((json['Genre'] as String?) ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        plot: json['Plot'] ?? '',
        rating: double.tryParse((json['imdbRating'] ?? '').toString()),
        poster: (json['Poster'] != null && json['Poster'] != 'N/A')
            ? json['Poster'] as String
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class OmdbDetails {
  final String title;
  final int? year;
  final int? duration;
  final List<String> genres;
  final String plot;
  final double? rating; // 0-10
  final String? poster;
  OmdbDetails({
    required this.title,
    required this.year,
    required this.duration,
    required this.genres,
    required this.plot,
    required this.rating,
    required this.poster,
  });
}
