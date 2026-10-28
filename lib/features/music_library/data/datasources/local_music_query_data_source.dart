import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_audio_scan/local_audio_scan.dart' as local_audio_scan;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

class LocalMusicQueryDataSource {
  static const androidChannel = MethodChannel('com.hemusic/local_audio_query');
  final local_audio_scan.LocalAudioScanner _scanner =
      local_audio_scan.LocalAudioScanner();
  final IosMediaLibraryScanner _iosScanner = IosMediaLibraryScanner();

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) return _scanner.requestPermission();
    if (Platform.isMacOS) return true;
    if (Platform.isIOS) return _iosScanner.requestPermission();
    return false;
  }

  Future<List<LocalMusicQueryTrack>> scanSongs({
    List<String> scanFolders = const [],
  }) async {
    if (Platform.isAndroid) {
      // DATE_MODIFIED is returned by MediaStore in milliseconds, avoiding one
      // synchronous filesystem stat per song on the Dart UI isolate.
      final tracks = await androidChannel.invokeListMethod<dynamic>(
        'scanSongs',
      );
      if (tracks == null) throw StateError('Audio query returned no result');
      return tracks
          .map((track) => _fromMap(Map<String, dynamic>.from(track as Map)))
          .toList(growable: false);
    }
    if (Platform.isMacOS) return _scanFiles(scanFolders);
    if (Platform.isIOS) return _scanIosTracks();
    return const [];
  }

  Future<List<LocalMusicQueryTrack>> _scanIosTracks() async {
    final results = (await _iosScanner.scanSongs()).map(_fromMap).toList();
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${docsDir.path}/Downloads');
    if (await downloadDir.exists()) {
      final seenPaths = results.map((track) => track.filePath).toSet();
      results.addAll(
        (await _scanFiles([
          downloadDir.path,
        ])).where((track) => seenPaths.add(track.filePath)),
      );
    }
    return results;
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
