import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';

class Settings {
  ViewType defaultView;
  int refreshIntervalHours;
  int lastRefreshEpochSec;
  bool showLivestreams;
  bool showMovies;
  bool showSeries;
  String tmdbApiKey;
  String metadataProvider; // 'omdb' (default) or 'tmdb'
  Settings(
      {this.defaultView = ViewType.all,
      this.refreshIntervalHours = 72,
      this.lastRefreshEpochSec = 0,
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

  bool isRefreshDueNow() {
    if (refreshIntervalHours == 0) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (lastRefreshEpochSec == 0) return true;
    return nowSec - lastRefreshEpochSec >= refreshIntervalHours * 3600;
  }
}
