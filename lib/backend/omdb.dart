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
}
