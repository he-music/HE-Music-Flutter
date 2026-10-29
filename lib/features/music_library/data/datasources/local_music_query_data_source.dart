import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_audio_scan/local_audio_scan.dart' as local_audio_scan;
import 'package:path/path.dart' as p;
import '../../../download/data/datasources/download_path_data_source.dart';

import 'ios_media_library_scanner.dart';
import 'local_music_file_scanner.dart';

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
    this.modifiedAt,
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
  final int? modifiedAt;
  final List<int>? artwork;
}

class LocalMusicScanResult {
  const LocalMusicScanResult(this.tracks, {this.isComplete = true});

  final List<LocalMusicQueryTrack> tracks;
  // Revoked media-library access must not delete songs we could not inspect.
  final bool isComplete;
}

class LocalMusicQueryDataSource {
  LocalMusicQueryDataSource({
    DownloadPathDataSource? downloadPaths,
    IosMediaLibraryScanner? iosScanner,
    String? platform,
  }) : platform = platform ?? Platform.operatingSystem,
       _downloadPaths = downloadPaths ?? DownloadPathDataSource(),
       _iosScanner = iosScanner ?? IosMediaLibraryScanner();

  static const androidChannel = MethodChannel('com.hemusic/local_audio_query');
  final String platform;
  final DownloadPathDataSource _downloadPaths;
  final IosMediaLibraryScanner _iosScanner;
  final local_audio_scan.LocalAudioScanner _scanner =
      local_audio_scan.LocalAudioScanner();

  Future<bool> requestPermission() async {
    if (platform == 'android') return _scanner.requestPermission();
    // Application downloads remain readable without system media-library access.
    return platform == 'macos' || platform == 'ios';
  }

  Future<LocalMusicScanResult> scanSongs({
    List<String> scanFolders = const [],
  }) async {
    if (platform == 'android') {
      final tracks = await androidChannel.invokeListMethod<dynamic>(
        'scanSongs',
      );
      if (tracks == null) throw StateError('Audio query returned no result');
      return LocalMusicScanResult(
        tracks
            .map((track) => _fromMap(Map<String, dynamic>.from(track as Map)))
            .toList(growable: false),
      );
    }
    if (platform == 'macos') {
      final downloads = await _downloadPaths.existingDownloadDirectories();
      return LocalMusicScanResult(
        await _scanFiles([
          ...scanFolders,
          ...downloads.map((directory) => directory.path),
        ]),
      );
    }
    if (platform == 'ios') return _scanIosTracks();
    return const LocalMusicScanResult([]);
  }

  Future<LocalMusicScanResult> _scanIosTracks() async {
    final hasMediaAccess = await _iosScanner.requestPermission();
    final results = hasMediaAccess
        ? (await _iosScanner.scanSongs()).map(_fromMap).toList()
        : <LocalMusicQueryTrack>[];
    final downloads = await _downloadPaths.existingDownloadDirectories();
    final seenPaths = results.map((track) => track.filePath).toSet();
    results.addAll(
      (await _scanFiles(
        downloads.map((directory) => directory.path).toList(),
      )).where((track) => seenPaths.add(track.filePath)),
    );
    return LocalMusicScanResult(results, isComplete: hasMediaAccess);
  }

  /// Read only the final downloaded file; no directory or media-library scan.
  Future<LocalMusicQueryTrack?> queryFile(String filePath) async {
    final file = filePath.startsWith('file:')
        ? File.fromUri(Uri.parse(filePath))
        : File(filePath);
    if (!LocalMusicFileScanner.isSupportedAudioFile(file.path)) return null;
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;
    return LocalMusicQueryTrack(
      id: file.path,
      title: '',
      artist: '',
      album: '',
      duration: -1,
      filePath: file.path,
      mimeType: _guessMimeType(file.path),
      size: stat.size,
      modifiedAt: stat.modified.millisecondsSinceEpoch,
    );
  }

  Future<List<LocalMusicQueryTrack>> _scanFiles(List<String> folders) async {
    final files = await const LocalMusicFileScanner().scan(folders);
    return files
        .map(
          (file) => LocalMusicQueryTrack(
            id: file.path,
            title: '',
            artist: '',
            album: '',
            duration: -1,
            filePath: file.path,
            mimeType: _guessMimeType(file.path),
            size: file.size,
            modifiedAt: file.modifiedAt,
          ),
        )
        .toList(growable: false);
  }

  LocalMusicQueryTrack _fromMap(Map<String, dynamic> track) =>
      LocalMusicQueryTrack(
        id: track['id'] as String? ?? '',
        title: track['title'] as String? ?? '',
        artist: track['artist'] as String? ?? '',
        album: track['album'] as String? ?? '',
        duration: track['duration'] as int? ?? 0,
        filePath: track['filePath'] as String? ?? '',
        mimeType: track['mimeType'] as String? ?? '',
        size: track['size'] as int? ?? 0,
        modifiedAt: track['modifiedAt'] as int?,
      );

  String _guessMimeType(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.mp3' => 'audio/mpeg',
        '.flac' => 'audio/flac',
        '.m4a' => 'audio/mp4',
        '.aac' => 'audio/aac',
        '.wav' || '.aiff' || '.aif' => 'audio/wav',
        '.ogg' || '.opus' => 'audio/ogg',
        '.ape' => 'audio/ape',
        _ => '',
      };
}
