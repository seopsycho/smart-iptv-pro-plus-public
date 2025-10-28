import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';

class Settings {
  ViewType defaultView;
  bool refreshOnStart;
  bool showLivestreams;
  bool showMovies;
  bool showSeries;
  String tmdbApiKey;
  String metadataProvider; // 'omdb' (default) or 'tmdb'
  Settings(
      {this.defaultView = ViewType.all,
      this.refreshOnStart = false,
      this.showLivestreams = true,
      this.showMovies = true,
      this.showSeries = true,
      this.tmdbApiKey = "",
      this.metadataProvider = "omdb"});

  List<MediaType> getMediaTypes() {
    return [
      if (showLivestreams) MediaType.livestream,
      if (showMovies) MediaType.movie,
      if (showSeries) MediaType.serie
    ];
  }
}
