import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_music_database.g.dart';

/// 本地歌曲表
@DataClassName('LocalSongRow')
class LocalSongs extends Table {
  @override
  String get tableName => 'local_songs';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get genre => text().withDefault(const Constant(''))();
  IntColumn get year => integer().nullable()();
  IntColumn get discNumber => integer().named('disc_number').nullable()();
  IntColumn get trackNumber => integer().named('track_number').nullable()();
  IntColumn get durationMs => integer().named('duration_ms')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get folderPath => text().named('folder_path').nullable()();
  IntColumn get fileSize => integer().named('file_size')();
  TextColumn get mimeType => text().named('mime_type')();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().named('sample_rate').nullable()();
  IntColumn get hasArtwork =>
      integer().named('has_artwork').withDefault(const Constant(0))();
  IntColumn get metadataEdited =>
      integer().named('metadata_edited').withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get scanBatchId => text().named('scan_batch_id')();
  TextColumn get scanSource => text().named('scan_source')();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get modifiedAt => integer().named('modified_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 播放统计表
class PlayStats extends Table {
  @override
  String get tableName => 'play_stats';

  TextColumn get songId =>
      text().named('song_id').references(LocalSongs, #id)();
  IntColumn get playCount =>
      integer().named('play_count').withDefault(const Constant(0))();
  IntColumn get totalDurationMs =>
      integer().named('total_duration_ms').withDefault(const Constant(0))();
  IntColumn get lastPlayedAt => integer().named('last_played_at').nullable()();

  @override
  Set<Column> get primaryKey => {songId};
}

/// macOS 扫描文件夹配置表
class ScanFolders extends Table {
  @override
  String get tableName => 'scan_folders';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text()();
  TextColumn get path => text()();
  IntColumn get enabled => integer().withDefault(const Constant(1))();
  TextColumn get bookmark => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {platform, path},
  ];
}

/// 歌手表
class Artists extends Table {
  @override
  String get tableName => 'artists';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}

/// 歌曲-歌手关联表（多对多）
class SongArtists extends Table {
  @override
  String get tableName => 'song_artists';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get songId => text().references(LocalSongs, #id)();
  IntColumn get artistId => integer().references(Artists, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {songId, artistId},
  ];
}

/// 本地音乐数据库
///
/// 使用 Drift + SQLite 持久化本地歌曲、播放统计、扫描文件夹配置和歌手信息。
/// 数据库文件存储在应用文档目录下。
@DriftDatabase(
  tables: [LocalSongs, PlayStats, ScanFolders, Artists, SongArtists],
)
class LocalMusicDatabase extends _$LocalMusicDatabase {
  LocalMusicDatabase() : super(_openConnection());

  /// 测试用构造函数，允许传入自定义 QueryExecutor
  LocalMusicDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(scanFolders, scanFolders.bookmark);
      }
      if (from < 3) {
        await m.createTable(artists);
        await m.createTable(songArtists);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'local_music.db'));
    return NativeDatabase.createInBackground(file);
  });
}
