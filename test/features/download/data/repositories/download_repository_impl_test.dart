import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_path_data_source.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_runner_data_source.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_task_store_data_source.dart';
import 'package:he_music_flutter/features/download/data/repositories/download_repository_impl.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/download/domain/repositories/download_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository enqueues runner task with resolved save path', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform('/tmp/app');

    final savePath = await repository.resolveSavePath(
      title: '测试下载',
      artist: '歌手A / 歌手B',
      fileExtension: 'flac',
    );

    final enqueued = await repository.enqueueTask(
      DownloadEnqueueRequest(
        taskId: 'task-1',
        pluginTaskId: 'plugin-1',
        url: 'https://example.com/song.flac',
        savePath: savePath,
      ),
    );

    expect(enqueued, isTrue);
    expect(runner.enqueued.single.pluginTaskId, 'plugin-1');
    expect(savePath, '/tmp/app/HEMusic/测试下载 - 歌手A、歌手B.flac');
  });

  test(
    'repository preserves spaces and parentheses in download filename',
    () async {
      final runner = _FakeDownloadRunnerDataSource();
      final store = _FakeDownloadTaskStoreDataSource();
      final repository = DownloadRepositoryImpl(
        runner,
        store,
        DownloadPathDataSource(),
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform('/tmp/app');

      final savePath = await repository.resolveSavePath(
        title: 'Runway(Explicit)',
        artist: 'Lady Gaga, Doechii',
        fileExtension: 'mp3',
      );

      expect(
        savePath,
        '/tmp/app/HEMusic/Runway(Explicit) - Lady Gaga、Doechii.mp3',
      );
    },
  );

  test('repository replaces invalid filename characters only', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform('/tmp/app');

    final savePath = await repository.resolveSavePath(
      title: 'AC/DC: Live?',
      artist: 'Guns N\' Roses / Jay-Z',
      fileExtension: 'mp3',
    );

    expect(
      savePath,
      '/tmp/app/HEMusic/AC、DC、 Live、 - Guns N\' Roses、Jay-Z.mp3',
    );
  });

  test('repository persists and restores tasks through store', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
    );

    final task = DownloadTask(
      id: 'task-1',
      title: '夜曲',
      url: 'https://example.com/song.mp3',
      status: DownloadTaskStatus.queued,
      progress: 0,
      quality: DownloadTaskQuality(
        label: 'standard',
        bitrate: 320,
        fileExtension: 'mp3',
      ),
      tagWriteStatus: DownloadTagWriteStatus.pending,
      lyricFormat: DownloadLyricFormat.none,
      createdAt: DateTime(2026, 4, 9),
    );

    await repository.saveTask(task);
    final restored = await repository.restoreTasks();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'task-1');
    expect(restored.single.quality.label, 'standard');
  });

  test('repository reveals file in finder on macos', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final revealedPaths = <String>[];
    final launchedDirectories = <Uri>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      platformResolver: () => _FakePlatform(isMacOS: true),
      revealInFileManager: (filePath) async {
        revealedPaths.add(filePath);
      },
      openDirectory: (directoryUri) async {
        launchedDirectories.add(directoryUri);
        return true;
      },
    );

    await repository.openContainingFolder('/tmp/app/HEMusic/song.mp3');

    expect(revealedPaths, <String>['/tmp/app/HEMusic/song.mp3']);
    expect(launchedDirectories, isEmpty);
  });

  test('repository opens directory on non-macos platforms', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final revealedPaths = <String>[];
    final launchedDirectories = <Uri>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      platformResolver: () => _FakePlatform(isMacOS: false),
      revealInFileManager: (filePath) async {
        revealedPaths.add(filePath);
      },
      openDirectory: (directoryUri) async {
        launchedDirectories.add(directoryUri);
        return true;
      },
    );

    await repository.openContainingFolder('/tmp/app/HEMusic/song.mp3');

    expect(revealedPaths, isEmpty);
    expect(launchedDirectories, <Uri>[Uri.directory('/tmp/app/HEMusic/')]);
  });

  test('repository opens file directly on android', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final revealedPaths = <String>[];
    final launchedDirectories = <Uri>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      platformResolver: () => _FakePlatform(isAndroid: true, isMacOS: false),
      revealInFileManager: (filePath) async {
        revealedPaths.add(filePath);
      },
      openDirectory: (directoryUri) async {
        launchedDirectories.add(directoryUri);
        return true;
      },
    );

    await repository.openContainingFolder('/tmp/app/HEMusic/song.mp3');

    expect(revealedPaths, isEmpty);
    expect(launchedDirectories, isEmpty);
    expect(runner.openedFiles, hasLength(1));
    expect(runner.openedFiles.single.filePath, '/tmp/app/HEMusic/song.mp3');
    expect(runner.openedFiles.single.mimeType, 'audio/mpeg');
  });

  test('repository opens file directly on ios', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final revealedPaths = <String>[];
    final launchedDirectories = <Uri>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      platformResolver: () => _FakePlatform(isIOS: true, isMacOS: false),
      revealInFileManager: (filePath) async {
        revealedPaths.add(filePath);
      },
      openDirectory: (directoryUri) async {
        launchedDirectories.add(directoryUri);
        return true;
      },
    );

    await repository.openContainingFolder('/tmp/app/HEMusic/song.mp3');

    expect(revealedPaths, isEmpty);
    expect(launchedDirectories, isEmpty);
    expect(runner.openedFiles, hasLength(1));
    expect(runner.openedFiles.single.filePath, '/tmp/app/HEMusic/song.mp3');
    expect(runner.openedFiles.single.mimeType, 'audio/mpeg');
  });

  test('repository uses absolute open command for macos reveal', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final commands = <({String executable, List<String> arguments})>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      platformResolver: () => _FakePlatform(isMacOS: true),
      revealInFileManager: DownloadRepositoryImpl.buildRevealInFileManager(
        processRunner: (executable, arguments) async {
          commands.add((
            executable: executable,
            arguments: List<String>.from(arguments),
          ));
          return ProcessResult(0, 0, '', '');
        },
      ),
    );

    await repository.openContainingFolder('/tmp/app/HEMusic/song.mp3');

    expect(commands, hasLength(1));
    expect(commands.single.executable, 'open');
    expect(commands.single.arguments, <String>[
      '-R',
      '/tmp/app/HEMusic/song.mp3',
    ]);
  });

  test('repository exports audio and lyric files together', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final exported = <({String path, String? mimeType})>[];
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      shareFiles: (files, {sharePositionOrigin}) async {
        exported.addAll(
          files.map((file) => (path: file.path, mimeType: file.mimeType)),
        );
        expect(sharePositionOrigin, isNull);
      },
    );

    await repository.exportFiles(
      filePath: '/tmp/app/HEMusic/song.mp3',
      lyricPath: '/tmp/app/HEMusic/song.lrc',
    );

    expect(exported, <({String path, String? mimeType})>[
      (path: '/tmp/app/HEMusic/song.mp3', mimeType: 'audio/mpeg'),
      (path: '/tmp/app/HEMusic/song.lrc', mimeType: 'application/octet-stream'),
    ]);
  });

  test('repository forwards share position origin to share handler', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final exported = <({String path, String? mimeType})>[];
    Rect? receivedSharePositionOrigin;
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
      shareFiles: (files, {sharePositionOrigin}) async {
        exported.addAll(
          files.map((file) => (path: file.path, mimeType: file.mimeType)),
        );
        receivedSharePositionOrigin = sharePositionOrigin;
      },
    );
    const sharePositionOrigin = Rect.fromLTWH(16, 32, 28, 28);

    await repository.exportFiles(
      filePath: '/tmp/app/HEMusic/song.mp3',
      lyricPath: '/tmp/app/HEMusic/song.lrc',
      sharePositionOrigin: sharePositionOrigin,
    );

    expect(exported, <({String path, String? mimeType})>[
      (path: '/tmp/app/HEMusic/song.mp3', mimeType: 'audio/mpeg'),
      (path: '/tmp/app/HEMusic/song.lrc', mimeType: 'application/octet-stream'),
    ]);
    expect(receivedSharePositionOrigin, sharePositionOrigin);
  });

  test(
    'repository deletes downloaded audio and lyric files when requested',
    () async {
      final runner = _FakeDownloadRunnerDataSource();
      final store = _FakeDownloadTaskStoreDataSource();
      final repository = DownloadRepositoryImpl(
        runner,
        store,
        DownloadPathDataSource(),
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'download-repo-test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final audioFile = File('${tempDir.path}/song.mp3');
      final lyricFile = File('${tempDir.path}/song.lrc');
      await audioFile.writeAsString('audio');
      await lyricFile.writeAsString('lyric');

      await repository.deleteDownloadedArtifacts(
        filePath: audioFile.path,
        lyricPath: lyricFile.path,
      );

      expect(await audioFile.exists(), isFalse);
      expect(await lyricFile.exists(), isFalse);
    },
  );

  test('repository ignores missing downloaded artifacts', () async {
    final runner = _FakeDownloadRunnerDataSource();
    final store = _FakeDownloadTaskStoreDataSource();
    final repository = DownloadRepositoryImpl(
      runner,
      store,
      DownloadPathDataSource(),
    );

    await repository.deleteDownloadedArtifacts(
      filePath: '/tmp/not-found-song.mp3',
      lyricPath: '/tmp/not-found-song.lrc',
    );
  });
}

