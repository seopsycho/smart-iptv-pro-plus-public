import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_iptv_pro/providers/ui_providers.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';

void main() {
  group('Riverpod State Management Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Search Filters Provider', () {
      test('should initialize with default filters', () {
        final filters = container.read(searchFiltersProvider);
        expect(filters.viewType, ViewType.all);
        expect(filters.query, '');
        expect(filters.mediaTypes, [MediaType.livestream, MediaType.movie, MediaType.serie]);
        expect(filters.page, 1);
      });

      test('should update query', () {
        final notifier = container.read(searchFiltersProvider.notifier);
        notifier.updateQuery('test query');
        
        final updatedFilters = container.read(searchFiltersProvider);
        expect(updatedFilters.query, 'test query');
        expect(updatedFilters.page, 1);
      });

      test('should update media types', () {
        final notifier = container.read(searchFiltersProvider.notifier);
        notifier.updateMediaTypes([MediaType.movie]);
        
        final updatedFilters = container.read(searchFiltersProvider);
        expect(updatedFilters.mediaTypes, [MediaType.movie]);
      });

      test('should handle pagination', () {
        final notifier = container.read(searchFiltersProvider.notifier);
        notifier.nextPage();
        
        final updatedFilters = container.read(searchFiltersProvider);
        expect(updatedFilters.page, 2);
      });

      test('should reset to default', () {
        final notifier = container.read(searchFiltersProvider.notifier);
        notifier.updateQuery('test');
        notifier.nextPage();
        notifier.reset();
        
        final resetFilters = container.read(searchFiltersProvider);
        expect(resetFilters.query, '');
        expect(resetFilters.page, 1);
        expect(resetFilters.viewType, ViewType.all);
      });
    });

    group('UI State Provider', () {
      test('should initialize with default UI state', () {
        final uiState = container.read(uiStateProvider);
        expect(uiState.searchMode, false);
        expect(uiState.favoritesFilter, 0);
        expect(uiState.isLoading, false);
        expect(uiState.allowLive, true);
        expect(uiState.allowMovies, true);
        expect(uiState.allowSeries, true);
      });

      test('should toggle search mode', () {
        final notifier = container.read(uiStateProvider.notifier);
        notifier.toggleSearchMode();
        
        final updatedState = container.read(uiStateProvider);
        expect(updatedState.searchMode, true);
        
        notifier.toggleSearchMode();
        final toggledBackState = container.read(uiStateProvider);
        expect(toggledBackState.searchMode, false);
      });

      test('should update favorites filter', () {
        final notifier = container.read(uiStateProvider.notifier);
        notifier.updateFavoritesFilter(2);
        
        final updatedState = container.read(uiStateProvider);
        expect(updatedState.favoritesFilter, 2);
      });

      test('should update loading state', () {
        final notifier = container.read(uiStateProvider.notifier);
        notifier.setLoading(true);
        
        final updatedState = container.read(uiStateProvider);
        expect(updatedState.isLoading, true);
      });

      test('should update media permissions', () {
        final notifier = container.read(uiStateProvider.notifier);
        notifier.updateMediaPermissions(
          allowLive: false,
          allowMovies: true,
          allowSeries: false,
        );
        
        final updatedState = container.read(uiStateProvider);
        expect(updatedState.allowLive, false);
        expect(updatedState.allowMovies, true);
        expect(updatedState.allowSeries, false);
      });

      test('should toggle show hidden in home', () {
        final notifier = container.read(uiStateProvider.notifier);
        notifier.toggleShowHiddenInHome();
        
        final updatedState = container.read(uiStateProvider);
        expect(updatedState.showHiddenInHome, true);
      });
    });

    group('Provider Integration', () {
      test('should handle search and UI state interaction', () {
        final searchNotifier = container.read(searchFiltersProvider.notifier);
        final uiNotifier = container.read(uiStateProvider.notifier);
        
        uiNotifier.setSearchMode(true);
        searchNotifier.updateQuery('test search');
        
        final searchFilters = container.read(searchFiltersProvider);
        final uiState = container.read(uiStateProvider);
        
        expect(uiState.searchMode, true);
        expect(searchFilters.query, 'test search');
      });

      test('should handle loading states across providers', () {
        final uiNotifier = container.read(uiStateProvider.notifier);
        
        uiNotifier.setLoading(true);
        final uiState = container.read(uiStateProvider);
        expect(uiState.isLoading, true);
        
        uiNotifier.setLoading(false);
        final updatedUiState = container.read(uiStateProvider);
        expect(updatedUiState.isLoading, false);
      });
    });
  });
}
