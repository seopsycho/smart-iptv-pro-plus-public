import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';

// Search filters provider
final searchFiltersProvider = StateNotifierProvider<SearchFiltersNotifier, Filters>((ref) {
  return SearchFiltersNotifier();
});

class SearchFiltersNotifier extends StateNotifier<Filters> {
  SearchFiltersNotifier() : super(Filters(
    viewType: ViewType.all,
    query: '',
    sourceIds: [],
    mediaTypes: [MediaType.livestream, MediaType.movie, MediaType.serie],
    useKeywords: true,
    page: 1,
  ));

  void updateQuery(String query) {
    state = Filters(
      viewType: state.viewType,
      query: query,
      sourceIds: state.sourceIds,
      mediaTypes: state.mediaTypes,
      useKeywords: state.useKeywords,
      page: 1,
      seriesId: state.seriesId,
      groupId: state.groupId,
    );
  }

  void updateSourceIds(List<int> sourceIds) {
    state = Filters(
      viewType: state.viewType,
      query: state.query,
      sourceIds: sourceIds,
      mediaTypes: state.mediaTypes,
      useKeywords: state.useKeywords,
      page: 1,
      seriesId: state.seriesId,
      groupId: state.groupId,
    );
  }

  void updateMediaTypes(List<MediaType> mediaTypes) {
    state = Filters(
      viewType: state.viewType,
      query: state.query,
      sourceIds: state.sourceIds,
      mediaTypes: mediaTypes,
      useKeywords: state.useKeywords,
      page: 1,
      seriesId: state.seriesId,
      groupId: state.groupId,
    );
  }

  void updateViewType(ViewType viewType) {
    state = Filters(
      viewType: viewType,
      query: state.query,
      sourceIds: state.sourceIds,
      mediaTypes: state.mediaTypes,
      useKeywords: state.useKeywords,
      page: 1,
      seriesId: state.seriesId,
      groupId: state.groupId,
    );
  }

  void nextPage() {
    state = Filters(
      viewType: state.viewType,
      query: state.query,
      sourceIds: state.sourceIds,
      mediaTypes: state.mediaTypes,
      useKeywords: state.useKeywords,
      page: state.page + 1,
      seriesId: state.seriesId,
      groupId: state.groupId,
    );
  }

  void reset() {
    state = Filters(
      viewType: ViewType.all,
      query: '',
      sourceIds: [],
      mediaTypes: [MediaType.livestream, MediaType.movie, MediaType.serie],
      useKeywords: true,
      page: 1,
    );
  }
}

// UI State provider
final uiStateProvider = StateNotifierProvider<UIStateNotifier, UIState>((ref) {
  return UIStateNotifier();
});

class UIState {
  final bool searchMode;
  final int favoritesFilter;
  final bool isLoading;
  final bool blockSettings;
  final int? previousScroll;
  final bool allowLive;
  final bool allowMovies;
  final bool allowSeries;
  final bool showHiddenInHome;

  const UIState({
    this.searchMode = false,
    this.favoritesFilter = 0,
    this.isLoading = false,
    this.blockSettings = false,
    this.previousScroll,
    this.allowLive = true,
    this.allowMovies = true,
    this.allowSeries = true,
    this.showHiddenInHome = false,
  });

  UIState copyWith({
    bool? searchMode,
    int? favoritesFilter,
    bool? isLoading,
    bool? blockSettings,
    int? previousScroll,
    bool? allowLive,
    bool? allowMovies,
    bool? allowSeries,
    bool? showHiddenInHome,
  }) {
    return UIState(
      searchMode: searchMode ?? this.searchMode,
      favoritesFilter: favoritesFilter ?? this.favoritesFilter,
      isLoading: isLoading ?? this.isLoading,
      blockSettings: blockSettings ?? this.blockSettings,
      previousScroll: previousScroll ?? this.previousScroll,
      allowLive: allowLive ?? this.allowLive,
      allowMovies: allowMovies ?? this.allowMovies,
      allowSeries: allowSeries ?? this.allowSeries,
      showHiddenInHome: showHiddenInHome ?? this.showHiddenInHome,
    );
  }
}

class UIStateNotifier extends StateNotifier<UIState> {
  UIStateNotifier() : super(const UIState());

  void toggleSearchMode() {
    state = state.copyWith(searchMode: !state.searchMode);
  }

  void setSearchMode(bool enabled) {
    state = state.copyWith(searchMode: enabled);
  }

  void updateFavoritesFilter(int filter) {
    state = state.copyWith(favoritesFilter: filter);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setBlockSettings(bool block) {
    state = state.copyWith(blockSettings: block);
  }

  void updatePreviousScroll(int? scroll) {
    state = state.copyWith(previousScroll: scroll);
  }

  void updateMediaPermissions({
    bool? allowLive,
    bool? allowMovies,
    bool? allowSeries,
  }) {
    state = state.copyWith(
      allowLive: allowLive,
      allowMovies: allowMovies,
      allowSeries: allowSeries,
    );
  }

  void toggleShowHiddenInHome() {
    state = state.copyWith(showHiddenInHome: !state.showHiddenInHome);
  }

  void setShowHiddenInHome(bool show) {
    state = state.copyWith(showHiddenInHome: show);
  }
}