class _FakeDownloadRunnerDataSource extends DownloadRunnerDataSource {
  _FakeDownloadRunnerDataSource() : super(null);

  final List<DownloadEnqueueRequest> enqueued = <DownloadEnqueueRequest>[];
  final List<({String filePath, String? mimeType})> openedFiles =
      <({String filePath, String? mimeType})>[];

  @override
  Future<bool> enqueue(DownloadEnqueueRequest request) async {
    enqueued.add(request);
    return true;
  }

  @override
  Future<void> download({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) async {
    onProgress(1);
  }

  @override
  Stream<DownloadRunnerEvent> watchEvents() {
    return const Stream<DownloadRunnerEvent>.empty();
  }

  @override
  Future<bool> openFile({required String filePath, String? mimeType}) async {
    openedFiles.add((filePath: filePath, mimeType: mimeType));
    return true;
  }
}

class _FakeDownloadTaskStoreDataSource extends DownloadTaskStoreDataSource {
  final List<DownloadTask> _tasks = <DownloadTask>[];

  @override
  Future<List<DownloadTask>> loadTasks() async {
    return List<DownloadTask>.from(_tasks);
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    _tasks
      ..removeWhere((item) => item.id == task.id)
      ..add(task);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getDownloadsPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FakePlatform implements PlatformInfo {
  const _FakePlatform({
    this.isAndroid = false,
    this.isIOS = false,
    required this.isMacOS,
  });

  @override
  final bool isAndroid;

  @override
  final bool isIOS;

  @override
  final bool isMacOS;
}
