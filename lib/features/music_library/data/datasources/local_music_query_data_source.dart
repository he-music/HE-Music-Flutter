import 'dart:io';

import 'package:local_audio_scan/local_audio_scan.dart' as local_audio_scan;
import 'package:path_provider/path_provider.dart';

import 'ios_media_library_scanner.dart';

class LocalMusicQueryTrack {
  const LocalMusicQueryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    required this.mimeType,
    required this.size,
    this.artwork,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String filePath;
  final String mimeType;
  final int size;
  final List<int>? artwork;
}

class LocalMusicQueryDataSource {
  final local_audio_scan.LocalAudioScanner _scanner =
      local_audio_scan.LocalAudioScanner();
  final IosMediaLibraryScanner _iosScanner = IosMediaLibraryScanner();

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return _scanner.requestPermission();
    }
    // macOS 必须在 iOS 之前检查，否则 macOS 上 Platform.isIOS 也为 true
    if (Platform.isMacOS) {
      return true;
    }
    if (Platform.isIOS) {
      return _iosScanner.requestPermission();
    }
    return false;
  }

  Future<List<LocalMusicQueryTrack>> scanSongs({
    List<String> scanFolders = const [],
  }) async {
    if (Platform.isAndroid) {
      final tracks = await _scanner.scanTracks(
        includeArtwork: true,
        filterJunkAudio: true,
      );
      return tracks
          .map(
            (track) => LocalMusicQueryTrack(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album,
              duration: track.duration,
              filePath: track.filePath,
              mimeType: track.mimeType,
              size: track.size,
              artwork: track.artwork,
            ),
          )
          .toList(growable: false);
    }
    // macOS 必须在 iOS 之前检查，否则 macOS 上 Platform.isIOS 也为 true
    if (Platform.isMacOS) {
      return _scanMacOsTracks(scanFolders);
    }
    if (Platform.isIOS) {
      return _scanIosTracks();
    }
    return const <LocalMusicQueryTrack>[];
  }

  Future<List<LocalMusicQueryTrack>> _scanIosTracks() async {
    // 1. 扫描系统音乐库（Apple Music / iTunes 同步的歌曲）
    final rawTracks = await _iosScanner.scanSongs();
    final results = rawTracks
        .map(
          (track) => LocalMusicQueryTrack(
            id: track['id'] as String? ?? '',
            title: track['title'] as String? ?? '',
            artist: track['artist'] as String? ?? '',
            album: track['album'] as String? ?? '',
            duration: track['duration'] as int? ?? 0,
            filePath: track['filePath'] as String? ?? '',
            mimeType: track['mimeType'] as String? ?? '',
            size: track['size'] as int? ?? 0,
          ),
        )
        .toList(growable: true);

    // 2. 扫描 App 沙盒内的下载目录（App 自身下载的歌曲）
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${docsDir.path}/Downloads');
    if (await downloadDir.exists()) {
      final seenPaths = <String>{...results.map((t) => t.filePath)};
      final entities = downloadDir.listSync(recursive: true, followLinks: true);
      for (final entity in entities) {
        if (entity is! File) continue;
        if (!_isSupportedAudioFile(entity.path)) continue;
        if (!seenPaths.add(entity.path)) continue;
        final stat = entity.statSync();
        results.add(
          LocalMusicQueryTrack(
            id: entity.path,
            title: '',
            artist: '',
            album: '',
            duration: -1,
            filePath: entity.path,
            mimeType: _guessMimeType(entity.path),
            size: stat.size,
          ),
        );
      }
    }

    return results;
  }

  Future<List<LocalMusicQueryTrack>> _scanMacOsTracks(
    List<String> scanFolders,
  ) async {
    // macOS App Sandbox 限制：自动插入的默认目录（如 ~/Music）可能无法访问
    // 需要用户通过文件选择器明确授权才能访问
    if (scanFolders.isEmpty) {
      return const <LocalMusicQueryTrack>[];
    }

    final results = <LocalMusicQueryTrack>[];
    // 用规范化路径去重，避免符号链接/重复目录导致同一文件被扫描多次
    final seenCanonicalPaths = <String>{};

    for (final dirPath in scanFolders) {
      // 先解析符号链接获取真实路径，沙盒内符号链接不能直接遍历
      var actualDirPath = dirPath;
      try {
        final resolved = await Directory(dirPath).resolveSymbolicLinks();
        actualDirPath = resolved;
      } catch (_) {
        // 无法解析符号链接，跳过该目录
        continue;
      }

      final dir = Directory(actualDirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: true,
        )) {
          if (entity is! File) continue;
          final entityPath = entity.path;
          if (!_isSupportedAudioFile(entityPath)) continue;
          // 用原始配置路径重建文件路径，保持用户期望的显示路径
          final relativePath = entityPath.replaceFirst(dir.path, '');
          final filePath = '$dirPath$relativePath';
          // 规范化路径用于去重
          final canonicalPath = await entity.resolveSymbolicLinks();
          if (!seenCanonicalPaths.add(canonicalPath)) continue;
          final stat = await entity.stat();
          results.add(
            LocalMusicQueryTrack(
              id: filePath,
              title: '',
              artist: '',
              album: '',
              duration: -1, // 未知时长，由后续元数据解析补充
              filePath: filePath,
              mimeType: _guessMimeType(filePath),
              size: stat.size,
            ),
          );
        }
      } catch (e) {
        // 跳过无法访问的目录（如未授权的沙盒目录）
        continue;
      }
    }
    return results;
  }

  bool _isSupportedAudioFile(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.endsWith('.mp3') ||
        normalized.endsWith('.flac') ||
        normalized.endsWith('.m4a') ||
        normalized.endsWith('.aac') ||
        normalized.endsWith('.wav') ||
        normalized.endsWith('.ogg') ||
        normalized.endsWith('.opus') ||
        normalized.endsWith('.ape') ||
        normalized.endsWith('.aiff') ||
        normalized.endsWith('.aif');
  }

  String _guessMimeType(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (normalized.endsWith('.flac')) {
      return 'audio/flac';
    }
    if (normalized.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (normalized.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (normalized.endsWith('.wav') ||
        normalized.endsWith('.aiff') ||
        normalized.endsWith('.aif')) {
      return 'audio/wav';
    }
    if (normalized.endsWith('.ogg') || normalized.endsWith('.opus')) {
      return 'audio/ogg';
    }
    if (normalized.endsWith('.ape')) {
      return 'audio/ape';
    }
    return '';
  }
}
