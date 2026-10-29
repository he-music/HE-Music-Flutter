import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_path_data_source.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/ios_media_library_scanner.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_query_data_source.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _Paths paths;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('local_download_scan_');
    paths = _Paths(root.path);
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = paths;
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  Future<File> audio(String relativePath) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    return file.writeAsBytes([1, 2, 3]);
  }

  test('macOS scans preferred, fallback and selected folders once', () async {
    final primary = await audio('downloads/HEMusic/new.mp3');
    final fallback = await audio('documents/HEMusic/old.flac');
    final selected = await audio('music/selected.m4a');
    final source = LocalMusicQueryDataSource(
      platform: 'macos',
      downloadPaths: DownloadPathDataSource(isIOS: false),
    );

    final result = await source.scanSongs(
      scanFolders: [primary.parent.path, selected.parent.path],
    );

    expect(result.isComplete, isTrue);
    expect(
      result.tracks.map((track) => track.filePath),
      unorderedEquals([primary.path, fallback.path, selected.path]),
    );
    expect(result.tracks, hasLength(3));
  });

  test('scanning does not create missing download folders', () async {
    final source = LocalMusicQueryDataSource(
      platform: 'macos',
      downloadPaths: DownloadPathDataSource(isIOS: false),
    );
    expect((await source.scanSongs()).tracks, isEmpty);
    expect(await Directory('${root.path}/downloads/HEMusic').exists(), isFalse);
    expect(await Directory('${root.path}/documents/HEMusic').exists(), isFalse);
  });

  test('download falls back to Documents and remains discoverable', () async {
    await File('${root.path}/downloads').writeAsString('not a directory');
    final downloadPaths = DownloadPathDataSource(isIOS: false);
    final directory = await downloadPaths.ensureDownloadDirectory();
    expect(directory.path, '${root.path}/documents/HEMusic');
    final file = await File('${directory.path}/fallback.mp3').writeAsBytes([1]);
    final source = LocalMusicQueryDataSource(
      platform: 'macos',
      downloadPaths: downloadPaths,
    );
    expect((await source.scanSongs()).tracks.single.filePath, file.path);
  });

  test(
    'iOS denial still discovers application downloads without querying media',
    () async {
      final file = await audio('documents/Downloads/song.mp3');
      final media = _MediaScanner(authorized: false);
      final source = LocalMusicQueryDataSource(
        platform: 'ios',
        iosScanner: media,
        downloadPaths: DownloadPathDataSource(isIOS: true),
      );

      expect(await source.requestPermission(), isTrue);
      expect(media.permissionRequests, 0);
      final result = await source.scanSongs();
      expect(result.tracks.single.filePath, file.path);
      expect(result.isComplete, isFalse);
      expect(media.permissionRequests, 1);
      expect(media.scanCalls, 0);
      expect(paths.downloadQueries, 0);
    },
  );

  test(
    'iOS authorized scan merges media library and application downloads',
    () async {
      final file = await audio('documents/Downloads/song.mp3');
      final media = _MediaScanner(authorized: true);
      final source = LocalMusicQueryDataSource(
        platform: 'ios',
        iosScanner: media,
        downloadPaths: DownloadPathDataSource(isIOS: true),
      );
      final result = await source.scanSongs();
      expect(result.isComplete, isTrue);
      expect(
        result.tracks.map((track) => track.filePath),
        unorderedEquals(['ipod-library://song.mp3?id=1', file.path]),
      );
      expect(media.scanCalls, 1);
    },
  );

  test(
    'queryFile accepts file URIs and ignores missing or unsupported files',
    () async {
      final file = await audio('documents/Downloads/song.mp3');
      final source = LocalMusicQueryDataSource(platform: 'ios');
      final track = await source.queryFile(file.uri.toString());
      expect(track!.id, file.path);
      expect(track.filePath, file.path);
      expect(track.size, 3);
      expect(
        track.modifiedAt,
        (await file.stat()).modified.millisecondsSinceEpoch,
      );
      expect(await source.queryFile('${root.path}/missing.mp3'), isNull);
      final other = await audio('documents/Downloads/lyric.lrc');
      expect(await source.queryFile(other.path), isNull);
    },
  );
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  int downloadQueries = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async => '$root/documents';

  @override
  Future<String?> getDownloadsPath() async {
    downloadQueries++;
    return '$root/downloads';
  }
}

class _MediaScanner extends IosMediaLibraryScanner {
  _MediaScanner({required this.authorized});
  final bool authorized;
  int permissionRequests = 0;
  int scanCalls = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return authorized;
  }

  @override
  Future<List<Map<String, dynamic>>> scanSongs() async {
    scanCalls++;
    return [
      {
        'id': '1',
        'title': 'Media song',
        'filePath': 'ipod-library://song.mp3?id=1',
        'duration': 180000,
      },
    ];
  }
}
