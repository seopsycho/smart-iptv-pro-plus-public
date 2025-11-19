import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iptv_pro/backend/db_factory.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:sqlite_async/sqlite_async.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Database Index Performance Tests', () {
    late SqliteDatabase db;

    setUpAll(() async {
      // Get existing database with all migrations
      db = await DbFactory.db;
    });

    tearDownAll(() async {
      // Don't close the shared database instance
      // db.close(); // Commented out to avoid affecting other tests
    });

    test('Verify critical indexes exist after migrations', () async {
      // Check Migration 9 indexes
      final criticalIndexes = [
        'index_channels_url_media_source_fav',
        'index_home_flags_composite',
        'index_groups_composite_order',
        'index_channels_url',
        'index_settings_key',
        'index_movie_positions_channel_position'
      ];

      for (final indexName in criticalIndexes) {
        final result = await db.getOptional(
          "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
          [indexName]
        );
        expect(result, isNotNull, reason: 'Index $indexName should exist');
      }

      // Check Migration 10 indexes
      final advancedIndexes = [
        'index_channels_search_composite',
        'index_channels_series_source',
        'index_downloads_channel_status'
      ];

      for (final indexName in advancedIndexes) {
        final result = await db.getOptional(
          "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
          [indexName]
        );
        expect(result, isNotNull, reason: 'Advanced index $indexName should exist');
      }
    });

    test('Query performance test with large dataset', () async {
      // Insert test data for performance testing
      await db.writeTransaction((tx) async {
        // Clear existing test data
        await tx.execute('DELETE FROM channels;');
        await tx.execute('DELETE FROM home_flags;');
        
        // Insert 1000 test channels
        for (int i = 0; i < 1000; i++) {
          await tx.execute('''
            INSERT OR REPLACE INTO channels 
            (name, url, source_id, media_type, favorite, last_watched, group_name)
            VALUES (?, ?, ?, ?, ?, ?, ?)
          ''', [
            'Test Channel $i',
            'http://test$i.example.com/stream',
            1,
            MediaType.livestream.index,
            i % 10 == 0 ? 1 : 0, // 10% favorites
            1640995200 + (i * 100), // Different timestamps
            'Test Group ${i % 20}'
          ]);
        }

        // Insert home flags for some channels
        for (int i = 0; i < 100; i++) {
          await tx.execute('''
            INSERT OR REPLACE INTO home_flags 
            (channel_id, hide_recent, hide_all, pinned)
            VALUES (?, ?, ?, ?)
          ''', [
            i + 1,
            i % 20 == 0 ? 1 : 0, // 5% hidden recent
            i % 25 == 0 ? 1 : 0, // 4% hidden all
            i % 15 == 0 ? 1 : 0  // 7% pinned
          ]);
        }
      });

      // Test complex search query performance
      final stopwatch = Stopwatch()..start();
      
      final filters = Filters(
        viewType: ViewType.all,
        query: 'Test',
        sourceIds: [1],
        mediaTypes: [MediaType.livestream],
        useKeywords: false,
        page: 1
      );

      final results = await Sql.search(filters);
      stopwatch.stop();

      expect(results.length, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(100), 
             reason: 'Complex search should complete in <100ms with indexes');

      print('Complex search query took: ${stopwatch.elapsedMilliseconds}ms for ${results.length} results');
    });

    test('Home feed performance with flags', () async {
      final stopwatch = Stopwatch()..start();
      
      // Test home flags query performance
      final flags = await Sql.getHomeFlagsForIds(List.generate(100, (i) => i + 1));
      stopwatch.stop();

      expect(flags.length, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
             reason: 'Home flags query should complete in <50ms with composite index');

      print('Home flags query took: ${stopwatch.elapsedMilliseconds}ms for ${flags.length} channels');
    });

    test('Favorites query performance', () async {
      final stopwatch = Stopwatch()..start();
      
      final favorites = await Sql.getFavoritesForSources([1], 50);
      stopwatch.stop();

      expect(favorites.length, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(30),
             reason: 'Favorites query should complete in <30ms with optimized indexes');

      print('Favorites query took: ${stopwatch.elapsedMilliseconds}ms for ${favorites.length} results');
    });

    test('Group ordering performance', () async {
      // Insert test groups
      await db.writeTransaction((tx) async {
        await tx.execute('DELETE FROM groups;');
        for (int i = 0; i < 50; i++) {
          await tx.execute('''
            INSERT OR REPLACE INTO groups 
            (name, source_id, position, hidden)
            VALUES (?, ?, ?, ?)
          ''', [
            'Test Group $i',
            1,
            i + 1, // Sequential positions
            i % 10 == 0 ? 1 : 0 // 10% hidden
          ]);
        }
      });

      final stopwatch = Stopwatch()..start();
      
      final groups = await Sql.getAllGroupsByMediaTypes([1], [MediaType.livestream]);
      stopwatch.stop();

      expect(groups.length, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(40),
             reason: 'Group ordering should complete in <40ms with composite index');

      print('Group ordering query took: ${stopwatch.elapsedMilliseconds}ms for ${groups.length} groups');
    });

    test('Index usage verification', () async {
      // Test that queries are using indexes by checking query plan
      final queryPlan = await db.getAll('''
        EXPLAIN QUERY PLAN 
        SELECT * FROM channels 
        WHERE url IS NOT NULL 
        AND media_type = ? 
        AND source_id = ? 
        AND favorite = ?
        ORDER BY last_watched DESC
        LIMIT 50
      ''', [MediaType.livestream.index, 1, 1]);

      // Should use INDEX for optimal performance
      final planText = queryPlan.map((row) => row.toString()).join(' ');
      expect(planText, contains('INDEX'), 
             reason: 'Query should use index for optimal performance');
      expect(planText, isNot(contains('SCAN TABLE')),
             reason: 'Query should not perform full table scan');

      print('Query plan uses index: ${planText.contains('INDEX')}');
    });
  });
}
