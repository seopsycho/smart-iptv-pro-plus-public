import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/services/tmdb_service.dart';
import 'package:smart_iptv_pro/backend/omdb.dart';
import 'package:smart_iptv_pro/backend/xtream.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:smart_iptv_pro/models/tmdb_item.dart';
import 'package:smart_iptv_pro/models/xtream_types.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/player.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsPage extends StatefulWidget {
  final Channel channel;
  const DetailsPage({super.key, required this.channel});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  String? poster;
  String? trailerKey;
  TmdbDetails? _tmdbDetails;
  OmdbDetails? _omdbDetails;
  bool _favorite = false;
  bool _episodesLoading = false;
  String? _playlistPlot;
  double? _playlistRating;
  int? _playlistYear;
  int? _playlistDuration; // minutes
  List<String> _playlistGenres = const [];
  Map<int, List<XtreamEpisode>> _episodesBySeason = {};
  int? _selectedSeason;
  Map<int, Channel> _episodeByStreamId = {};
  Source? _source;

  @override
  void initState() {
    super.initState();
    _favorite = widget.channel.favorite;
    _loadArtworkAndTrailer();
    _loadDetails();
    _loadEpisodesIfSeries();
  }

  Future<void> _loadArtworkAndTrailer() async {
    final img = widget.channel.image?.trim();
    final settings = await SettingsService.getSettings();
    // OMDB poster as fallback (we may override later with playlist)
    if ((img == null || img.isEmpty) &&
        (widget.channel.mediaType == MediaType.movie ||
            widget.channel.mediaType == MediaType.serie)) {
      final p = await OmdbApi.getPosterByTitle(widget.channel.name);
      if (mounted) setState(() => poster = p);
    }
    // Always try TMDB trailer if key exists
    if (settings.tmdbApiKey.isNotEmpty) {
      final tmdb = TmdbService(apiKey: settings.tmdbApiKey);
      final tmdbItem = widget.channel.mediaType == MediaType.movie
          ? await tmdb.searchMovie(widget.channel.name)
          : await tmdb.searchSeries(widget.channel.name);
      if (tmdbItem != null) {
        final key = await tmdb.getTrailerYoutubeKey(tmdbItem.id, isSeries: tmdbItem.isSeries);
        if (mounted) setState(() => trailerKey = key);
      }
    }
  }

  Future<void> _loadDetails() async {
    final settings = await SettingsService.getSettings();
    if (settings.metadataProvider == 'tmdb' && settings.tmdbApiKey.isNotEmpty) {
      final tmdb = TmdbService(apiKey: settings.tmdbApiKey);
      final search = widget.channel.mediaType == MediaType.movie
          ? await tmdb.searchMovie(widget.channel.name)
          : await tmdb.searchSeries(widget.channel.name);
      if (search != null) {
        final det = widget.channel.mediaType == MediaType.movie
            ? await tmdb.movieDetails(search.id)
            : await tmdb.seriesDetails(search.id);
        if (mounted) setState(() => _tmdbDetails = det);
      }
    }
    if (_tmdbDetails == null) {
      final omdb = await OmdbApi.getDetailsByTitle(widget.channel.name);
      if (mounted) setState(() => _omdbDetails = omdb);
    }
    // Prefer playlist metadata for movies via get_vod_info
    if (widget.channel.mediaType == MediaType.movie) {
      try {
        final src = await Sql.getSourceFromId(widget.channel.sourceId);
        src.urlOrigin = Uri.parse(src.url!).origin;
        _source = src;
        if (widget.channel.streamId != null && widget.channel.streamId! > 0) {
          final v = await getXtreamHttpData(getVodInfo, src, {
            'vod_id': widget.channel.streamId.toString(),
          });
          if (v is Map && v['info'] is Map) {
            final info = v['info'] as Map;
            final p = (info['plot'] ?? info['description'])?.toString();
            if (p != null && p.trim().isNotEmpty) {
              if (mounted) setState(() => _playlistPlot = p);
            }
            final mi = (info['movie_image'] ?? info['cover'] ?? info['backdrop_path'])?.toString();
            if (mi != null && mi.isNotEmpty) {
              if (mounted) setState(() => poster = mi);
            }
            // Rating / Year / Duration / Genres from playlist
            final ratingStr = info['rating']?.toString();
            final yearStr = (info['year'] ?? info['releaseDate'] ?? info['release_date'])?.toString();
            final durationStr = (info['runtime'] ?? info['duration'] ?? info['duration_minutes'] ?? info['duration_secs'])?.toString();
            final genreStr = info['genre']?.toString();
            double? pr = double.tryParse(ratingStr ?? '');
            int? py;
            if (yearStr != null) {
              final match = RegExp(r"(\\d{4})").firstMatch(yearStr);
              if (match != null) py = int.tryParse(match.group(1)!);
            }
            int? pd;
            if (durationStr != null) {
              // accept minutes or seconds; attempt to parse
              final n = int.tryParse(RegExp(r"(\\d+)").firstMatch(durationStr)?.group(1) ?? '');
              if (n != null) {
                if ((durationStr.toLowerCase().contains('sec') || durationStr.endsWith('s')) && n > 0) {
                  pd = (n / 60).round();
                } else {
                  pd = n;
                }
              }
            }
            final pg = (genreStr != null && genreStr.trim().isNotEmpty)
                ? genreStr.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList()
                : <String>[];
            if (mounted) {
              setState(() {
                _playlistRating = pr;
                _playlistYear = py;
                _playlistDuration = pd;
                _playlistGenres = pg;
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadEpisodesIfSeries() async {
    if (widget.channel.mediaType != MediaType.serie) return;
    setState(() => _episodesLoading = true);
    final sid = int.tryParse(widget.channel.url ?? '');
    if (sid == null) {
      setState(() => _episodesLoading = false);
      return;
    }
    // Persist episodes to DB for history/resume, etc.
    await Error.tryAsync(() async {
      await getEpisodes(widget.channel);
    }, context, null, true, false);
    // Load persisted episodes
    final filters = Filters(
      viewType: ViewType.all,
      mediaTypes: [MediaType.movie],
      seriesId: sid,
      sourceIds: [widget.channel.sourceId],
      page: 1,
    );
    final eps = await Sql.search(filters);
    // Map channel by streamId for quick match
    _episodeByStreamId = {
      for (final c in eps)
        if (c.streamId != null) c.streamId!: c
    };
    // Also fetch Xtream episodes to get season/episode numbers
    final source = await Sql.getSourceFromId(widget.channel.sourceId);
    source.urlOrigin = Uri.parse(source.url!).origin;
    _source = source;
    final info = await getXtreamHttpData(getSeriesInfo, source, {
      'series_id': sid.toString(),
    });
    if (info != null) {
      // Prefer playlist metadata for series if available
      if (info is Map && info['info'] is Map) {
        final m = info['info'] as Map;
        final p = (m['plot'] ?? m['description'])?.toString();
        if (p != null && p.trim().isNotEmpty) {
          _playlistPlot = p;
        }
        final mi = (m['cover'] ?? m['movie_image'] ?? m['backdrop_path'])?.toString();
        if (mi != null && mi.isNotEmpty) {
          poster = mi;
        }
        final ratingStr = m['rating']?.toString();
        final yearStr = (m['year'] ?? m['releaseDate'] ?? m['release_date'])?.toString();
        final durationStr = (m['runtime'] ?? m['duration'] ?? m['duration_minutes'] ?? m['duration_secs'])?.toString();
        final genreStr = m['genre']?.toString();
        double? pr = double.tryParse(ratingStr ?? '');
        int? py;
        if (yearStr != null) {
          final match = RegExp(r"(\\d{4})").firstMatch(yearStr);
          if (match != null) py = int.tryParse(match.group(1)!);
        }
        int? pd;
        if (durationStr != null) {
          final n = int.tryParse(RegExp(r"(\\d+)").firstMatch(durationStr)?.group(1) ?? '');
          if (n != null) {
            if ((durationStr.toLowerCase().contains('sec') || durationStr.endsWith('s')) && n > 0) {
              pd = (n / 60).round();
            } else {
              pd = n;
            }
          }
        }
        final pg = (genreStr != null && genreStr.trim().isNotEmpty)
            ? genreStr.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList()
            : <String>[];
        _playlistRating = pr;
        _playlistYear = py;
        _playlistDuration = pd;
        _playlistGenres = pg;
      }
      final xs = XtreamSeries.fromJson(info).episodes;
      xs.sort((a, b) {
        final sa = int.tryParse(a.season) ?? 0;
        final sb = int.tryParse(b.season) ?? 0;
        if (sa != sb) return sa.compareTo(sb);
        final ea = int.tryParse(a.episodeNum) ?? 0;
        final eb = int.tryParse(b.episodeNum) ?? 0;
        return ea.compareTo(eb);
      });
      _episodesBySeason = {};
      for (final e in xs) {
        final s = int.tryParse(e.season) ?? 0;
        _episodesBySeason.putIfAbsent(s, () => []).add(e);
      }
      _selectedSeason ??= _episodesBySeason.keys.isEmpty
          ? null
          : _episodesBySeason.keys.reduce((a, b) => a < b ? a : b);
    }
    if (mounted) setState(() => _episodesLoading = false);
  }

  Future<void> _toggleFavorite() async {
    await Sql.favoriteChannel(widget.channel.id!, !_favorite);
    if (mounted) setState(() => _favorite = !_favorite);
    widget.channel.favorite = _favorite;
  }

  Future<void> _play(Channel channel) async {
    if (channel.id != null) {
      await Sql.addToHistory(channel.id!);
    }
    // If it's a series, channel points to series meta; prevent direct playback
    if (channel.mediaType == MediaType.serie) {
      await _showEpisodePicker();
      return;
    }
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Player(
                  channel: channel,
                )));
  }

  Future<void> _showEpisodePicker() async {
    if (_episodesLoading) return;
    if (_episodesBySeason.isEmpty) {
      await _loadEpisodesIfSeries();
    }
    if (_episodesBySeason.isEmpty) return;
    _selectedSeason ??= _episodesBySeason.keys.reduce((a, b) => a < b ? a : b);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: (_episodesBySeason.keys.toList()..sort())
                      .map((s) => ChoiceChip(
                            label: Text('Season $s'),
                            selected: _selectedSeason == s,
                            onSelected: (_) => setState(() => _selectedSeason = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                if (_selectedSeason != null)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _episodesBySeason[_selectedSeason]!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final xe = _episodesBySeason[_selectedSeason]![index];
                        final sNum = int.tryParse(xe.season) ?? 0;
                        final eNum = int.tryParse(xe.episodeNum) ?? 0;
                        final prefix = 'S${sNum.toString().padLeft(2, '0')}E${eNum.toString().padLeft(2, '0')}';
                        final titleText = xe.title.trim().isEmpty ? prefix : '$prefix · ${xe.title.trim()}';
                        final ch = _episodeByStreamId[int.tryParse(xe.id) ?? -1];
                        final img = ch?.image ?? xe.info?.movieImage;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 100,
                              height: 56,
                              child: (img?.trim().isNotEmpty ?? false)
                                  ? CachedNetworkImage(imageUrl: img!.trim(), fit: BoxFit.cover)
                                  : Container(color: Theme.of(context).colorScheme.surfaceContainer, child: const Icon(FeatherIcons.image)),
                            ),
                          ),
                          title: Text(titleText, style: Theme.of(context).textTheme.titleSmall),
                          subtitle: (xe.info?.plot != null && xe.info!.plot!.trim().isNotEmpty)
                              ? Text(xe.info!.plot!, maxLines: 2, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(FeatherIcons.play),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (ch != null) {
                                await _play(ch);
                              } else if (_source != null) {
                                final url = getUrl(xe.id, _source!, MediaType.serie, xe.containerExtension);
                                final epChannel = Channel(
                                  name: xe.title.trim().isNotEmpty ? xe.title.trim() : 'Episode ${eNum}',
                                  mediaType: MediaType.movie,
                                  sourceId: widget.channel.sourceId,
                                  favorite: false,
                                  image: img,
                                  url: url,
                                  seriesId: int.tryParse(widget.channel.url ?? ''),
                                  streamId: int.tryParse(xe.id),
                                );
                                // Don't add to history for ad-hoc channel
                                if (!mounted) return;
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => Player(
                                              channel: epChannel,
                                            )));
                              }
                            },
                          ),
                        );
                      },
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (widget.channel.image?.trim().isNotEmpty ?? false) || (poster != null);
    final title = _tmdbDetails?.title ?? _omdbDetails?.title ?? widget.channel.name;
    final year = _playlistYear ?? _omdbDetails?.year ?? _tmdbDetails?.year;
    final duration = _playlistDuration ?? _omdbDetails?.duration ?? _tmdbDetails?.duration;
    final genres = _playlistGenres.isNotEmpty
        ? _playlistGenres
        : (_omdbDetails?.genres ?? _tmdbDetails?.genres ?? const <String>[]);
    final rating = _playlistRating ?? _omdbDetails?.rating ?? _tmdbDetails?.rating;
    final desc = (_playlistPlot != null && _playlistPlot!.trim().isNotEmpty)
        ? _playlistPlot!.trim()
        : ((_omdbDetails?.plot != null && _omdbDetails!.plot.trim().isNotEmpty)
            ? _omdbDetails!.plot
            : (_tmdbDetails?.overview ?? ''));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(FeatherIcons.x),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: (widget.channel.image?.trim().isNotEmpty ?? false)
                              ? widget.channel.image!.trim()
                              : (poster ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 140,
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xB3000000)],
                            )),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                      onPressed: () => _play(widget.channel),
                      icon: const Icon(FeatherIcons.play),
                      label: const Text('Play')),
                  const SizedBox(width: 12),
                  if (trailerKey != null)
                    OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://www.youtube.com/watch?v=$trailerKey');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(FeatherIcons.film),
                        label: const Text('Trailer')),
                  const SizedBox(width: 12),
                  TextButton.icon(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        FeatherIcons.heart,
                        color: _favorite ? const Color(0xFFE50914) : null,
                      ),
                      label: Text(_favorite ? 'Added to watchlist' : 'Add to watchlist')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (rating != null)
                    Row(children: [
                      const Icon(FeatherIcons.star, color: Color(0xFFE50914), size: 20),
                      const SizedBox(width: 6),
                      Text(rating.toStringAsFixed(1)),
                    ]),
                  if (year != null) ...[
                    const SizedBox(width: 16),
                    Text(year.toString()),
                  ],
                  if (duration != null) ...[
                    const SizedBox(width: 16),
                    Text('${duration}m'),
                  ]
                ],
              ),
              const SizedBox(height: 10),
              if (genres.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: genres
                      .map((g) => Chip(
                            label: Text(g),
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                            backgroundColor: Theme.of(context).colorScheme.surface,
                          ))
                      .toList(),
                ),
              const SizedBox(height: 10),
              if (desc.trim().isNotEmpty) Text(desc),
              const SizedBox(height: 20),
              if (widget.channel.mediaType == MediaType.serie) ...[
                Text('Seasons / Episodes', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_episodesLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_episodesBySeason.isEmpty)
                  const Text('No episodes found')
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (_episodesBySeason.keys.toList()..sort())
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text('Season $s'),
                                  selected: _selectedSeason == s,
                                  onSelected: (_) => setState(() => _selectedSeason = s),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedSeason != null)
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _episodesBySeason[_selectedSeason]!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final xe = _episodesBySeason[_selectedSeason]![index];
                        final sNum = int.tryParse(xe.season) ?? 0;
                        final eNum = int.tryParse(xe.episodeNum) ?? 0;
                        final prefix = 'S${sNum.toString().padLeft(2, '0')}E${eNum.toString().padLeft(2, '0')}';
                        final titleText = xe.title.trim().isEmpty ? prefix : '$prefix · ${xe.title.trim()}';
                        final ch = _episodeByStreamId[int.tryParse(xe.id) ?? -1];
                        final img = ch?.image ?? xe.info?.movieImage;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 100,
                              height: 56,
                              child: (img?.trim().isNotEmpty ?? false)
                                  ? CachedNetworkImage(imageUrl: img!.trim(), fit: BoxFit.cover)
                                  : Container(color: Theme.of(context).colorScheme.surfaceContainer, child: const Icon(FeatherIcons.image)),
                            ),
                          ),
                          title: Text(titleText, style: Theme.of(context).textTheme.titleSmall),
                          subtitle: (xe.info?.plot != null && xe.info!.plot!.trim().isNotEmpty)
                              ? Text(xe.info!.plot!, maxLines: 2, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(FeatherIcons.play),
                            onPressed: () async {
                              if (ch != null) {
                                await _play(ch);
                              } else if (_source != null) {
                                final url = getUrl(xe.id, _source!, MediaType.serie, xe.containerExtension);
                                final epChannel = Channel(
                                  name: xe.title.trim().isEmpty ? 'Episode ${eNum}' : xe.title.trim(),
                                  mediaType: MediaType.movie,
                                  sourceId: widget.channel.sourceId,
                                  favorite: false,
                                  image: img,
                                  url: url,
                                  seriesId: int.tryParse(widget.channel.url ?? ''),
                                  streamId: int.tryParse(xe.id),
                                );
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => Player(
                                              channel: epChannel,
                                            )));
                              }
                            },
                          ),
                        );
                      },
                    ),
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class TmdbDetailsPage extends StatefulWidget {
  final TmdbItem item;
  final List<int> sourceIds;
  const TmdbDetailsPage({super.key, required this.item, required this.sourceIds});

  @override
  State<TmdbDetailsPage> createState() => _TmdbDetailsPageState();
}

