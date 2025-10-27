import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/services/tmdb_service.dart';
import 'package:open_tv/backend/omdb.dart';
import 'package:open_tv/backend/xtream.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/models/tmdb_item.dart';
import 'package:open_tv/player.dart';
import 'package:open_tv/backend/settings_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadArtworkAndTrailer();
  }

  Future<void> _loadArtworkAndTrailer() async {
    final img = widget.channel.image?.trim();
    final settings = await SettingsService.getSettings();
    // OMDB first for posters when available
    if ((img == null || img.isEmpty) &&
        (widget.channel.mediaType == MediaType.movie ||
            widget.channel.mediaType == MediaType.serie)) {
      final p = await OmdbApi.getPosterByTitle(widget.channel.name);
      if (mounted) setState(() => poster = p);
    }
    // TMDB trailer only when provider is TMDB and key present
    if (settings.metadataProvider == 'tmdb' && settings.tmdbApiKey.isNotEmpty) {
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

  Future<void> _play(Channel channel) async {
    await Sql.addToHistory(channel.id!);
    // If it's a series, channel points to series meta; prevent direct playback
    if (channel.mediaType == MediaType.serie) {
      await Error.tryAsync(() async {
        await getEpisodes(channel);
      }, context, null, true, false);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Home(
                  home: HomeManager(
                      filters: Filters(
                          viewType: ViewType.all,
                          mediaTypes: [MediaType.movie],
                          seriesId: int.tryParse(channel.url ?? ''),
                          sourceIds: [channel.sourceId])))));
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.channel.image?.trim().isNotEmpty ?? false)
        ? widget.channel.image!.trim()
        : poster;
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                      onPressed: () => _play(widget.channel),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play')),
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
              ),
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
