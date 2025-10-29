import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/bottom_nav.dart';
import 'package:smart_iptv_pro/channel_tile.dart';
import 'package:smart_iptv_pro/loading.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/no_push_animation_material_page_route.dart';
import 'package:smart_iptv_pro/models/node.dart';
import 'package:smart_iptv_pro/models/node_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/whats_new_modal.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/settings_view.dart';
import 'package:smart_iptv_pro/select_dialog.dart';
import 'package:smart_iptv_pro/models/id_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_iptv_pro/services/tmdb_service.dart';
import 'package:smart_iptv_pro/models/tmdb_item.dart';
import 'package:smart_iptv_pro/details.dart';
import 'package:smart_iptv_pro/manage_categories.dart';
import 'package:smart_iptv_pro/services/cast_service.dart';
import 'package:smart_iptv_pro/downloads_view.dart';

class Home extends StatefulWidget {
  final HomeManager home;
  final bool refresh;
  final firstLaunch;
  const Home(
      {super.key,
      required this.home,
      this.refresh = false,
      this.firstLaunch = false});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Timer? _debounce;
  bool reachedMax = false;
  final int pageSize = 36;
  List<Channel> channels = [];
  // Feed data
  List<Channel> recentLive = [];
  List<Channel> favoriteTv = [];
  List<Channel> favMovies = [];
  List<Channel> favSeries = [];
  List<TmdbItem> topSeries = [];
  List<TmdbItem> topMovies = [];
  List<Channel> recentMoviesHome = [];
  List<Channel> recentSeriesHome = [];
  // Landing data for Movies/Series
  List<Channel> recentMovies = [];
  List<Channel> recentSeries = [];
  List<Channel> movieCategories = [];
  List<Channel> seriesCategories = [];
  bool searchMode = false;
  int favoritesFilter = 0;
  final FocusNode _focusNode = FocusNode();
  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = false;
  bool blockSettings = false;
  int? previousScroll;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    initializeAsync();
  }

  Future<void> _refreshCategoriesAfterChange() async {
    // Refresh both list/grid as needed without assumptions
    await load(false);
    await loadLandingSections();
  }

  Future<void> _openManageCategories() async {
    final sourceIds = widget.home.filters.sourceIds ?? [];
    final mediaTypes = widget.home.filters.mediaTypes ?? [];
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManageCategoriesPage(
              sourceIds: sourceIds,
              mediaTypes: mediaTypes,
            )));
    if (!mounted) return;
    await _refreshCategoriesAfterChange();
  }

  void _showCategoryOptions(Channel c) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return FutureBuilder<bool>(
              future: Sql.getGroupHidden(c.id!),
              builder: (context, snap) {
                final hidden = snap.data == true;
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                          title: Text(hidden ? 'Unhide category' : 'Hide category'),
                          onTap: () async {
                            await Sql.setGroupHidden(c.id!, !hidden);
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _refreshCategoriesAfterChange();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.tune),
                          title: const Text('Manage categories'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openManageCategories();
                          },
                        ),
                        const SizedBox(height: 4),
                        ListTile(
                          leading: const Icon(Icons.close),
                          title: const Text('Close'),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              });
        });
  }

  Future<void> loadLandingSections() async {
    final sourceIds = widget.home.filters.sourceIds ?? [];
    final settings = await SettingsService.getSettings();
    if (widget.home.filters.mediaTypes != null &&
        widget.home.filters.mediaTypes!.length == 1) {
      final mt = widget.home.filters.mediaTypes!.first;
      if (mt == MediaType.movie) {
        final recent =
            await Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.movie, 30);
        final cats = await Sql.getAllGroupsByMediaTypes(sourceIds, [MediaType.movie]);
        List<TmdbItem> movies = [];
        if (settings.tmdbApiKey.isNotEmpty) {
          movies = await TmdbService(apiKey: settings.tmdbApiKey).trendingMovies();
        }
        if (!mounted) return;
        setState(() {
          recentMovies = recent;
          movieCategories = cats;
          topMovies = movies;
        });
      } else if (mt == MediaType.serie) {
        final recent =
            await Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.serie, 30);
        final cats = await Sql.getAllGroupsByMediaTypes(sourceIds, [MediaType.serie]);
        List<TmdbItem> series = [];
        if (settings.tmdbApiKey.isNotEmpty) {
          series = await TmdbService(apiKey: settings.tmdbApiKey).trendingSeries();
        }
        if (!mounted) return;
        setState(() {
          recentSeries = recent;
          seriesCategories = cats;
          topSeries = series;
        });
      }
    }
  }

  Future<void> loadFeed() async {
    final sourceIds = widget.home.filters.sourceIds ?? [];
    // Recent TV
    final recent = await Sql.getRecentLivestreams(sourceIds, 20);
    // Favorites by type
    final favTv =
        await Sql.getFavoritesByMediaType(sourceIds, MediaType.livestream, 30);
    final favMov =
        await Sql.getFavoritesByMediaType(sourceIds, MediaType.movie, 30);
    final favSer =
        await Sql.getFavoritesByMediaType(sourceIds, MediaType.serie, 30);
    final rMovies =
        await Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.movie, 30);
    final rSeries =
        await Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.serie, 30);
    // TMDB trending (optional)
    final settings = await SettingsService.getSettings();
    List<TmdbItem> series = [];
    List<TmdbItem> movies = [];
    if (settings.tmdbApiKey.isNotEmpty) {
      final tmdb = TmdbService(apiKey: settings.tmdbApiKey);
      series = await tmdb.trendingSeries();
      movies = await tmdb.trendingMovies();
    }
    if (!mounted) return;
    setState(() {
      recentLive = recent;
      favoriteTv = favTv;
      favMovies = favMov;
      favSeries = favSer;
      recentMoviesHome = rMovies;
      recentSeriesHome = rSeries;
      topSeries = series;
      topMovies = movies;
    });
  }

  Future<void> openSourceSelector() async {
    // Build list of enabled sources + 'All sources' option
    final allSources = await Sql.getSources();
    final enabled = allSources.where((s) => s.enabled).toList();
    final items = <IdData<String>>[
      IdData(id: -1, data: 'All sources'),
      ...enabled.map((s) => IdData(id: s.id!, data: s.name))
    ];
    if (!mounted) return;
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return SelectDialog(
              title: "Select source",
              data: items,
              action: (id) async {
                if (id == -1) {
                  // All enabled sources
                  widget.home.filters.sourceIds =
                      enabled.map((s) => s.id!).toList();
                } else {
                  widget.home.filters.sourceIds = [id];
                }
                Navigator.of(context).pop();
                // Reset paging and reload sections according to current tab
                await load(false);
                final idx = getStartingIndex();
                if (idx == 0) {
                  await loadFeed();
                } else if (idx == 3 || idx == 4) {
                  await loadLandingSections();
                }
              });
        });
  }

  Future<void> initializeAsync() async {
    if (widget.home.filters.sourceIds == null) {
      final sources = await Sql.getEnabledSourcesMinimal();
      widget.home.filters.sourceIds = sources.map((x) => x.id).toList();
    }
    if (widget.home.filters.mediaTypes == null) {
      widget.home.filters.mediaTypes =
          (await SettingsService.getSettings()).getMediaTypes();
    }
    await load();
    // Load feed sections if on Home tab
    if (getStartingIndex() == 0) {
      await loadFeed();
    } else if (getStartingIndex() == 3 || getStartingIndex() == 4) {
      await loadLandingSections();
    }
    final String? version = await SettingsService.shouldShowWhatsNew();
    if (widget.firstLaunch && version != null) {
      await showWhatsNew(version);
    }
    if (widget.refresh) {
      Error.tryAsyncNoLoading(() async {
        setState(() {
          blockSettings = true;
        });
        await Utils.refreshAllSources();
      }, context, true, "Refreshed all sources");
      setState(() {
        blockSettings = false;
      });
    }
  }

  Future<void> showWhatsNew(String version) async {
    showDialog(
        context: context,
        builder: (context) => WhatsNewModal(version: version));
  }

  void toggleSearch() {
    setState(() {
      searchMode = !searchMode;
    });
    if (searchMode) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => FocusScope.of(context).requestFocus(_focusNode));
    } else {
      FocusScope.of(context).unfocus();
      widget.home.filters.query = null;
      searchController.clear();
      _scrollController.jumpTo(0);
      load(false);
    }
  }

  Future<void> load([bool more = false]) async {
    if (more) {
      widget.home.filters.page++;
    } else {
      widget.home.filters.page = 1;
    }
    await Error.tryAsyncNoLoading(() async {
      List<Channel> channels;
      if (widget.home.filters.viewType == ViewType.categories &&
          widget.home.filters.mediaTypes != null &&
          widget.home.filters.sourceIds != null) {
        // Show all categories at once
        channels = await Sql.getAllGroupsByMediaTypes(
            widget.home.filters.sourceIds!, widget.home.filters.mediaTypes!);
        reachedMax = true;
      } else {
        channels = await Sql.search(widget.home.filters);
      }
      if (!more) {
        setState(() {
          this.channels = channels;
        });
      } else {
        setState(() {
          this.channels.addAll(channels);
        });
      }
      if (widget.home.filters.viewType != ViewType.categories) {
        reachedMax = channels.length < pageSize;
      }
    }, context);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() async {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.75 &&
        !isLoading &&
        !reachedMax) {
      setState(() {
        isLoading = true;
      });
      await load(true);
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleBack() {
    toggleSearch();
  }

  bool canPop() {
    return !searchMode;
  }

  void clearSearch() {
    widget.home.filters.query = null;
    searchController.clear();
  }

  int getStartingIndex() {
    if (widget.home.filters.viewType == ViewType.favorites) {
      return 1; // Favorites
    }
    if (widget.home.filters.viewType == ViewType.downloads) {
      return 5; // Downloads tab
    }
    if (widget.home.filters.mediaTypes != null &&
        widget.home.filters.mediaTypes!.length == 1) {
      final m = widget.home.filters.mediaTypes!.first;
      if (m == MediaType.livestream) return 2; // Live TV
      if (m == MediaType.serie) return 3; // Series
      if (m == MediaType.movie) return 4; // Movies
    }
    return 0; // Home
  }

  void onTabSelected(int index) async {
    // Map tabs: 0 Home, 1 Favorites, 2 Live TV, 3 Series, 4 Movies, 5 Downloads
    List<MediaType>? mediaTypes;
    ViewType viewType = ViewType.all;
    if (index == 0) {
      // Home -> use current settings toggles
      final settings = await SettingsService.getSettings();
      mediaTypes = settings.getMediaTypes();
      viewType = ViewType.all;
    } else if (index == 1) {
      final settings = await SettingsService.getSettings();
      mediaTypes = settings.getMediaTypes();
      viewType = ViewType.favorites;
    } else if (index == 2) {
      mediaTypes = [MediaType.livestream];
      viewType = ViewType.categories; // categories first for Live TV
    } else if (index == 3) {
      mediaTypes = [MediaType.serie];
      viewType = ViewType.all;
    } else if (index == 4) {
      mediaTypes = [MediaType.movie];
      viewType = ViewType.all;
    } else if (index == 5) {
      viewType = ViewType.downloads;
      mediaTypes = null;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        NoPushAnimationMaterialPageRoute(
            builder: (context) => Home(
                  home: HomeManager(
                      filters: Filters(
                          viewType: viewType,
                          mediaTypes: mediaTypes,
                          sourceIds: widget.home.filters.sourceIds)),
                )),
        (route) => false);
  }

  void setNode(Node node) {
    final home = HomeManager(
        node: node,
        filters: Filters(
            viewType: ViewType.all,
            mediaTypes: widget.home.filters.mediaTypes,
            sourceIds: widget.home.filters.sourceIds));
    if (widget.home.filters.groupId != null) {
      home.filters.groupId = widget.home.filters.groupId;
    } else if (node.type == NodeType.category) {
      home.filters.groupId = node.id;
    }
    if (node.type == NodeType.series) home.filters.seriesId = node.id;
    Navigator.of(context).push(NoPushAnimationMaterialPageRoute(
        builder: (context) => Home(home: home)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: canPop(),
        onPopInvokedWithResult: (didPop, result) {
          handleBack();
        },
        child: Scaffold(
            appBar: AppBar(
              title: widget.home.node != null
                  ? Text(widget.home.node.toString())
                  : null,
              leading: widget.home.node != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: widget.home.node == null
                  ? [
                      IconButton(
                        tooltip: 'Cast',
                        icon: const Icon(Icons.cast),
                        onPressed: () async {
                          await CastService.ensureConnected(context);
                        },
                      ),
                      IconButton(
                        tooltip: 'Select source',
                        icon: const Icon(Icons.filter_list),
                        onPressed: () async {
                          await openSourceSelector();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () async {
                          if (blockSettings) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Settings disabled while refreshing on start")));
                            return;
                          }
                          await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const SettingsView(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                              transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) =>
                                  child,
                            ),
                          );
                          // After settings, re-sync enabled sources and reload
                          final enabled = await Sql.getEnabledSourcesMinimal();
                          widget.home.filters.sourceIds =
                              enabled.map((s) => s.id).toList();
                          await load(false);
                          final idx = getStartingIndex();
                          if (idx == 0) {
                            await loadFeed();
                          } else if (idx == 3 || idx == 4) {
                            await loadLandingSections();
                          }
                        },
                      )
                    ]
                  : null,
            ),
            body: Loading(
                child: SafeArea(
                    child: Column(children: [
              AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: searchMode
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainer, // Background color
                          child: Row(
                            children: [
                              if (widget.home.filters.viewType ==
                                      ViewType.favorites &&
                                  !searchMode &&
                                  widget.home.node == null)
                                _buildFavoritesTypeFilter(),
                              Expanded(
                                  child: TextField(
                                controller: searchController,
                                focusNode: _focusNode,
                                onChanged: (query) {
                                  _debounce?.cancel();
                                  _debounce = Timer(
                                      const Duration(milliseconds: 500), () {
                                    widget.home.filters.query = query;
                                    load(false);
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Search...",
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                      onPressed: () {
                                        widget.home.filters.useKeywords =
                                            !widget.home.filters.useKeywords;
                                        load(false);
                                      },
                                      icon: Icon(widget.home.filters.useKeywords
                                          ? Icons.label
                                          : Icons.label_outline)),
                                  filled: true, // Light background for contrast
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                ),
                              )),
                              const SizedBox(width: 10),
                              SizedBox(
                                  width: 40,
                                  child: IconButton(
                                      onPressed: toggleSearch,
                                      icon: const Icon(
                                        Icons.close,
                                      )))
                            ],
                          ),
                        )
                      : const SizedBox.shrink()),
              if (widget.home.filters.viewType == ViewType.favorites &&
                  !searchMode &&
                  widget.home.node == null)
                _buildFavoritesTypeFilter(),
              Expanded(
                  child: getStartingIndex() == 0 &&
                          !searchMode &&
                          widget.home.node == null
                      ? SingleChildScrollView(
                          child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRecentTvSection(),
                              if (favoriteTv.isNotEmpty)
                                _buildSection(
                                    title: 'Favorite TV Channels',
                                    height: 210,
                                    children: favoriteTv
                                        .map((c) => _channelCard(c))
                                        .toList()),
                              if (topSeries.isNotEmpty)
                                _buildTmdbGateOrSection(
                                    title: 'Top Series',
                                    items: topSeries,
                                    isSeries: true),
                              if (recentSeriesHome.isNotEmpty)
                                _buildSection(
                                    title: 'Recently added Series',
                                    height: 210,
                                    children: recentSeriesHome
                                        .map((c) => _channelCard(c))
                                        .toList()),
                              if (favSeries.isNotEmpty)
                                _buildSection(
                                    title: 'Watchlist • Series',
                                    height: 210,
                                    children: favSeries
                                        .map((c) => _channelCard(c))
                                        .toList()),
                              if (topMovies.isNotEmpty)
                                _buildTmdbGateOrSection(
                                    title: 'Top Movies',
                                    items: topMovies,
                                    isSeries: false),
                              if (recentMoviesHome.isNotEmpty)
                                _buildSection(
                                    title: 'Recently added Movies',
                                    height: 210,
                                    children: recentMoviesHome
                                        .map((c) => _channelCard(c))
                                        .toList()),
                              if (favMovies.isNotEmpty)
                                _buildSection(
                                    title: 'Watchlist • Movies',
                                    height: 210,
                                    children: favMovies
                                        .map((c) => _channelCard(c))
                                        .toList()),
                          ],
                          ),
                        ))
                      : (getStartingIndex() == 4 && !searchMode && widget.home.node == null)
                          ? _buildMoviesLanding()
                          : (getStartingIndex() == 3 && !searchMode && widget.home.node == null)
                              ? _buildSeriesLanding()
                              : (getStartingIndex() == 5 && !searchMode && widget.home.node == null)
                                  ? const DownloadsView(embedded: true)
                      : GridView.builder(
                          shrinkWrap: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
                          itemCount: channels.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 315,
                            mainAxisExtent: 120,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                          ),
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            if (channel.mediaType == MediaType.group) {
                              return _categoryGridTile(channel);
                            }
                            return ChannelTile(
                              channel: channel,
                              parentContext: context,
                              setNode: setNode,
                            );
                          },
                        )),
            ]))),
            bottomNavigationBar: BottomNav(
              startingIndex: getStartingIndex(),
              onTabSelected: onTabSelected,
            ),
            floatingActionButton: Visibility(
              visible: !searchMode,
              child: FloatingActionButton(
                onPressed: toggleSearch,
                tooltip: 'Search',
                child: const Icon(Icons.search),
              ),
            )));
  }

  Widget _buildSection({
    required String title,
    required double height,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTvSection() {
    const String title = 'Recently watched TV channels';
    if (recentLive.isNotEmpty) {
      return _buildSection(
          title: title,
          height: 210,
          children: recentLive.map((c) => _channelCard(c)).toList());
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child:
                Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'This will show up once you start watching TV channels',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTypeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: favoritesFilter == 0,
            onSelected: (v) {
              if (v) _applyFavoritesFilter(0);
            },
          ),
          ChoiceChip(
            label: const Text('TV'),
            selected: favoritesFilter == 1,
            onSelected: (v) {
              if (v) _applyFavoritesFilter(1);
            },
          ),
          ChoiceChip(
            label: const Text('Series'),
            selected: favoritesFilter == 2,
            onSelected: (v) {
              if (v) _applyFavoritesFilter(2);
            },
          ),
          ChoiceChip(
            label: const Text('Movies'),
            selected: favoritesFilter == 3,
            onSelected: (v) {
              if (v) _applyFavoritesFilter(3);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _applyFavoritesFilter(int idx) async {
    setState(() {
      favoritesFilter = idx;
    });
    List<MediaType>? mediaTypes;
    if (idx == 0) {
      final s = await SettingsService.getSettings();
      mediaTypes = s.getMediaTypes();
    } else if (idx == 1) {
      mediaTypes = [MediaType.livestream];
    } else if (idx == 2) {
      mediaTypes = [MediaType.serie];
    } else if (idx == 3) {
      mediaTypes = [MediaType.movie];
    }
    widget.home.filters.viewType = ViewType.favorites;
    widget.home.filters.mediaTypes = mediaTypes;
    await load(false);
  }

  Widget _channelCard(Channel c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetailsPage(
                        channel: c,
                      )));
          if (mounted) setState(() {});
        },
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (c.image?.trim().isNotEmpty ?? false)
                            ? CachedNetworkImage(
                                imageUrl: c.image!.trim(),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: const Icon(Icons.tv, size: 48),
                              ),
                      ),
                      if (c.favorite)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.favorite, color: Color(0xFFE50914)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _tmdbCard(TmdbItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TmdbDetailsPage(
                        item: item,
                        sourceIds: widget.home.filters.sourceIds ?? [],
                      )));
        },
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (item.posterUrl != null)
                      ? CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: const Icon(Icons.local_movies, size: 48),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTmdbGateOrSection({
    required String title,
    required List<TmdbItem> items,
    required bool isSeries,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildSection(
        title: title, height: 260, children: items.map(_tmdbCard).toList());
  }

  Widget _categoryGridTile(Channel c) {
    return InkWell(
      onTap: () {
        setNode(Node(id: c.id!, name: c.name, type: NodeType.category));
      },
      onLongPress: () => _showCategoryOptions(c),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            c.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(String title, List<Channel> categories) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 16 / 9,
            ),
            itemBuilder: (context, index) => _categoryGridTile(categories[index]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMoviesLanding() {
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (topMovies.isNotEmpty)
          _buildTmdbGateOrSection(
              title: 'Trending Movies', items: topMovies, isSeries: false),
        if (recentMovies.isNotEmpty)
          _buildSection(
              title: 'Recently added Movies',
              height: 210,
              children: recentMovies.map((c) => _channelCard(c)).toList()),
        if (movieCategories.isNotEmpty)
          _buildCategoryGrid('Categories', movieCategories),
      ]),
    ));
  }

  Widget _buildSeriesLanding() {
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (topSeries.isNotEmpty)
          _buildTmdbGateOrSection(
              title: 'Trending Series', items: topSeries, isSeries: true),
        if (recentSeries.isNotEmpty)
          _buildSection(
              title: 'Recently added Series',
              height: 210,
              children: recentSeries.map((c) => _channelCard(c)).toList()),
        if (seriesCategories.isNotEmpty)
          _buildCategoryGrid('Categories', seriesCategories),
      ]),
    ));
  }

}
