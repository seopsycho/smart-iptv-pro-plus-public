import 'package:smart_iptv_pro/backend/db_factory.dart';

/// Debug utility to check if specific channel names exist in the database
/// and why they might not appear in search/category results.
class DebugMissingChannels {
  static const String target = "зачарованные";
  static const String alternative = "завороженные";
  static const List<String> exactMatches = [
    "Play-x зачарованные",
    "DITV зачарованные",
    "TVPLAY зачарованные HD"
  ];

  static Future<void> runDiagnostics() async {
    final db = await DbFactory.db;
    print("=== DEBUG MISSING CHANNELS: '$target' ===");
    print("(Also checking for similar: '$alternative')");
    print("(Exact matches to check: ${exactMatches.join(', ')})");

    // 1) Check channels table directly
    print("\n--- Checking for '$target' ---");
    final directChannels = await db.getAll('''
      SELECT id, name, group_name, source_id, media_type, url 
      FROM channels 
      WHERE LOWER(name) LIKE ? AND url IS NOT NULL
      ORDER BY name
    ''', ['%$target%']);
    print("Direct channels table matches: ${directChannels.length}");
    for (final row in directChannels) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' group='${row.columnAt(2)}' source=${row.columnAt(3)} type=${row.columnAt(4)}");
    }

    print("\n--- Checking for '$alternative' ---");
    final altChannels = await db.getAll('''
      SELECT id, name, group_name, source_id, media_type, url 
      FROM channels 
      WHERE LOWER(name) LIKE ? AND url IS NOT NULL
      ORDER BY name
    ''', ['%$alternative%']);
    print("Alternative channels table matches: ${altChannels.length}");
    for (final row in altChannels) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' group='${row.columnAt(2)}' source=${row.columnAt(3)} type=${row.columnAt(4)}");
    }

    print("\n--- Checking exact matches ---");
    for (final exact in exactMatches) {
      final exactChannels = await db.getAll('''
        SELECT id, name, group_name, source_id, media_type, url 
        FROM channels 
        WHERE name = ? AND url IS NOT NULL
        ORDER BY name
      ''', [exact]);
      if (exactChannels.isNotEmpty) {
        print("Found exact match for '$exact':");
        for (final row in exactChannels) {
          print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' group='${row.columnAt(2)}' source=${row.columnAt(3)} type=${row.columnAt(4)}");
        }
      }
    }

    // 2) Check groups table (categories)
    print("\n--- Checking groups for '$target' ---");
    final directGroups = await db.getAll('''
      SELECT id, name, source_id, media_type 
      FROM groups 
      WHERE LOWER(name) LIKE ? AND name IS NOT NULL
      ORDER BY name
    ''', ['%$target%']);
    print("Direct groups table matches: ${directGroups.length}");
    for (final row in directGroups) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' source=${row.columnAt(2)} type=${row.columnAt(3)}");
    }

    print("\n--- Checking groups for '$alternative' ---");
    final altGroups = await db.getAll('''
      SELECT id, name, source_id, media_type 
      FROM groups 
      WHERE LOWER(name) LIKE ? AND name IS NOT NULL
      ORDER BY name
    ''', ['%$alternative%']);
    print("Alternative groups table matches: ${altGroups.length}");
    for (final row in altGroups) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' source=${row.columnAt(2)} type=${row.columnAt(3)}");
    }

    // 3) Check for ANY channel containing "зачарованные" (case insensitive)
    print("\n--- Checking ANY channel containing '$target' (case insensitive) ---");
    final anyChannels = await db.getAll('''
      SELECT id, name, group_name, source_id, media_type, url 
      FROM channels 
      WHERE LOWER(name) LIKE '%' || LOWER(?) || '%' AND url IS NOT NULL
      ORDER BY name
    ''', [target]);
    print("ANY channels with '$target' (case insensitive): ${anyChannels.length}");
    for (final row in anyChannels) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' group='${row.columnAt(2)}' source=${row.columnAt(3)} type=${row.columnAt(4)}");
    }

    // 4) Show ALL channels for debugging
    print("\n--- ALL channels in database (first 50) ---");
    final allChannels = await db.getAll('''
      SELECT id, name, group_name, source_id, media_type 
      FROM channels 
      WHERE url IS NOT NULL
      ORDER BY name
      LIMIT 50
    ''');
    print("Total channels in DB (showing first 50): ${allChannels.length}");
    for (final row in allChannels) {
      print("  - id=${row.columnAt(0)} name='${row.columnAt(1)}' source=${row.columnAt(3)} type=${row.columnAt(4)}");
    }

    print("\n=== RECOMMENDATION ===");
    if (anyChannels.isNotEmpty) {
      print("Found channels containing '$target':");
      for (final row in anyChannels) {
        print("  - '${row.columnAt(1)}' (source: ${row.columnAt(3)})");
      }
    } else if (altChannels.isNotEmpty) {
      print("Found similar channel '$alternative'. Try searching for that instead.");
      print("Available matches:");
      for (final row in altChannels) {
        print("  - '${row.columnAt(1)}' (source: ${row.columnAt(3)})");
      }
    } else {
      print("No channels found matching any variation of '$target'");
      print("The channels you're looking for might not be in your current playlist");
      print("Expected channels: ${exactMatches.join(', ')}");
    }

    print("=== END DEBUG ===");
  }
}