class _TmdbDetailsPageState extends State<TmdbDetailsPage> {
  String? trailerKey;

  @override
  void initState() {
    super.initState();
    _loadTrailer();
  }

  Future<void> _loadTrailer() async {
    final settings = await SettingsService.getSettings();
    if (settings.tmdbApiKey.isEmpty) return;
    final tmdb = TmdbService(apiKey: settings.tmdbApiKey);
    final key = await tmdb.getTrailerYoutubeKey(widget.item.id, isSeries: widget.item.isSeries);
    if (mounted) setState(() => trailerKey = key);
  }

  Future<void> _findAndOpenStreams() async {
    // Search channels roughly by title and type
    final filters = Filters(
      viewType: ViewType.all,
      useKeywords: true,
      query: widget.item.title,
      mediaTypes: [widget.item.isSeries ? MediaType.serie : MediaType.movie],
      sourceIds: widget.sourceIds,
      page: 1,
    );
    final matches = await Sql.search(filters);
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No streams found for this title')));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DetailsPage(
                  channel: matches.first,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.item.posterUrl != null)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.item.posterUrl!,
                    width: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Text(widget.item.overview),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                      onPressed: _findAndOpenStreams,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Find Streams')),
                  const SizedBox(width: 12),
                  if (trailerKey != null)
                    OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://www.youtube.com/watch?v=$trailerKey');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.movie),
                        label: const Text('Watch Trailer'))
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
