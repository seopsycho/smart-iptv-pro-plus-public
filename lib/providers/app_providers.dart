import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/models/settings.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';

// Settings Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<Settings>>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AsyncValue<Settings>> {
  SettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getSettings();
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateSettings(Settings newSettings) async {
    try {
      await SettingsService.updateSettings(newSettings);
      state = AsyncValue.data(newSettings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Sources Provider
final sourcesProvider = StateNotifierProvider<SourcesNotifier, AsyncValue<List<Source>>>((ref) {
  return SourcesNotifier();
});

class SourcesNotifier extends StateNotifier<AsyncValue<List<Source>>> {
  SourcesNotifier() : super(const AsyncValue.loading()) {
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final sources = await Sql.getSources();
      state = AsyncValue.data(sources);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshSources() async {
    state = const AsyncValue.loading();
    await _loadSources();
  }

  Future<void> addSource(Source source) async {
    try {
      await Sql.insertSource(source);
      await _loadSources();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateSource(Source source) async {
    try {
      await Sql.updateSource(source);
      await _loadSources();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteSource(int sourceId) async {
    try {
      await Sql.deleteSource(sourceId);
      await _loadSources();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Channels Provider
final channelsProvider = StateNotifierProvider<ChannelsNotifier, AsyncValue<List<Channel>>>((ref) {
  return ChannelsNotifier();
});

class ChannelsNotifier extends StateNotifier<AsyncValue<List<Channel>>> {
  ChannelsNotifier() : super(const AsyncValue.data([]));

  Future<void> loadChannels(Filters filters) async {
    state = const AsyncValue.loading();
    try {
      final channels = await Sql.search(filters);
      state = AsyncValue.data(channels);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> loadMoreChannels(Filters filters) async {
    final currentState = state.value ?? [];
    try {
      final newChannels = await Sql.search(filters);
      state = AsyncValue.data([...currentState, ...newChannels]);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clearChannels() {
    state = const AsyncValue.data([]);
  }
}

// Home Data Provider
final homeDataProvider = StateNotifierProvider<HomeDataNotifier, AsyncValue<HomeData>>((ref) {
  return HomeDataNotifier();
});

class HomeData {
  final List<Channel> recentLive;
  final List<Channel> favoriteTv;
  final List<Channel> favMovies;
  final List<Channel> favSeries;
  final List<Channel> recentMovies;
  final List<Channel> recentSeries;
  final List<Channel> movieCategories;
  final List<Channel> serieCategories;
  final bool isLoading;
  final bool hasError;

  const HomeData({
    this.recentLive = const [],
    this.favoriteTv = const [],
    this.favMovies = const [],
    this.favSeries = const [],
    this.recentMovies = const [],
    this.recentSeries = const [],
    this.movieCategories = const [],
    this.serieCategories = const [],
    this.isLoading = false,
    this.hasError = false,
  });

  HomeData copyWith({
    List<Channel>? recentLive,
    List<Channel>? favoriteTv,
    List<Channel>? favMovies,
    List<Channel>? favSeries,
    List<Channel>? recentMovies,
    List<Channel>? recentSeries,
    List<Channel>? movieCategories,
    List<Channel>? serieCategories,
    bool? isLoading,
    bool? hasError,
  }) {
    return HomeData(
      recentLive: recentLive ?? this.recentLive,
      favoriteTv: favoriteTv ?? this.favoriteTv,
      favMovies: favMovies ?? this.favMovies,
      favSeries: favSeries ?? this.favSeries,
      recentMovies: recentMovies ?? this.recentMovies,
      recentSeries: recentSeries ?? this.recentSeries,
      movieCategories: movieCategories ?? this.movieCategories,
      serieCategories: serieCategories ?? this.serieCategories,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

class HomeDataNotifier extends StateNotifier<AsyncValue<HomeData>> {
  HomeDataNotifier() : super(const AsyncValue.data(HomeData()));

  Future<void> loadHomeData() async {
    state = AsyncValue.data(const HomeData(isLoading: true));
    
    try {
      final sources = await Sql.getSources();
      if (sources.isEmpty) {
        state = const AsyncValue.data(HomeData());
        return;
      }

      final sourceIds = sources.map((s) => s.id!).toList();
      
      // Load all home data in parallel
      final results = await Future.wait([
        Sql.getRecentLivestreams(sourceIds, 10),
        Sql.getFavoritesByMediaType(sourceIds, MediaType.livestream, 10),
        Sql.getFavoritesByMediaType(sourceIds, MediaType.movie, 10),
        Sql.getFavoritesByMediaType(sourceIds, MediaType.serie, 10),
        Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.movie, 10),
        Sql.getRecentlyAddedByMediaType(sourceIds, MediaType.serie, 10),
        Sql.getAllGroupsByMediaTypes(sourceIds, [MediaType.movie]),
        Sql.getAllGroupsByMediaTypes(sourceIds, [MediaType.serie]),
      ]);

      final homeData = HomeData(
        recentLive: results[0],
        favoriteTv: results[1],
        favMovies: results[2],
        favSeries: results[3],
        recentMovies: results[4],
        recentSeries: results[5],
        movieCategories: results[6],
        serieCategories: results[7],
        isLoading: false,
      );

      state = AsyncValue.data(homeData);
    } catch (error) {
      state = AsyncValue.data(HomeData(hasError: true));
    }
  }

  Future<void> refreshHomeData() async {
    await loadHomeData();
  }

  void updateChannel(Channel updatedChannel) {
    final currentData = state.value;
    if (currentData == null) return;

    // Update channel in all relevant lists
    List<Channel> updateList(List<Channel> list) {
      return list.map((channel) => 
        channel.id == updatedChannel.id ? updatedChannel : channel
      ).toList();
    }

    final newData = currentData.copyWith(
      recentLive: updateList(currentData.recentLive),
      favoriteTv: updateList(currentData.favoriteTv),
      favMovies: updateList(currentData.favMovies),
      favSeries: updateList(currentData.favSeries),
      recentMovies: updateList(currentData.recentMovies),
      recentSeries: updateList(currentData.recentSeries),
    );

    state = AsyncValue.data(newData);
  }
}

// Search Provider
final searchProvider = StateNotifierProvider<SearchNotifier, AsyncValue<List<Channel>>>((ref) {
  return SearchNotifier();
});

class SearchNotifier extends StateNotifier<AsyncValue<List<Channel>>> {
  SearchNotifier() : super(const AsyncValue.data([]));

  Future<void> searchChannels(String query, List<int> sourceIds, List<MediaType> mediaTypes) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final filters = Filters(
        viewType: ViewType.all,
        query: query,
        sourceIds: sourceIds,
        mediaTypes: mediaTypes,
        useKeywords: true,
        page: 1,
      );
      
      final channels = await Sql.search(filters);
      state = AsyncValue.data(channels);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clearSearch() {
    state = const AsyncValue.data([]);
  }
}

// Home Manager Provider
final homeManagerProvider = StateNotifierProvider<HomeManagerNotifier, AsyncValue<HomeManager>>((ref) {
  return HomeManagerNotifier();
});

class HomeManagerNotifier extends StateNotifier<AsyncValue<HomeManager>> {
  HomeManagerNotifier() : super(const AsyncValue.loading()) {
    _loadHomeManager();
  }

  Future<void> _loadHomeManager() async {
    try {
      final homeManager = HomeManager.defaultManager();
      state = AsyncValue.data(homeManager);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateHomeFlags(int channelId, {bool? hideRecent, bool? hideAll, bool? pinned}) async {
    final currentManager = state.value;
    if (currentManager == null) return;

    try {
      if (hideRecent != null) {
        await Sql.setHideRecent(channelId, hideRecent);
      }
      if (hideAll != null) {
        await Sql.setHideAll(channelId, hideAll);
      }
      if (pinned != null) {
        await Sql.setPinned(channelId, pinned);
      }
      
      await _loadHomeManager(); // Reload to get updated state
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadHomeManager();
  }
}
