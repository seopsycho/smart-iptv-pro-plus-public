import 'dart:convert';

import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_preserve.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/xtream_types.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:http/http.dart' as http;

const String getLiveStreams = "get_live_streams";
const String getVods = "get_vod_streams";
const String getSeries = "get_series";
const String getSeriesInfo = "get_series_info";
const String getSeriesCategories = "get_series_categories";
const String getLiveStreamCategories = "get_live_categories";
const String getVodCategories = "get_vod_categories";
const String liveStreamExtension = "ts";

Future<void> getXtream(Source source, bool wipe,
    [void Function(String, bool)? onProgress]) async {
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
      statements = [];
  List<ChannelPreserve>? preserve;
  statements.add(Sql.getOrCreateSourceByName(source));
  if (wipe) {
    preserve = await Sql.getChannelsPreserve(source.id!);
    statements.add(Sql.wipeSource(source.id!));
  }
  source.urlOrigin = Uri.parse(source.url!).origin;
  onProgress?.call("Checking server status", false);
  await getXtreamHttpData(getLiveStreams, source);
  onProgress?.call("Checking server status", true);

  onProgress?.call("Fetching live streaming categories", false);
  final liveCategoriesJson =
      await getXtreamHttpData(getLiveStreamCategories, source);
  onProgress?.call("Fetching live streaming categories", true);

  onProgress?.call("Fetching live streaming Channels", false);
  final liveStreamsJson = await getXtreamHttpData(getLiveStreams, source);
  onProgress?.call("Fetching live streaming Channels", true);

  onProgress?.call("Fetching live movie categories", false);
  final vodCategoriesJson = await getXtreamHttpData(getVodCategories, source);
  onProgress?.call("Fetching live movie categories", true);

  onProgress?.call("Fetching live films", false);
  final vodsJson = await getXtreamHttpData(getVods, source);
  onProgress?.call("Fetching live films", true);

  onProgress?.call("Fetching live series categories", false);
  final seriesCategoriesJson =
      await getXtreamHttpData(getSeriesCategories, source);
  onProgress?.call("Fetching live series categories", true);

  onProgress?.call("Fetching live series", false);
  final seriesJson = await getXtreamHttpData(getSeries, source);
  onProgress?.call("Fetching live series", true);

  int failCount = 0;
  if (liveStreamsJson != null && liveCategoriesJson != null) {
    try {
      processXtream(
          statements,
          processJsonList(liveStreamsJson, XtreamStream.fromJson),
          processJsonList(liveCategoriesJson, XtreamCategory.fromJson),
          source,
          MediaType.livestream);
    } catch (e) {
      failCount++;
    }
  }
  if (vodsJson != null && vodCategoriesJson != null) {
    try {
      processXtream(
          statements,
          processJsonList(vodsJson, XtreamStream.fromJson),
          processJsonList(vodCategoriesJson, XtreamCategory.fromJson),
          source,
          MediaType.movie);
    } catch (e) {
      failCount++;
    }
  }
  if (seriesJson != null && seriesCategoriesJson != null) {
    try {
      processXtream(
          statements,
          processJsonList(seriesJson, XtreamStream.fromJson),
          processJsonList(seriesCategoriesJson, XtreamCategory.fromJson),
          source,
          MediaType.serie);
    } catch (e) {
      failCount++;
    }
  }
  if (failCount > 1) {
    return;
  }
  onProgress?.call("Fetching Information", false);
  statements.add(Sql.updateGroups());
  if (preserve != null) {
    statements.add(Sql.restorePreserve(preserve));
  }
  await Sql.commitWrite(statements);
  onProgress?.call("Fetching Information", true);
}

List<T> processJsonList<T>(
    List<dynamic> jsonList, T Function(Map<String, dynamic>) fromJson) {
  return jsonList
      .map((json) => fromJson(json as Map<String, dynamic>))
      .toList();
}

Future<dynamic> getXtreamHttpData(String action, Source source,
    [Map<String, String>? extraQueryParams]) async {
  try {
    var url = buildXtreamUrl(source, action, extraQueryParams);
    final response = await http.get(url);
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body);
  } catch (_) {}
  return null;
}

void processXtream(
    List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
        statements,
    List<XtreamStream> streams,
    List<XtreamCategory> cats,
    Source source,
    MediaType mediaType) {
  Map<String, String> catsMap =
      Map.fromEntries(cats.map((x) => MapEntry(x.categoryId, x.categoryName)));
  for (var live in streams) {
    var cname = catsMap[live.categoryId];
    try {
      var channel = xtreamToChannel(live, source, mediaType, cname);
      statements.add(Sql.insertChannel(channel));
    } catch (_) {}
  }
}

Channel xtreamToChannel(XtreamStream stream, Source source,
    MediaType streamType, String? categoryName) {
  return Channel(
      name: stream.name!,
      mediaType: streamType,
      sourceId: -1,
      favorite: false,
      group: categoryName,
      image: stream.streamIcon?.trim() ?? stream.cover?.trim(),
      url: streamType == MediaType.serie
          ? stream.seriesId.toString()
          : getUrl(stream.streamId?.trim(), source, streamType,
              stream.containerExtension),
      streamId: int.tryParse(stream.streamId ?? "") ?? -1);
}

String getUrl(
    String? streamId, Source source, MediaType streamType, String? extension) {
  return "${source.urlOrigin}/${getXtreamMediaTypeStr(streamType)}/${source.username}/${source.password}/$streamId.${extension ?? liveStreamExtension}";
}

String getXtreamMediaTypeStr(MediaType type) {
  switch (type) {
    case MediaType.livestream:
      return "live";
    case MediaType.movie:
      return "movie";
    case MediaType.serie:
      return "series";
    default:
      return "";
  }
}

Uri buildXtreamUrl(Source source, String action,
    [Map<String, String>? extraQueryParams]) {
  var params = {
    'username': source.username,
    'password': source.password,
    'action': action,
  };
  if (extraQueryParams != null) {
    params.addAll(extraQueryParams);
  }
  var url = Uri.parse(source.url!).replace(queryParameters: params);
  return url;
}

Future<void> getEpisodes(Channel channel) async {
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
      statements = [];
  var seriesId = int.parse(channel.url!);
  var source = await Sql.getSourceFromId(channel.sourceId);
  source.urlOrigin = Uri.parse(source.url!).origin;
  var episodes = XtreamSeries.fromJson(await getXtreamHttpData(
          getSeriesInfo, source, {'series_id': seriesId.toString()}))
      .episodes;
  episodes.sort((a, b) {
    int seasonComparison = a.season.compareTo(b.season);
    if (seasonComparison != 0) {
      return seasonComparison;
    }
    return a.episodeNum.compareTo(b.episodeNum);
  });
  for (var episode in episodes) {
    try {
      statements
          .add(Sql.insertChannel(episodeToChannel(episode, source, seriesId)));
    } catch (_) {}
  }
  await Sql.commitWrite(statements);
}

Channel episodeToChannel(XtreamEpisode episode, Source source, int seriesId) {
  return Channel(
      image: episode.info?.movieImage,
      mediaType: MediaType.movie,
      name: episode.title.trim(),
      sourceId: source.id!,
      favorite: false,
      url: getUrl(
          episode.id, source, MediaType.serie, episode.containerExtension),
      seriesId: seriesId);
}
