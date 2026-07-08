import 'dart:io' show File, FileSystemException, Platform;
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../datasources/local_music_dao.dart';
import '../datasources/local_music_query_data_source.dart';

const _unknownArtist = '未知歌手';
const _unknownAlbum = '未知专辑';
const _minimumTrackDurationMilliseconds = 60 * 1000;
const _callRecordingKeywords = <String>[
  'callrecord',
  'call_record',
  'call-record',
  'call recorder',
  'call_rec',
  'call rec',
  'recordings/call',
  'recording/call',
  'phone call',
  '通话录音',
  '电话录音',
  '录音/通话',
  '录音/电话',
  '/recordings/',
  '/recorder/',
  '/sound_recorder/',
  '/miui/sound_recorder/',
];

class LocalMusicRepositoryImpl implements LocalMusicRepository {
  LocalMusicRepositoryImpl(this._dataSource, this._metadataReader, this._dao);

  final LocalMusicQueryDataSource _dataSource;
  final LocalAudioMetadataReader _metadataReader;
  final LocalMusicDao _dao;

  @override
  Future<bool> requestPermission() {
    return _dataSource.requestPermission();
  }

  /// 扫描本地歌曲并写入 Drift DB
  ///
  /// 两阶段策略：
  /// 1. 轻量元数据扫描（不含封面）→ 写入 DB
  /// 2. 后台封面提取（由调用方触发，见 kq6 任务）
  @override
  Future<List<LocalSong>> scanSongs() async {
    // macOS：从数据库读取用户配置的扫描目录
    // 注意：不要自动插入默认目录，macOS App Sandbox 会阻止未授权的访问
    // 用户需要通过文件夹管理器明确选择要扫描的目录
    final scanFolders = Platform.isMacOS
        ? await _dao.getEnabledScanFolders('macos')
        : <String>[];
    final tracks = await _dataSource.scanSongs(scanFolders: scanFolders);

    final batchId = const Uuid().v4();
    final scanSource = _detectScanSource();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companions = <LocalSongsCompanion>[];
    for (final track in tracks) {
      final metadata = await _metadataReader.read(
        track.filePath,
        fetchArtwork: false,
      );
      // 合并时长：优先使用元数据中的实际时长
      final effectiveDuration =
          metadata?.duration?.inMilliseconds ?? track.duration;
      final effectiveTrack = LocalMusicQueryTrack(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: effectiveDuration,
        filePath: track.filePath,
        mimeType: track.mimeType,
        size: track.size,
        artwork: track.artwork,
      );

      if (_shouldKeepTrack(effectiveTrack)) {
        final song = _buildCompanion(
          effectiveTrack,
          metadata,
          scanSource,
          batchId,
          now,
        );
        companions.add(song);
      }
    }

    // 写入 DB（ON CONFLICT UPSERT）
    await _dao.upsertSongs(companions, scanSource, batchId);

    // 为每首歌曲关联歌手
    for (final song in companions) {
      final artistStr = song.artist.value;
      if (artistStr.isNotEmpty) {
        // 分割歌手字符串（支持 " / " 分隔符）
        final artistNames = artistStr
            .split(RegExp(r'\s*/\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (artistNames.isNotEmpty) {
          await _dao.linkSongToArtists(song.id.value, artistNames);
        }
      }
    }

    // 清理旧批次数据
    await _dao.deleteStaleBySource(scanSource, batchId);

    // 返回写入的歌曲列表
    return companions
        .map(
          (c) => LocalSong(
            id: c.id.value,
            title: c.title.value,
            filePath: c.filePath.value,
            artist: c.artist.value,
            album: c.album.value,
            duration: Duration(milliseconds: c.durationMs.value),
            mimeType: c.mimeType.value,
            size: c.fileSize.value,
            genre: c.genre.value,
            year: c.year.value,
            discNumber: c.discNumber.value,
            trackNumber: c.trackNumber.value,
            folderPath: c.folderPath.value,
            bitrate: c.bitrate.value,
            sampleRate: c.sampleRate.value,
          ),
        )
        .toList();
  }

  @override
  Stream<List<LocalSong>> watchSongs({
    String? searchQuery,
    String sortBy = 'title',
    bool ascending = true,
  }) => _dao.watchSongs(
    searchQuery: searchQuery,
    sortBy: sortBy,
    ascending: ascending,
  );

  @override
  Stream<List<LocalSong>> watchSongsByArtist(String artistName) =>
      _dao.watchSongsByArtist(artistName);

  @override
  Stream<List<LocalSong>> watchSongsByAlbum(String albumName) =>
      _dao.watchSongsByAlbum(albumName);

  @override
  Stream<List<ArtistGroup>> watchArtists() => _dao.watchArtists();

  @override
  Stream<List<AlbumGroup>> watchAlbums() => _dao.watchAlbums();

  @override
  Stream<List<GenreGroup>> watchGenres() => _dao.watchGenres();

  @override
  Future<void> incrementPlayCount(String songId) =>
      _dao.incrementPlayCount(songId);

  @override
  Future<void> clearLibrary() => _dao.clearAll();

  @override
  Future<void> markMetadataEdited(String songId) =>
      _dao.markMetadataEdited(songId);

  @override
  Future<void> markFileMissing(String songId) => _dao.markFileMissing(songId);

  // ========== 内部工具 ==========

  String _detectScanSource() {
    if (Platform.isAndroid) return 'android';
    // macOS 必须在 iOS 之前检查，否则 macOS 上 Platform.isIOS 也为 true
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'macos';
  }

  bool _shouldKeepTrack(LocalMusicQueryTrack track) {
    // duration < 0 表示文件系统扫描的未知时长，跳过时长过滤（后续元数据解析会补充）
    if (track.duration >= 0 &&
        track.duration <= _minimumTrackDurationMilliseconds) {
      return false;
    }
    final path = track.filePath.trim().toLowerCase();
    final fileName = Uri.file(track.filePath).pathSegments.last.toLowerCase();
    for (final keyword in _callRecordingKeywords) {
      if (path.contains(keyword) || fileName.contains(keyword)) {
        return false;
      }
    }
    return true;
  }

  /// 构建 Drift 写入对象
  LocalSongsCompanion _buildCompanion(
    LocalMusicQueryTrack track,
    LocalAudioMetadata? metadata,
    String scanSource,
    String batchId,
    int now,
  ) {
    final fileName = Uri.file(track.filePath).pathSegments.last;
    final rawName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final parsed = _parseFileName(rawName);

    final title = _pickText(
      primary: metadata?.title ?? track.title,
      fallback: parsed.title,
    );
    final artist = _pickText(
      primary: metadata?.artist ?? track.artist,
      fallback: parsed.artist,
    );
    final album = _pickText(
      primary: metadata?.album ?? track.album,
      fallback: parsed.album,
    );
    final durationMs = _pickDurationMilliseconds(
      metadata?.duration?.inMilliseconds ?? track.duration,
    );

    // 提取文件夹路径（仅 Android/macOS）
    final folderPath = scanSource != 'ios' ? _parentPath(track.filePath) : null;
    // 文件修改时间用于后续增量判断；文件不可读时保留扫描时间作为兜底。
    final modifiedAt = scanSource != 'ios'
        ? _readModifiedAt(track.filePath, fallback: now)
        : null;

    return LocalSongsCompanion(
      id: Value(track.id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      genre: Value(metadata?.genre ?? ''),
      year: Value(metadata?.year),
      discNumber: Value(metadata?.discNumber),
      trackNumber: Value(metadata?.trackNumber),
      durationMs: Value(durationMs),
      filePath: Value(track.filePath),
      folderPath: Value(folderPath),
      fileSize: Value(track.size),
      mimeType: Value(track.mimeType),
      bitrate: Value(metadata?.bitrate),
      sampleRate: Value(metadata?.sampleRate),
      hasArtwork: const Value(0),
      metadataEdited: const Value(0),
      status: const Value('active'),
      scanBatchId: Value(batchId),
      scanSource: Value(scanSource),
      createdAt: Value(now),
      updatedAt: Value(now),
      modifiedAt: Value(modifiedAt),
    );
  }

  String _pickText({required String? primary, required String fallback}) {
    return _normalizeLocalValue(primary) ?? fallback;
  }

  int _pickDurationMilliseconds(int milliseconds) {
    return milliseconds > 0 ? milliseconds : 0;
  }

  String? _normalizeLocalValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '<unknown>') {
      return null;
    }
    return normalized;
  }

  String? _parentPath(String filePath) {
    final segments = filePath.split('/');
    if (segments.length <= 1) return null;
    return segments.sublist(0, segments.length - 1).join('/');
  }

  int _readModifiedAt(String filePath, {required int fallback}) {
    try {
      return File(filePath).statSync().modified.millisecondsSinceEpoch;
    } on FileSystemException {
      return fallback;
    }
  }

  _ParsedLocalSongMeta _parseFileName(String rawName) {
    final normalized = rawName
        .replaceAll('_', ' ')
        .replaceAll(' - ', ' - ')
        .trim();
    final segments = normalized
        .split(' - ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (segments.length >= 3) {
      return _ParsedLocalSongMeta(
        artist: segments.first,
        album: segments[1],
        title: segments.sublist(2).join(' - '),
      );
    }
    if (segments.length == 2) {
      return _ParsedLocalSongMeta(
        artist: segments.first,
        album: _unknownAlbum,
        title: segments.last,
      );
    }
    return _ParsedLocalSongMeta(
      artist: _unknownArtist,
      album: _unknownAlbum,
      title: normalized,
    );
  }
}

class _ParsedLocalSongMeta {
  const _ParsedLocalSongMeta({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}
