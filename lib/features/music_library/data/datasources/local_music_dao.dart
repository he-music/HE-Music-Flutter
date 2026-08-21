import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';

/// 本地音乐数据访问对象
///
/// 封装 Drift 数据库操作，提供歌曲的 CRUD、分组查询、增量扫描清理等功能。
class LocalMusicDao {
  LocalMusicDao(this._db);

  final LocalMusicDatabase _db;

  static const _upsertSongSql =
      'INSERT INTO local_songs '
      '(id, title, artist, album, genre, year, disc_number, track_number, '
      'duration_ms, file_path, folder_path, file_size, mime_type, '
      'bitrate, sample_rate, has_artwork, metadata_edited, status, '
      'scan_batch_id, scan_source, created_at, updated_at, modified_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'title = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.title ELSE excluded.title END, '
      'artist = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.artist ELSE excluded.artist END, '
      'album = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.album ELSE excluded.album END, '
      'genre = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.genre ELSE excluded.genre END, '
      'year = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.year ELSE excluded.year END, '
      'disc_number = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.disc_number ELSE excluded.disc_number END, '
      'track_number = CASE WHEN local_songs.metadata_edited = 1 THEN local_songs.track_number ELSE excluded.track_number END, '
      'duration_ms = excluded.duration_ms, '
      'file_size = excluded.file_size, '
      'mime_type = excluded.mime_type, '
      'bitrate = excluded.bitrate, '
      'sample_rate = excluded.sample_rate, '
      'modified_at = excluded.modified_at, '
      'folder_path = excluded.folder_path, '
      'scan_batch_id = excluded.scan_batch_id, '
      'scan_source = excluded.scan_source, '
      'updated_at = excluded.updated_at';

  // ========== 查询 ==========

  /// 监听歌曲列表，支持搜索、排序、分页
  ///
  /// [searchQuery] 非空时按 title/artist/album 模糊匹配
  /// [sortBy] 排序字段：title/artist/album/duration/size/created_at/play_count/last_played_at
  /// [ascending] 是否升序
  /// [offset] 分页偏移
  /// [limit] 每页数量，默认 50
  Stream<List<LocalSong>> watchSongs({
    String? searchQuery,
    String sortBy = 'title',
    bool ascending = true,
    int offset = 0,
    int limit = 50,
  }) {
    final query = _db.select(_db.localSongs);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final pattern = '%${searchQuery.replaceAll('%', '\\%')}%';
      query.where(
        (t) =>
            t.title.like(pattern) |
            t.artist.like(pattern) |
            t.album.like(pattern),
      );
    }
    query.where((t) => t.status.equals('active'));
    query.orderBy([
      (t) => OrderingTerm(
        expression: _sortColumn(t, sortBy),
        mode: ascending ? OrderingMode.asc : OrderingMode.desc,
      ),
    ]);
    query.limit(limit, offset: offset);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// 读取指定平台已有歌曲行，供扫描流程按文件指纹跳过未变化的标签解析。
  Future<Map<String, LocalSongRow>> getSongRowsBySource(
    String scanSource,
  ) async {
    final rows = await (_db.select(
      _db.localSongs,
    )..where((song) => song.scanSource.equals(scanSource))).get();
    return <String, LocalSongRow>{for (final row in rows) row.id: row};
  }

  /// 监听指定艺术家的歌曲（使用关联表）
  Stream<List<LocalSong>> watchSongsByArtist(String artistName) {
    final query =
        _db.select(_db.localSongs).join([
            innerJoin(
              _db.songArtists,
              _db.songArtists.songId.equalsExp(_db.localSongs.id),
            ),
            innerJoin(
              _db.artists,
              _db.artists.id.equalsExp(_db.songArtists.artistId),
            ),
          ])
          ..where(
            _db.artists.name.equals(artistName) &
                _db.localSongs.status.equals('active'),
          )
          ..orderBy([OrderingTerm.asc(_db.localSongs.trackNumber)]);

    return query.watch().map((rows) {
      // 去重（同一首歌可能有多个歌手关联）
      final songMap = <String, LocalSong>{};
      for (final row in rows) {
        final song = _toEntity(row.readTable(_db.localSongs));
        songMap[song.id] = song;
      }
      final result = songMap.values.toList();
      result.sort((a, b) => (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0));
      return result;
    });
  }

