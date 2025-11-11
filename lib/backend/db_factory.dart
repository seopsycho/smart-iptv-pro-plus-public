import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:sqlite_async/sqlite_async.dart';

class DbFactory {
  static SqliteDatabase? _db;

  static Future<SqliteDatabase> _createDB() async {
    var db = SqliteDatabase(path: "${await Utils.appDir}/db.sqlite");
    var migrations = SqliteMigrations()
      ..add(SqliteMigration(1, (tx) async {
        await tx.execute('''
        CREATE TABLE "sources" (
          "id"          INTEGER PRIMARY KEY,
          "name"        varchar(100),
          "source_type" integer,
          "url"         varchar(500),
          "username"    varchar(100),
          "password"    varchar(100),
          "enabled"     integer DEFAULT 1
        );
        ''');
        await tx.execute('''
        CREATE TABLE "channels" (
          "id" INTEGER PRIMARY KEY,
          "name" varchar(100),
          "group_name" varchar(100),
          "image" varchar(500),
          "url" varchar(500),
          "media_type" integer,
          "source_id" integer,
          "favorite" integer,
          "series_id" integer,
          "group_id" integer,
          "stream_id" integer,
          FOREIGN KEY (source_id) REFERENCES sources(id)
          FOREIGN KEY (group_id) REFERENCES groups(id)
        );
        ''');
        await tx.execute('''
        CREATE TABLE "channel_http_headers" (
            "id" INTEGER PRIMARY KEY,
            "channel_id" integer,
            "referrer" varchar(500),
            "user_agent" varchar(500),
            "http_origin" varchar(500),
            "ignore_ssl" integer DEFAULT 0,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
        );
        ''');
        await tx.execute('''
        CREATE TABLE "movie_positions" (
          "id" INTEGER PRIMARY KEY,
          "channel_id" integer,
          "position" int,
          FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
        )
        ''');
        await tx.execute('''
        CREATE TABLE "settings" (
          "key" VARCHAR(50) PRIMARY KEY,
          "value" VARCHAR(100)
        );
        ''');
        await tx.execute('''
          CREATE TABLE "groups" (
            "id" INTEGER PRIMARY KEY,
            "name" varchar(100),
            "image" varchar(500),
            "source_id" integer,
            FOREIGN KEY (source_id) REFERENCES sources(id)
          );
        ''');
        await tx
            .execute('''CREATE INDEX index_channel_name ON channels(name);''');
        await tx.execute(
            '''CREATE UNIQUE INDEX channels_unique ON channels(name, source_id);''');
        await tx.execute(
            '''CREATE UNIQUE INDEX index_source_name ON sources(name);''');
        await tx.execute(
            '''CREATE INDEX index_source_enabled ON sources(enabled);''');
        await tx.execute(
            '''CREATE UNIQUE INDEX index_group_unique ON groups(name, source_id);''');
        await tx.execute('''CREATE INDEX index_group_name ON groups(name);''');
        await tx.execute(
            '''CREATE INDEX index_channel_source_id ON channels(source_id);''');
        await tx.execute(
            '''CREATE INDEX index_channel_favorite ON channels(favorite);''');
        await tx.execute(
            '''CREATE INDEX index_channel_series_id ON channels(series_id);''');
        await tx.execute(
            '''CREATE INDEX index_channel_group_id ON channels(group_id);''');
        await tx.execute(
            '''CREATE INDEX index_channel_media_type ON channels(media_type);''');
        await tx.execute(
            '''CREATE INDEX index_channels_stream_id ON channels(stream_id);''');
        await tx.execute(
            '''CREATE INDEX index_channels_group_name ON channels(group_name);''');
        await tx.execute(
            '''CREATE INDEX index_group_source_id ON groups(source_id);''');
        await tx.execute('''
          CREATE UNIQUE INDEX index_channel_http_headers_channel_id ON channel_http_headers(channel_id);
        ''');
        await tx.execute('''
          CREATE UNIQUE INDEX index_movie_positions_channel_id ON movie_positions(channel_id);
        ''');
      }))
      ..add(SqliteMigration(2, (tx) async {
        await tx.execute('''
          ALTER TABLE channels
          ADD COLUMN last_watched integer;
        ''');
        await tx.execute('''
          CREATE INDEX index_channel_last_watched ON channels(last_watched);
        ''');
      }))
      ..add(SqliteMigration(3, (tx) async {
        await tx.execute('''
          ALTER TABLE groups
          ADD COLUMN media_type integer;
        ''');
        await tx.execute('''
          CREATE INDEX index_groups_media_type ON groups(media_type);
        ''');
      }))
      ..add(SqliteMigration(4, (tx) async {
        await tx.execute('''
          ALTER TABLE groups
          ADD COLUMN hidden integer DEFAULT 0;
        ''');
        await tx.execute('''
          ALTER TABLE groups
          ADD COLUMN position integer;
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_groups_hidden ON groups(hidden);
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_groups_position ON groups(position);
        ''');
      }))
      ..add(SqliteMigration(5, (tx) async {
        await tx.execute('''
          CREATE TABLE "downloads" (
            "id" INTEGER PRIMARY KEY,
            "channel_id" integer UNIQUE,
            "file_path" varchar(1000),
            "status" integer,
            "bytes" integer,
            "total_bytes" integer,
            "created_at" integer,
            "updated_at" integer,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
          );
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_downloads_status ON downloads(status);
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_downloads_updated_at ON downloads(updated_at);
        ''');
      }))
      ..add(SqliteMigration(6, (tx) async {
        await tx.execute('''
          ALTER TABLE channels
          ADD COLUMN created_at integer;
        ''');
        await tx.execute('''
          ALTER TABLE channels
          ADD COLUMN updated_at integer;
        ''');
        await tx.execute('''
          UPDATE channels
          SET created_at = strftime('%s','now')
          WHERE created_at IS NULL;
        ''');
        await tx.execute('''
          UPDATE channels
          SET updated_at = created_at
          WHERE updated_at IS NULL;
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_channel_created_at ON channels(created_at);
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_channel_updated_at ON channels(updated_at);
        ''');
      }))
      ..add(SqliteMigration(7, (tx) async {
        final exists = await tx.getOptional(
            "SELECT 1 FROM pragma_table_info('downloads') WHERE name = 'fail_reason' LIMIT 1");
        if (exists == null) {
          await tx.execute('''
            ALTER TABLE downloads
            ADD COLUMN fail_reason varchar(500);
          ''');
        }
      }))
      ..add(SqliteMigration(8, (tx) async {
        await tx.execute('''
          CREATE TABLE "home_flags" (
            "channel_id" integer PRIMARY KEY,
            "hide_recent" integer DEFAULT 0,
            "hide_all" integer DEFAULT 0,
            "pinned" integer DEFAULT 0,
            FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
          );
        ''');
        await tx.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS index_home_flags_channel_id ON home_flags(channel_id);
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_home_flags_hide_all ON home_flags(hide_all);
        ''');
        await tx.execute('''
          CREATE INDEX IF NOT EXISTS index_home_flags_pinned ON home_flags(pinned);
        ''');
      }));
    await migrations.migrate(db);
    // Improve concurrency: readers don't block writers and vice-versa
    try {
      await db.execute("PRAGMA journal_mode=WAL;");
      await db.execute("PRAGMA synchronous=NORMAL;");
      await db.execute("PRAGMA busy_timeout=5000;");
    } catch (_) {}
    return db;
  }

  static Future<SqliteDatabase> get db async {
    if (_db == null) {
      _db = await _createDB();
      return _db!;
    }
    // Detect ClosedException or invalid state and reopen
    try {
      await _db!.get("SELECT 1");
    } catch (_) {
      _db = await _createDB();
    }
    return _db!;
  }

  // Allow callers to force a reopen (e.g., after fatal errors)
  static void reset() {
    _db = null;
  }
}
