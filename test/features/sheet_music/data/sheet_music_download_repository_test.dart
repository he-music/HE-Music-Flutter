import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/sheet_music/data/repositories/sheet_music_download_repository_impl.dart';
import 'package:he_music_flutter/features/sheet_music/domain/repositories/sheet_music_download_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
  );

  test(
    'page downloads preserve original bytes and infer extension from content instead of URL',
    () async {
      final requests = <RequestOptions>[];
      final destination = _Destination();
      final repository = SheetMusicDownloadRepositoryImpl(_dio(png, requests));
      await repository.downloadPage(
        destination: destination,
        url: 'https://cdn.example.com/picture.jpg?signature=token',
        title: '歌/曲',
        pageIndex: 11,
      );
      expect(destination.bytes, png);
      expect(destination.fileName, '歌_曲_012.png');
      expect(requests.single.responseType, ResponseType.bytes);
      expect(requests.single.headers.containsKey('Authorization'), false);
    },
  );

  test('empty and HTML error payloads are not saved as images', () async {
    for (final bytes in [<int>[], utf8.encode('<html>sign in</html>')]) {
      final destination = _Destination();
      final repository = SheetMusicDownloadRepositoryImpl(_dio(bytes, []));
      await expectLater(
        repository.downloadPage(
          destination: destination,
          url: 'https://cdn.example.com/file.png',
          title: '曲谱',
          pageIndex: 0,
        ),
        throwsA(isA<SheetMusicSaveException>()),
      );
      expect(destination.bytes, isNull);
    }
  });

  test('filenames remain safe for directories and preserve Unicode', () {
    expect(sheetMusicFileStem('  ../a:b*?  '), '.._a_b__');
    expect(sheetMusicFileStem('... '), 'sheet_music');
    expect(sheetMusicFileStem('乐谱🎵'), '乐谱🎵');
    expect(sheetMusicFileStem('🎵' * 80).runes.length, 48);
  });

  test(
    'iOS requests add-only access once and copies the original file to Photos',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final temporary = await Directory.systemTemp.createTemp(
        'sheet-save-test-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(temporary.path);
      addTearDown(() => PathProviderPlatform.instance = oldPaths);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      const gallery = MethodChannel('com.fluttercandies/saver_gallery');
      var permissionRequests = 0;
      final savedPaths = <String>[];
      messenger.setMockMethodCallHandler(permissions, (call) async {
        expect(call.method, 'requestPermissions');
        permissionRequests++;
        final requested = (call.arguments as List).cast<int>();
        expect(requested, [10]); // Permission.photosAddOnly
        return {for (final value in requested) value: 1};
      });
      messenger.setMockMethodCallHandler(gallery, (call) async {
        expect(call.method, 'saveFileToGallery');
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final path = args['filePath'] as String;
        savedPaths.add(path);
        expect(await File(path).readAsBytes(), png);
        expect(args['skipIfExists'], false);
        return {'isSuccess': true};
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(permissions, null);
        messenger.setMockMethodCallHandler(gallery, null);
      });
      final repository = SheetMusicDownloadRepositoryImpl(_dio(png, []));
      final destination = (await repository.prepare('曲谱'))!;
      await repository.downloadPage(
        destination: destination,
        url: 'https://cdn.example.com/1',
        title: '曲谱',
        pageIndex: 0,
      );
      await repository.downloadPage(
        destination: destination,
        url: 'https://cdn.example.com/2',
        title: '曲谱',
        pageIndex: 1,
      );
      expect(permissionRequests, 1);
      expect(savedPaths.map((path) => path.split('/').last), [
        '曲谱_001.png',
        '曲谱_002.png',
      ]);
      expect(await temporary.list().toList(), isEmpty);
    },
  );
  test(
    'desktop selection creates a collection folder and writes ordered original images',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = await Directory.systemTemp.createTemp(
        'sheet-desktop-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var selections = 0;
      final repository = SheetMusicDownloadRepositoryImpl(
        _dio(png, []),
        selectDirectory: () async {
          selections++;
          return directory.path;
        },
      );
      final destination = (await repository.prepare('练习曲'))!;
      await repository.downloadPage(
        destination: destination,
        url: 'https://cdn.example.com/2',
        title: '练习曲',
        pageIndex: 0,
      );
      await repository.downloadPage(
        destination: destination,
        url: 'https://cdn.example.com/1',
        title: '练习曲',
        pageIndex: 1,
      );
      expect(selections, 1);
      final files = await Directory(destination.directoryPath!).list().toList();
      expect(files.map((file) => file.uri.pathSegments.last).toList()..sort(), [
        '练习曲_001.png',
        '练习曲_002.png',
      ]);
      for (final file in files) {
        expect(await File(file.path).readAsBytes(), png);
      }
    },
  );

  test('cancelled desktop directory picker creates no destination', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = SheetMusicDownloadRepositoryImpl(
      _dio(png, []),
      selectDirectory: () async => null,
    );
    expect(await repository.prepare('曲谱'), isNull);
  });
}

Dio _dio(List<int> bytes, List<RequestOptions> requests) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        requests.add(request);
        handler.resolve(
          Response(requestOptions: request, statusCode: 200, data: bytes),
        );
      },
    ),
  );
  return dio;
}

class _Destination extends SheetMusicDownloadDestination {
  Uint8List? bytes;
  String? fileName;
  @override
  String? get directoryPath => null;
  @override
  Future<void> save(Uint8List bytes, String fileName) async {
    this.bytes = bytes;
    this.fileName = fileName;
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}