  /// 监听指定专辑的歌曲
  Stream<List<LocalSong>> watchSongsByAlbum(String albumName) {
    final query = _db.select(_db.localSongs)
      ..where((t) => t.album.equals(albumName) & t.status.equals('active'))
      ..orderBy([(t) => OrderingTerm.asc(t.trackNumber)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  /// 按艺术家分组（使用关联表，支持多歌手）
  Stream<List<ArtistGroup>> watchArtists() {
    return watchArtistsFromRelation();
  }

  // ========== 歌手管理 ==========

  /// 获取或创建歌手，返回歌手 ID
  Future<int> getOrCreateArtist(String name) async {
    // 尝试查找现有歌手
    final existing = await (_db.select(
      _db.artists,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    // 创建新歌手
    return _db.into(_db.artists).insert(ArtistsCompanion(name: Value(name)));
  }

  /// 为歌曲关联歌手（支持多个歌手）
  Future<void> linkSongToArtists(
    String songId,
    List<String> artistNames,
  ) async {
    // 先删除旧的关联
    await (_db.delete(
      _db.songArtists,
    )..where((t) => t.songId.equals(songId))).go();

    // 添加新的关联
    for (final name in artistNames) {
      if (name.trim().isEmpty) continue;
      final artistId = await getOrCreateArtist(name.trim());
      await _db
          .into(_db.songArtists)
          .insert(
            SongArtistsCompanion(
              songId: Value(songId),
              artistId: Value(artistId),
            ),
          );
    }
  }

  /// 获取歌曲的所有歌手
  Future<List<String>> getSongArtists(String songId) async {
    final query = _db.select(_db.songArtists).join([
      innerJoin(
        _db.artists,
        _db.artists.id.equalsExp(_db.songArtists.artistId),
      ),
    ])..where(_db.songArtists.songId.equals(songId));
    final rows = await query.get();
    return rows.map((row) => row.read(_db.artists.name) ?? '').toList();
  }

  /// 获取歌手的所有歌曲
  Future<List<String>> getArtistSongIds(String artistName) async {
    final query = _db.select(_db.songArtists).join([
      innerJoin(
        _db.artists,
        _db.artists.id.equalsExp(_db.songArtists.artistId),
      ),
    ])..where(_db.artists.name.equals(artistName));
    final rows = await query.get();
    return rows.map((row) => row.read(_db.songArtists.songId) ?? '').toList();
  }

  /// 按歌手分组（使用关联表）
  Stream<List<ArtistGroup>> watchArtistsFromRelation() {
    // 子查询：计算每个歌手的专辑数量
    final albumCountSubquery = CustomExpression<int>(
      '(SELECT COUNT(DISTINCT ls.album) FROM local_songs ls '
      'INNER JOIN song_artists sa ON sa.song_id = ls.id '
      'WHERE sa.artist_id = artists.id AND ls.status = \'active\')',
    );

    final query =
        _db.selectOnly(_db.artists).join([
            innerJoin(
              _db.songArtists,
              _db.songArtists.artistId.equalsExp(_db.artists.id),
            ),
          ])
          ..addColumns([
            _db.artists.name,
            _db.songArtists.songId.count(distinct: true),
            albumCountSubquery,
          ])
          ..groupBy([_db.artists.name])
          ..orderBy([OrderingTerm.asc(_db.artists.name)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ArtistGroup(
              name: row.read(_db.artists.name) ?? '',
              songCount:
                  row.read(_db.songArtists.songId.count(distinct: true)) ?? 0,
              albumCount: row.read(albumCountSubquery) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// 按专辑分组（含封面路径：取同专辑中有封面歌曲的 file_path）
  Stream<List<AlbumGroup>> watchAlbums() {
    // 子查询：同一专辑中 has_artwork=1 的任意一首歌的 file_path
    final artworkSubquery = CustomExpression<String>(
      '(SELECT file_path FROM local_songs AS s2 '
      'WHERE s2.album = local_songs.album AND s2.has_artwork = 1 '
      'AND s2.status = \'active\' LIMIT 1)',
    );
    final query = _db.selectOnly(_db.localSongs)
      ..addColumns([
        _db.localSongs.album,
        _db.localSongs.artist,
        _db.localSongs.id.count(),
        _db.localSongs.year.max(),
        artworkSubquery,
      ])
      ..where(_db.localSongs.status.equals('active'))
      ..groupBy([_db.localSongs.album])
      ..orderBy([OrderingTerm.asc(_db.localSongs.album)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => AlbumGroup(
              name: row.read(_db.localSongs.album) ?? '',
              artist: row.read(_db.localSongs.artist) ?? '',
              songCount: row.read(_db.localSongs.id.count()) ?? 0,
              year: row.read(_db.localSongs.year.max()),
              artworkPath: row.read(artworkSubquery),
            ),
          )
          .toList(),
    );
  }

  /// 按流派分组
  Stream<List<GenreGroup>> watchGenres() {
    final query = _db.selectOnly(_db.localSongs)
      ..addColumns([_db.localSongs.genre, _db.localSongs.id.count()])
      ..where(
        _db.localSongs.status.equals('active') &
            _db.localSongs.genre.isNotValue(''),
      )
      ..groupBy([_db.localSongs.genre])
      ..orderBy([OrderingTerm.asc(_db.localSongs.genre)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => GenreGroup(
              name: row.read(_db.localSongs.genre) ?? '',
              songCount: row.read(_db.localSongs.id.count()) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// 按文件夹分组（仅 Android/macOS）
  Stream<List<FolderGroup>> watchFolderGroups() {
    final query = _db.selectOnly(_db.localSongs)
      ..addColumns([_db.localSongs.folderPath, _db.localSongs.id.count()])
      ..where(
        _db.localSongs.status.equals('active') &
            _db.localSongs.folderPath.isNotNull(),
      )
      ..groupBy([_db.localSongs.folderPath])
      ..orderBy([OrderingTerm.asc(_db.localSongs.folderPath)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => FolderGroup(
              path: row.read(_db.localSongs.folderPath) ?? '',
              songCount: row.read(_db.localSongs.id.count()) ?? 0,
            ),
          )
          .toList(),
    );
  }

  // ========== 写入 ==========

  /// 批量插入或更新歌曲
  ///
  /// 按 id 去重（ON CONFLICT(id)），id 在各平台均为唯一标识。
  /// 使用 raw SQL 实现 UPSERT，支持对 metadata_edited=1 的记录保留用户编辑的标签字段。
  Future<void> upsertSongs(
    List<LocalSongsCompanion> songs,
    String scanSource,
    String batchId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(
      () => _upsertSongsInBatch(songs, scanSource, batchId, now),
    );
  }

  /// 原子提交一次扫描结果，避免歌曲、歌手关联和旧批次处于半完成状态。
  Future<void> commitScanBatch({
    required List<LocalSongsCompanion> songs,
    required Map<String, List<String>> artistsBySongId,
    required String scanSource,
    required String batchId,
    bool replaceOnlyProvidedArtists = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _upsertSongsInBatch(songs, scanSource, batchId, now);
      await _replaceSongArtistsForBatch(
        artistsBySongId,
        scanSource,
        batchId,
        replaceOnlyProvidedArtists: replaceOnlyProvidedArtists,
      );
      await _deleteStaleBySource(scanSource, batchId);
    });
  }

  /// 清理旧批次数据
  ///
  /// 删除指定平台下非当前批次且未被用户编辑过的记录。
  /// metadata_edited=1 的记录不会被删除。
  Future<void> deleteStaleBySource(
    String scanSource,
    String currentBatchId,
  ) async {
    await _db.transaction(
      () => _deleteStaleBySource(scanSource, currentBatchId),
    );
  }

  /// 标记文件缺失
  Future<void> markFileMissing(String songId) async {
    await (_db.update(_db.localSongs)..where((t) => t.id.equals(songId))).write(
      const LocalSongsCompanion(status: Value('missing')),
    );
  }

  /// 标记元数据已编辑
  Future<void> markMetadataEdited(String songId) async {
    await (_db.update(_db.localSongs)..where((t) => t.id.equals(songId))).write(
      const LocalSongsCompanion(metadataEdited: Value(1)),
    );
  }

  /// 更新歌曲元数据
  Future<void> updateSongMetadata({
    required String songId,
    required String title,
    required String artist,
    required String album,
    required String genre,
    int? year,
  }) async {
    await (_db.update(_db.localSongs)..where((t) => t.id.equals(songId))).write(
      LocalSongsCompanion(
        title: Value(title),
        artist: Value(artist),
        album: Value(album),
        genre: Value(genre),
        year: Value(year),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 获取没有封面的歌曲文件路径列表
  Future<List<String>> getSongsWithoutArtwork() async {
    final query = _db.select(_db.localSongs)
      ..where((t) => t.hasArtwork.equals(0) & t.status.equals('active'));
    final rows = await query.get();
    return rows.map((r) => r.filePath).toList();
  }

  /// 标记封面已提取
  Future<void> markArtworkExtracted(String songId) async {
    await (_db.update(_db.localSongs)..where((t) => t.id.equals(songId))).write(
      const LocalSongsCompanion(hasArtwork: Value(1)),
    );
  }

  /// 按文件路径标记封面已提取
  Future<void> markArtworkExtractedByFilePath(String filePath) async {
    await (_db.update(_db.localSongs)
          ..where((t) => t.filePath.equals(filePath)))
        .write(const LocalSongsCompanion(hasArtwork: Value(1)));
  }

  // ========== 播放统计 ==========

  /// 播放次数 +1，累计时长累加，更新最后播放时间
  Future<void> incrementPlayCount(String songId, {int durationMs = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      'INSERT INTO play_stats (song_id, play_count, total_duration_ms, last_played_at) '
      'VALUES (?, 1, ?, ?) '
      'ON CONFLICT(song_id) DO UPDATE SET '
      'play_count = play_stats.play_count + 1, '
      'total_duration_ms = play_stats.total_duration_ms + excluded.total_duration_ms, '
      'last_played_at = excluded.last_played_at',
      variables: [
        Variable.withString(songId),
        Variable.withInt(durationMs),
        Variable.withInt(now),
      ],
    );
  }

  // ========== 清除 ==========

  /// 清除全部本地歌曲数据（先删关联表再删主表，避免 FK 约束冲突）
  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.playStats).go();
      await _db.delete(_db.songArtists).go();
      await _db.delete(_db.localSongs).go();
    });
  }

  // ========== 文件夹管理 ==========

  /// 获取指定平台的扫描文件夹列表（包含 bookmark）
  Future<List<ScanFolder>> getScanFolders(String platform) async {
    final query = _db.select(_db.scanFolders)
      ..where((t) => t.platform.equals(platform))
      ..orderBy([(t) => OrderingTerm.asc(t.path)]);
    return query.get();
  }

  /// 获取指定平台已启用的扫描文件夹路径列表
  Future<List<String>> getEnabledScanFolders(String platform) async {
    final query = _db.select(_db.scanFolders)
      ..where((t) => t.platform.equals(platform) & t.enabled.equals(1))
      ..orderBy([(t) => OrderingTerm.asc(t.path)]);
    final rows = await query.get();
    return rows.map((r) => r.path).toList();
  }

  /// 获取指定平台已启用的扫描文件夹（包含 bookmark）
  Future<List<ScanFolder>> getEnabledScanFoldersWithBookmarks(
    String platform,
  ) async {
    final query = _db.select(_db.scanFolders)
      ..where((t) => t.platform.equals(platform) & t.enabled.equals(1))
      ..orderBy([(t) => OrderingTerm.asc(t.path)]);
    return query.get();
  }

  /// 添加扫描文件夹（带 security-scoped bookmark）
  Future<void> addScanFolder(
    String platform,
    String path, {
    String? bookmark,
  }) async {
    await _db.customInsert(
      'INSERT INTO scan_folders (platform, path, enabled, bookmark) '
      'VALUES (?, ?, 1, ?) '
      'ON CONFLICT(platform, path) DO UPDATE SET enabled = 1, bookmark = ?',
      variables: [
        Variable.withString(platform),
        Variable.withString(path),
        Variable.withString(bookmark ?? ''),
        Variable.withString(bookmark ?? ''),
      ],
    );
  }

  /// 删除扫描文件夹
  Future<void> removeScanFolder(String platform, String path) async {
    await (_db.delete(
      _db.scanFolders,
    )..where((t) => t.platform.equals(platform) & t.path.equals(path))).go();
  }

  /// 启用/禁用扫描文件夹
  Future<void> toggleScanFolder(
    String platform,
    String path,
    bool enabled,
  ) async {
    await (_db.update(_db.scanFolders)
          ..where((t) => t.platform.equals(platform) & t.path.equals(path)))
        .write(ScanFoldersCompanion(enabled: Value(enabled ? 1 : 0)));
  }

  // ========== 内部工具 ==========

  Future<void> _upsertSongsInBatch(
    List<LocalSongsCompanion> songs,
    String scanSource,
    String batchId,
    int now,
  ) async {
    if (songs.isEmpty) return;
    final updates = <TableUpdate>{
      TableUpdate.onTable(_db.localSongs, kind: UpdateKind.insert),
    };
    await _db.batch((batch) {
      for (final song in songs) {
        batch.customStatement(_upsertSongSql, <Object?>[
          song.id.value,
          song.title.value,
          song.artist.value,
          song.album.value,
          song.genre.value,
          song.year.value,
          song.discNumber.value,
          song.trackNumber.value,
          song.durationMs.value,
          song.filePath.value,
          song.folderPath.value,
          song.fileSize.value,
          song.mimeType.value,
          song.bitrate.value,
          song.sampleRate.value,
          'active',
          batchId,
          scanSource,
          now,
          now,
          song.modifiedAt.value,
        ], updates);
      }
    });
  }

  Future<void> _replaceSongArtistsForBatch(
    Map<String, List<String>> artistsBySongId,
    String scanSource,
    String batchId, {
    required bool replaceOnlyProvidedArtists,
  }) async {
    final currentSongs =
        await (_db.select(_db.localSongs)..where(
              (song) =>
                  song.scanSource.equals(scanSource) &
                  song.scanBatchId.equals(batchId),
            ))
            .get();
    if (currentSongs.isEmpty) return;
    final songsToReplace = replaceOnlyProvidedArtists
        ? currentSongs
              .where((song) => artistsBySongId.containsKey(song.id))
              .toList(growable: false)
        : currentSongs;
    if (songsToReplace.isEmpty) return;

    // 已编辑歌曲以数据库内保留的 artist 为准，避免重新扫描破坏关联。
    final effectiveArtists = <String, List<String>>{};
    final uniqueArtistNames = <String>{};
    for (final song in songsToReplace) {
      final names = _normalizeArtistNames(
        song.metadataEdited == 1
            ? _splitArtistNames(song.artist)
            : artistsBySongId[song.id] ?? _splitArtistNames(song.artist),
      );
      effectiveArtists[song.id] = names;
      uniqueArtistNames.addAll(names);
    }

    if (uniqueArtistNames.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAll(
          _db.artists,
          uniqueArtistNames.map((name) => ArtistsCompanion(name: Value(name))),
          mode: InsertMode.insertOrIgnore,
        );
      });
    }

    final artistIds = <String, int>{
      for (final artist in await _db.select(_db.artists).get())
        artist.name: artist.id,
    };
    await _db.batch((batch) {
      for (final song in songsToReplace) {
        batch.deleteWhere(
          _db.songArtists,
          (relation) => relation.songId.equals(song.id),
        );
        for (final name in effectiveArtists[song.id]!) {
          final artistId = artistIds[name];
          if (artistId == null) continue;
          batch.insert(
            _db.songArtists,
            SongArtistsCompanion(
              songId: Value(song.id),
              artistId: Value(artistId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }

  Future<void> _deleteStaleBySource(
    String scanSource,
    String currentBatchId,
  ) async {
    const staleWhere =
        'scan_source = ? AND scan_batch_id != ? AND metadata_edited = 0';
    final variables = <Variable<String>>[
      Variable.withString(scanSource),
      Variable.withString(currentBatchId),
    ];
    // 先清理依赖表，再删除歌曲，满足外键约束；批量 SQL 避免逐行删除放大扫描耗时。
    await _db.customUpdate(
      'DELETE FROM play_stats WHERE song_id IN '
      '(SELECT id FROM local_songs WHERE $staleWhere)',
      variables: variables,
      updates: {_db.playStats},
      updateKind: UpdateKind.delete,
    );
    await _db.customUpdate(
      'DELETE FROM song_artists WHERE song_id IN '
      '(SELECT id FROM local_songs WHERE $staleWhere)',
      variables: variables,
      updates: {_db.songArtists},
      updateKind: UpdateKind.delete,
    );
    await _db.customUpdate(
      'DELETE FROM local_songs WHERE $staleWhere',
      variables: variables,
      updates: {_db.localSongs},
      updateKind: UpdateKind.delete,
    );
  }

  List<String> _splitArtistNames(String artist) {
    return artist.split(RegExp(r'\s*/\s*'));
  }

  List<String> _normalizeArtistNames(Iterable<String> names) {
    return names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// 根据排序字段名返回对应的列表达式
  Expression<Object> _sortColumn(LocalSongs t, String sortBy) {
    switch (sortBy) {
      case 'artist':
        return t.artist;
      case 'album':
        return t.album;
      case 'duration':
        return t.durationMs;
      case 'size':
        return t.fileSize;
      case 'created_at':
        return t.createdAt;
      case 'play_count':
        return const CustomExpression('COALESCE(play_stats.play_count, 0)');
      case 'last_played_at':
        return const CustomExpression('COALESCE(play_stats.last_played_at, 0)');
      default:
        return t.title;
    }
  }

  /// Drift 行 → LocalSong 实体
  LocalSong _toEntity(LocalSongRow row) {
    return LocalSong(
      id: row.id,
      title: row.title,
      filePath: row.filePath,
      artist: row.artist,
      album: row.album,
      duration: Duration(milliseconds: row.durationMs),
      mimeType: row.mimeType,
      size: row.fileSize,
      genre: row.genre,
      year: row.year,
      discNumber: row.discNumber,
      trackNumber: row.trackNumber,
      folderPath: row.folderPath,
      bitrate: row.bitrate,
      sampleRate: row.sampleRate,
      hasArtwork: row.hasArtwork == 1,
      metadataEdited: row.metadataEdited == 1,
      status: row.status,
    );
  }
}

/// 文件夹分组
class FolderGroup {
  const FolderGroup({required this.path, required this.songCount});

  final String path;
  final int songCount;
}
