import 'dart:collection';

import 'package:smart_iptv_pro/backend/db_factory.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/channel_http_headers.dart';
import 'package:smart_iptv_pro/models/channel_preserve.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/download_item.dart';
import 'package:smart_iptv_pro/models/id_data.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/models/source_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:sqlite_async/sqlite3.dart';
import 'package:sqlite_async/sqlite_async.dart';

const int pageSize = 36;

class Sql {
  static Future<void> commitWrite(
      List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
          commits) async {
    Map<String, String> memory = {};
    Future<void> _run() async {
      final db = await DbFactory.db;
      await db.writeTransaction((tx) async {
        for (var commit in commits) {
          await commit(tx, memory);
        }
      });
    }
    bool retried = false;
    try {
      await _run();
    } catch (e) {
      // If the underlying sqlite isolate was closed (e.g. hot restart), reopen and retry once
      final msg = e.toString();
      if (!retried && (msg.contains('ClosedException') || msg.contains('database is closed'))) {
        retried = true;
        DbFactory.reset();
        await _run();
      } else {
        rethrow;
      }
    }
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String> memory)
      insertChannel(Channel channel) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
        INSERT INTO channels (name, image, url, source_id, media_type, series_id, favorite, stream_id, group_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (name, source_id)
        DO UPDATE SET
          url = excluded.url,
          group_name = excluded.group_name,
          media_type = excluded.media_type,
          stream_id = excluded.stream_id,
          image = excluded.image,
          series_id = excluded.series_id;
      ''', [
        channel.name,
        channel.image,
        channel.url,
        channel.sourceId == -1
            ? int.parse(memory['sourceId']!)
            : channel.sourceId,
        channel.mediaType.index,
        channel.seriesId,
        channel.favorite,
        channel.streamId,
        channel.group
      ]);
      memory['lastChannelId'] =
          (await tx.get("SELECT last_insert_rowid()")).columnAt(0).toString();
    };
  }

  static Future<List<Channel>> getRecentLivestreams(
      List<int> sourceIds, int limit) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * FROM channels
      WHERE url IS NOT NULL
        AND media_type = ?
        AND last_watched IS NOT NULL
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
      ORDER BY last_watched DESC
      LIMIT ?
    ''', [MediaType.livestream.index, ...sourceIds, limit]);
    return results.map(rowToChannel).toList();
  }

  static Future<List<Channel>> getFavoritesForSources(
      List<int> sourceIds, int limit) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * FROM channels
      WHERE url IS NOT NULL
        AND favorite = 1
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
      ORDER BY id DESC
      LIMIT ?
    ''', [...sourceIds, limit]);
    return results.map(rowToChannel).toList();
  }

  static Future<List<Channel>> getFavoritesByMediaType(
      List<int> sourceIds, MediaType mediaType, int limit) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * FROM channels
      WHERE url IS NOT NULL
        AND favorite = 1
        AND media_type = ?
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
      ORDER BY id DESC
      LIMIT ?
    ''', [mediaType.index, ...sourceIds, limit]);
    return results.map(rowToChannel).toList();
  }

  static Future<List<Channel>> getRecentlyAddedByMediaType(
      List<int> sourceIds, MediaType mediaType, int limit) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * FROM channels
      WHERE url IS NOT NULL
        AND media_type = ?
        AND series_id IS NULL
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
      ORDER BY id DESC
      LIMIT ?
    ''', [mediaType.index, ...sourceIds, limit]);
    return results.map(rowToChannel).toList();
  }

  static Future<List<Channel>> getFavoritesByMediaTypes(
      List<int> sourceIds, List<MediaType> mediaTypes, int limit) async {
    var db = await DbFactory.db;
    final mtPlaceholders = generatePlaceholders(mediaTypes.length);
    var results = await db.getAll('''
      SELECT * FROM channels
      WHERE url IS NOT NULL
        AND favorite = 1
        AND media_type IN ($mtPlaceholders)
      AND source_id IN (${generatePlaceholders(sourceIds.length)})
      ORDER BY id DESC
      LIMIT ?
    ''', [...mediaTypes.map((m) => m.index), ...sourceIds, limit]);
    return results.map(rowToChannel).toList();
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      updateGroups() {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = int.parse(memory['sourceId']!);
      await tx.execute('''
      INSERT INTO groups (name, image, source_id, media_type)
      SELECT group_name, MAX(image), ?, media_type
      FROM channels
      WHERE source_id = ?
      GROUP BY group_name, media_type
      ON CONFLICT(name, source_id) DO UPDATE SET
          media_type = excluded.media_type,
          image = COALESCE(excluded.image, groups.image);
    ''', [sourceId, sourceId]);
      await tx.execute('''
      UPDATE channels
      SET group_id = (
        SELECT id FROM groups 
        WHERE groups.name = channels.group_name 
          AND groups.source_id = channels.source_id
        LIMIT 1
      )
      WHERE source_id = ?;
    ''', [sourceId]);
    };
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      insertChannelHeaders(ChannelHttpHeaders headers) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
          INSERT OR IGNORE INTO channel_http_headers (channel_id, referrer, user_agent, http_origin, ignore_ssl)
          VALUES (?, ?, ?, ?, ?)
        ''', [
        int.parse(memory['lastChannelId']!),
        headers.referrer,
        headers.userAgent,
        headers.httpOrigin,
        headers.ignoreSSL
      ]);
    };
  }

  static Future<ChannelHttpHeaders?> getChannelHeaders(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
        SELECT * FROM channel_http_headers
        WHERE channel_id = ?
        LIMIT 1
    ''', [channelId]);
    return result != null ? _rowToHeaders(result) : null;
  }

  static ChannelHttpHeaders _rowToHeaders(Row row) {
    return ChannelHttpHeaders(
        id: row.columnAt(0),
        channelId: row.columnAt(1),
        referrer: row.columnAt(2),
        userAgent: row.columnAt(3),
        httpOrigin: row.columnAt(4),
        ignoreSSL: row.columnAt(5));
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      getOrCreateSourceByName(Source source) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = (await tx.getOptional(
              "SELECT id FROM sources WHERE name = ?", [source.name]))
          ?.columnAt(0);
      if (sourceId != null) {
        memory['sourceId'] = sourceId.toString();
        return;
      }
      await tx.execute('''
            INSERT INTO sources (name, source_type, url, username, password) VALUES (?, ?, ?, ?, ?);
          ''', [
        source.name,
        source.sourceType.index,
        source.url,
        source.username,
        source.password,
      ]);
      memory['sourceId'] =
          (await tx.get("SELECT last_insert_rowid();")).columnAt(0).toString();
    };
  }

  static Future<List<Channel>> search(Filters filters) async {
    if (filters.viewType == ViewType.categories &&
        filters.groupId == null &&
        filters.seriesId == null) {
      return searchGroup(filters);
    }
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var mediaTypes = filters.seriesId == null
        ? filters.mediaTypes!.map((x) => x.index)
        : [1];
    var query = filters.query ?? "";
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"];
    var sqlQuery = '''
        SELECT * FROM channels 
        WHERE (${getKeywordsSql(keywords.length)})
        AND media_type IN (${generatePlaceholders(mediaTypes.length)})
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        AND url IS NOT NULL
    ''';
    List<Object> params = [];
    if (filters.viewType == ViewType.favorites && filters.seriesId == null) {
      sqlQuery += "\nAND favorite = 1";
    }
    if (filters.viewType == ViewType.history) {
      sqlQuery += "\nAND last_watched IS NOT NULL";
      sqlQuery += "\nORDER BY last_watched DESC";
    }
    if (filters.seriesId != null) {
      sqlQuery += "\nAND series_id = ?";
    } else if (filters.groupId != null) {
      sqlQuery += "\nAND group_id = ?";
    }
    sqlQuery += "\nLIMIT ?, ?";
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    if (filters.seriesId != null) {
      params.add(filters.seriesId!);
    } else if (filters.groupId != null) {
      params.add(filters.groupId!);
    }
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(rowToChannel).toList();
  }

  static Channel rowToChannel(Row row) {
    return Channel(
      id: row.columnAt(0),
      name: row.columnAt(1),
      group: row.columnAt(2),
      image: row.columnAt(3),
      url: row.columnAt(4),
      mediaType: MediaType.values[row.columnAt(5)],
      sourceId: row.columnAt(6),
      favorite: row.columnAt(7) == 1,
      seriesId: row.columnAt(8),
      groupId: row.columnAt(9),
      streamId: row.columnAt(10),
    );
  }

  static String generatePlaceholders(int size) {
    return List.filled(size, "?").join(",");
  }

  static String getKeywordsSql(int size) {
    return List.generate(size, (_) => "name LIKE ?").join(" AND ");
  }

  static Future<List<Channel>> searchGroup(Filters filters) async {
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var query = filters.query ?? "";
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"]; 
    var mediaTypes = filters.mediaTypes!.map((x) => x.index);
    var sqlQuery = '''
        SELECT * FROM groups 
        WHERE (${getKeywordsSql(keywords.length)})
        AND (media_type IS NULL OR media_type IN (${generatePlaceholders(mediaTypes.length)}))
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        AND (hidden = 0 OR hidden IS NULL)
        ORDER BY (position IS NULL) ASC, position ASC, name ASC
        LIMIT ?, ?
    ''';
    List<Object> params = [];
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(groupChannelToRow).toList();
  }

  static Future<List<Channel>> searchGroupIncludeHidden(Filters filters) async {
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var query = filters.query ?? "";
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"]; 
    var mediaTypes = filters.mediaTypes!.map((x) => x.index);
    var sqlQuery = '''
        SELECT * FROM groups 
        WHERE (${getKeywordsSql(keywords.length)})
        AND (media_type IS NULL OR media_type IN (${generatePlaceholders(mediaTypes.length)}))
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        ORDER BY (position IS NULL) ASC, position ASC, name ASC
        LIMIT ?, ?
    ''';
    List<Object> params = [];
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(groupChannelToRow).toList();
  }

  static Future<void> setGroupHidden(int groupId, bool hidden) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE groups
      SET hidden = ?
      WHERE id = ?
    ''', [hidden ? 1 : 0, groupId]);
  }

  static Future<void> reorderGroups(List<int> ids) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      int pos = 1;
      for (final id in ids) {
        await tx.execute('''
          UPDATE groups
          SET position = ?
          WHERE id = ?
        ''', [pos, id]);
        pos++;
      }
    });
  }

  static Future<bool> getGroupHidden(int groupId) async {
    var db = await DbFactory.db;
    final row = await db.getOptional('''
      SELECT hidden FROM groups WHERE id = ?
    ''', [groupId]);
    if (row == null) return false;
    final val = row.columnAt(0);
    if (val == null) return false;
    return val == 1;
  }

  static Future<List<Channel>> getAllGroupsByMediaTypes(
      List<int> sourceIds, List<MediaType> mediaTypes) async {
    var db = await DbFactory.db;
    var sqlQuery = '''
        SELECT * FROM groups 
        WHERE (media_type IS NULL OR media_type IN (${generatePlaceholders(mediaTypes.length)}))
        AND source_id IN (${generatePlaceholders(sourceIds.length)})
        AND (hidden = 0 OR hidden IS NULL)
        ORDER BY (position IS NULL) ASC, position ASC, name ASC
    ''';
    List<Object> params = [...mediaTypes.map((m) => m.index), ...sourceIds];
    var results = await db.getAll(sqlQuery, params);
    return results.map(groupChannelToRow).toList();
  }

  static Channel groupChannelToRow(Row row) {
    return Channel(
        id: row.columnAt(0),
        name: row.columnAt(1),
        image: row.columnAt(2),
        sourceId: row.columnAt(3),
        favorite: false,
        mediaType: MediaType.group);
  }

  static Future<bool> sourceNameExists(String? name) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT 1
      FROM sources
      WHERE name = ?
    ''', [name]);
    return result?.columnAt(0) == 1;
  }

  static Future<List<Source>> getSources() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * 
      FROM sources 
    ''');
    return results.map(rowToSource).toList();
  }

  static Source rowToSource(Row row) {
    return Source(
        id: row.columnAt(0),
        name: row.columnAt(1),
        sourceType: SourceType.values[row.columnAt(2)],
        url: row.columnAt(3),
        username: row.columnAt(4),
        password: row.columnAt(5),
        enabled: row.columnAt(6) == 1);
  }

  static Future<List<IdData<SourceType>>> getEnabledSourcesMinimal() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT id, source_type
      FROM sources 
      WHERE enabled = 1
    ''');
    return results.map(rowToSourceMinimal).toList();
  }

  static IdData<SourceType> rowToSourceMinimal(Row row) {
    return IdData(
        id: row.columnAt(0), data: SourceType.values[row.columnAt(1)]);
  }

  static Future<bool> hasSources() async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT 1
      FROM sources
      LIMIT 1
    ''');
    return result?.columnAt(0) == 1;
  }

  static Future<void> favoriteChannel(int channelId, bool favorite) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE channels
      SET favorite = ?
      WHERE id = ?
    ''', [favorite ? 1 : 0, channelId]);
  }

  static Future<HashMap<String, String>> getSettings() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''SELECT key, value FROM Settings''');
    return HashMap.fromEntries(
        results.map((f) => MapEntry(f.columnAt(0), f.columnAt(1))));
  }

  static Future<void> updateSettings(HashMap<String, String> settings) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      for (var entry in settings.entries) {
        await tx.execute('''
        INSERT INTO Settings (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = ?''',
            [entry.key, entry.value, entry.value]);
      }
    });
  }

  static Future<void> deleteSource(int sourceId) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute("DELETE FROM channels WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM groups WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM sources WHERE id = ?", [sourceId]);
    });
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      wipeSource(int sourceId) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute('''
        DELETE FROM channels 
        WHERE source_id = ? 
      ''', [sourceId]);
      await tx.execute('''
        DELETE FROM groups
        WHERE source_id = ?
      ''', [sourceId]);
    };
  }

  static Future<void> updateSource(Source source) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE sources
      SET url = ?, username = ?, password = ?
      WHERE id = ?
    ''', [source.url, source.username, source.password, source.id]);
  }

  static Future<void> updateChannelImage(int channelId, String imageUrl) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE channels
      SET image = ?
      WHERE id = ?
    ''', [imageUrl, channelId]);
  }

  static Future<Source> getSourceFromId(int id) async {
    var db = await DbFactory.db;
    var result = await db.get('''SELECT * FROM sources WHERE id = ?''', [id]);
    return rowToSource(result);
  }

  static Future<void> setSourceEnabled(bool enabled, int sourceId) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE sources 
      SET enabled = ? 
      WHERE id = ?
    ''', [enabled, sourceId]);
  }

  static Future setPosition(int channelId, int seconds) async {
    var db = await DbFactory.db;
    await db.execute('''
      INSERT INTO movie_positions (channel_id, position)
      VALUES (?, ?)
      ON CONFLICT (channel_id)
      DO UPDATE SET
      position = excluded.position;
    ''', [channelId, seconds]);
  }

  static Future<int?> getPosition(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT position FROM movie_positions
      WHERE channel_id = ?
    ''', [channelId]);
    return result?.columnAt(0);
  }

  static Future<void> addToHistory(int id) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE channels
      SET last_watched = strftime('%s', 'now')
      WHERE id = ?
    ''', [id]);
    await db.execute('''
      UPDATE channels
      SET last_watched = NULL
      WHERE last_watched IS NOT NULL
		  AND id NOT IN (
				SELECT id 
				FROM channels
				WHERE last_watched IS NOT NULL
				ORDER BY last_watched DESC
				LIMIT 36
		  )
    ''');
  }

  static Future<List<ChannelPreserve>> getChannelsPreserve(int sourceId) async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT name, favorite, last_watched
      FROM channels
      WHERE (favorite = 1 OR last_watched IS NOT NULL) AND source_id = ?
    ''', [sourceId]);
    return results.map(rowToChannelPreserve).toList();
  }

  static ChannelPreserve rowToChannelPreserve(Row row) {
    return ChannelPreserve(
        name: row.columnAt(0),
        favorite: row.columnAt(1),
        lastWatched: row.columnAt(2));
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
      restorePreserve(List<ChannelPreserve> preserve) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      final sourceId = int.parse(memory['sourceId']!);
      for (var channel in preserve) {
        await tx.execute('''
          UPDATE channels
          SET favorite = ?, last_watched = ?
          WHERE name = ?
          AND source_id = ?
        ''', [channel.favorite, channel.lastWatched, channel.name, sourceId]);
      }
    };
  }

  static Future<void> upsertDownload({
    required int channelId,
    required String filePath,
    required int status,
    required int bytes,
    required int totalBytes,
  }) async {
    var db = await DbFactory.db;
    await db.execute('''
      INSERT INTO downloads (channel_id, file_path, status, bytes, total_bytes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, strftime('%s','now'), strftime('%s','now'))
      ON CONFLICT(channel_id) DO UPDATE SET
        file_path = excluded.file_path,
        status = excluded.status,
        bytes = excluded.bytes,
        total_bytes = excluded.total_bytes,
        updated_at = strftime('%s','now');
    ''', [channelId, filePath, status, bytes, totalBytes]);
  }

  static Future<void> updateDownloadProgress(int channelId, int bytes, int totalBytes) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE downloads
      SET bytes = ?, total_bytes = ?, updated_at = strftime('%s','now')
      WHERE channel_id = ?
    ''', [bytes, totalBytes, channelId]);
  }

  static Future<void> updateDownloadStatus(int channelId, int status) async {
    var db = await DbFactory.db;
    await db.execute('''
      UPDATE downloads
      SET status = ?, updated_at = strftime('%s','now')
      WHERE channel_id = ?
    ''', [status, channelId]);
  }

  static Future<void> deleteDownload(int channelId) async {
    var db = await DbFactory.db;
    await db.execute('''
      DELETE FROM downloads WHERE channel_id = ?
    ''', [channelId]);
  }

  static Future<void> deleteAllDownloads() async {
    var db = await DbFactory.db;
    await db.execute('DELETE FROM downloads');
  }

  static DownloadItem _rowToDownloadItem(Row row) {
    final channel = Channel(
      id: row.columnAt(5),
      name: row.columnAt(6),
      group: row.columnAt(7),
      image: row.columnAt(8),
      url: row.columnAt(9),
      mediaType: MediaType.values[row.columnAt(10)],
      sourceId: row.columnAt(11),
      favorite: row.columnAt(12) == 1,
      seriesId: row.columnAt(13),
      groupId: row.columnAt(14),
      streamId: row.columnAt(15),
    );
    return DownloadItem(
      channel: channel,
      filePath: row.columnAt(1),
      status: row.columnAt(2),
      bytes: row.columnAt(3) ?? 0,
      totalBytes: row.columnAt(4) ?? 0,
    );
  }

  static Future<DownloadItem?> getDownload(int channelId) async {
    var db = await DbFactory.db;
    final row = await db.getOptional('''
      SELECT d.channel_id, d.file_path, d.status, d.bytes, d.total_bytes,
             c.id, c.name, c.group_name, c.image, c.url, c.media_type, c.source_id, c.favorite, c.series_id, c.group_id, c.stream_id
      FROM downloads d JOIN channels c ON c.id = d.channel_id
      WHERE d.channel_id = ?
      LIMIT 1
    ''', [channelId]);
    if (row == null) return null;
    return _rowToDownloadItem(row);
  }

  static Future<List<DownloadItem>> getAllDownloads() async {
    var db = await DbFactory.db;
    final results = await db.getAll('''
      SELECT d.channel_id, d.file_path, d.status, d.bytes, d.total_bytes,
             c.id, c.name, c.group_name, c.image, c.url, c.media_type, c.source_id, c.favorite, c.series_id, c.group_id, c.stream_id
      FROM downloads d JOIN channels c ON c.id = d.channel_id
      ORDER BY d.updated_at DESC
    ''');
    return results.map(_rowToDownloadItem).toList();
  }
}
