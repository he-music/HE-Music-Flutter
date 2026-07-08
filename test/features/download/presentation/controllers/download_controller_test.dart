import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/data/services/download_lyric_resolver.dart';
import 'package:he_music_flutter/features/download/data/services/download_metadata_writer.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/download/domain/repositories/download_repository.dart';
import 'package:he_music_flutter/features/download/presentation/providers/download_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  test('controller restores persisted tasks on build', () async {
    final repository = _FakeDownloadRepository(
      initialTasks: <DownloadTask>[
        DownloadTask(
          id: 'task-1',
          title: '已恢复任务',
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
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(downloadControllerProvider);
    expect(state.tasks, hasLength(1));
    expect(state.tasks.single.title, '已恢复任务');
  });

  test(
    'enqueue resolves save path first and fetches url when dispatch starts',
    () async {
      final repository = _FakeDownloadRepository();
      final online = _FakeOnlineController();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: '测试下载',
            songId: 'song-1',
            platform: 'qq',
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(downloadControllerProvider);
      expect(repository.resolveSavePathCalls, 2);
      expect(online.fetchSongUrlCalls, 1);
      expect(repository.enqueueTaskRequests, hasLength(1));
      expect(repository.downloadFileCalls, 0);
      expect(state.tasks, hasLength(1));
      expect(state.tasks.first.status, DownloadTaskStatus.preparing);
      expect(state.tasks.first.url, 'https://example.com/song.mp3');
      expect(state.tasks.first.filePath, '/tmp/测试下载.mp3');
    },
  );

  test('enqueue uses artist in resolved save path when available', () async {
    final repository = _FakeDownloadRepository();
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
        onlineControllerProvider.overrideWith(() => online),
      ],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .enqueue(
          title: '夜曲',
          songId: 'song-1',
          platform: 'qq',
          artist: '周杰伦 / 五月天',
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(downloadControllerProvider);
    expect(state.tasks.first.filePath, '/tmp/夜曲 - 周杰伦 / 五月天.mp3');
  });

  test('dispatch fetches url when queued task starts', () async {
    final repository = _FakeDownloadRepository();
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
        onlineControllerProvider.overrideWith(() => online),
      ],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .enqueue(
          title: '测试下载',
          songId: 'song-1',
          platform: 'qq',
          quality: DownloadTaskQuality(
            label: 'lossless',
            bitrate: 999,
            fileExtension: 'flac',
          ),
        );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(online.fetchSongUrlCalls, 1);
    expect(repository.enqueueTaskRequests, hasLength(1));
    expect(
      repository.enqueueTaskRequests.single.url,
      'https://example.com/song.flac',
    );
    expect(repository.enqueueTaskRequests.single.savePath, '/tmp/测试下载.flac');
  });

  test(
    'dispatch uses final format for file path but keeps selected quality',
    () async {
      final repository = _FakeDownloadRepository();
      final online = _FakeOnlineController(resolvedFormat: 'flac');
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: '格式回退测试',
            songId: 'song-1',
            platform: 'qq',
            quality: DownloadTaskQuality(
              label: 'hq',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final task = container.read(downloadControllerProvider).tasks.single;
      expect(task.quality.label, 'hq');
      expect(task.quality.bitrate, 320);
      expect(task.quality.fileExtension, 'mp3');
      expect(task.effectiveFileExtension, 'flac');
      expect(task.filePath, '/tmp/格式回退测试.flac');
      expect(
        repository.enqueueTaskRequests.single.savePath,
        '/tmp/格式回退测试.flac',
      );
    },
  );

  test('runner events drive progress and completion state', () async {
    final repository = _FakeDownloadRepository();
    final metadataWriter = _FakeDownloadMetadataWriter();
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
        downloadMetadataWriterProvider.overrideWithValue(metadataWriter),
        onlineControllerProvider.overrideWith(() => online),
      ],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .enqueue(
          title: '测试下载',
          songId: 'song-1',
          platform: 'qq',
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
        );
    await Future<void>.delayed(Duration.zero);
    final pluginTaskId = repository.enqueueTaskRequests.single.pluginTaskId;

    repository.emit(
      DownloadRunnerEvent(
        pluginTaskId: pluginTaskId,
        status: DownloadRunnerStatus.running,
        progress: 0.4,
        expectedFileSize: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var state = container.read(downloadControllerProvider);
    expect(state.tasks.first.status, DownloadTaskStatus.downloading);
    expect(state.tasks.first.progress, 0.4);
    expect(state.tasks.first.downloadedBytes, 400);
    expect(state.tasks.first.totalBytes, 1000);

    repository.emit(
      DownloadRunnerEvent(
        pluginTaskId: pluginTaskId,
        status: DownloadRunnerStatus.complete,
        filePath: '/tmp/测试下载.mp3',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    state = container.read(downloadControllerProvider);
    expect(state.tasks.first.status, DownloadTaskStatus.completed);
    expect(state.tasks.first.progress, 1);
    expect(state.tasks.first.filePath, '/tmp/测试下载.mp3');
    expect(state.tasks.first.downloadedBytes, 1000);
    expect(state.tasks.first.totalBytes, 1000);
    expect(metadataWriter.requests, isEmpty);
  });

  test(
    'complete event triggers metadata tagging when task has metadata payload',
    () async {
      final repository = _FakeDownloadRepository();
      final metadataWriter = _FakeDownloadMetadataWriter(
        result: const DownloadMetadataWriteResult(
          lyricFormat: DownloadLyricFormat.timed,
          artworkEmbedded: true,
          lyricPath: '/tmp/测试下载.lrc',
        ),
      );
      final online = _FakeOnlineController();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadMetadataWriterProvider.overrideWithValue(metadataWriter),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: '测试下载',
            songId: 'song-1',
            platform: 'qq',
            artist: '周杰伦',
            album: '十一月的萧邦',
            artworkUrl: 'https://example.com/cover.jpg',
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
          );
      await Future<void>.delayed(Duration.zero);
      final pluginTaskId = repository.enqueueTaskRequests.single.pluginTaskId;

      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: pluginTaskId,
          status: DownloadRunnerStatus.complete,
          filePath: '/tmp/测试下载.mp3',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(downloadControllerProvider);
      expect(metadataWriter.requests, hasLength(1));
      expect(state.tasks.first.status, DownloadTaskStatus.completed);
      expect(state.tasks.first.tagWriteStatus, DownloadTagWriteStatus.success);
      expect(state.tasks.first.lyricFormat, DownloadLyricFormat.timed);
      expect(state.tasks.first.lyricPath, '/tmp/测试下载.lrc');
    },
  );

  test(
    'complete event skips metadata state write after container dispose',
    () async {
      final repository = _FakeDownloadRepository();
      final metadataWriter = _FakeDownloadMetadataWriter(
        result: const DownloadMetadataWriteResult(
          lyricFormat: DownloadLyricFormat.timed,
          artworkEmbedded: true,
          lyricPath: '/tmp/测试下载.lrc',
        ),
        delay: const Duration(milliseconds: 10),
      );
      final online = _FakeOnlineController();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadMetadataWriterProvider.overrideWithValue(metadataWriter),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: '测试下载',
            songId: 'song-1',
            platform: 'qq',
            artist: '周杰伦',
            album: '十一月的萧邦',
            artworkUrl: 'https://example.com/cover.jpg',
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
          );
      await Future<void>.delayed(Duration.zero);
      final pluginTaskId = repository.enqueueTaskRequests.single.pluginTaskId;

      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: pluginTaskId,
          status: DownloadRunnerStatus.complete,
          filePath: '/tmp/测试下载.mp3',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(metadataWriter.requests, isEmpty);
    },
  );

  test(
    'android complete flow moves audio and lyric to public downloads',
    () async {
      final repository = _FakeDownloadRepository(
        isAndroid: true,
        moveToPublicDownloadsResult:
            '/storage/emulated/0/Download/HEMusic/测试下载.mp3',
        moveLyricToPublicDownloadsResult:
            '/storage/emulated/0/Download/HEMusic/测试下载.lrc',
      );
      final metadataWriter = _FakeDownloadMetadataWriter(
        result: const DownloadMetadataWriteResult(
          lyricFormat: DownloadLyricFormat.timed,
          artworkEmbedded: true,
          lyricPath: '/tmp/测试下载.lrc',
        ),
      );
      final online = _FakeOnlineController();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadMetadataWriterProvider.overrideWithValue(metadataWriter),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: '测试下载',
            songId: 'song-1',
            platform: 'qq',
            artist: '周杰伦',
            album: '十一月的萧邦',
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
          );
      await Future<void>.delayed(Duration.zero);
      final pluginTaskId = repository.enqueueTaskRequests.single.pluginTaskId;

      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: pluginTaskId,
          status: DownloadRunnerStatus.complete,
          filePath: '/tmp/测试下载.mp3',
        ),
      );
      await _waitForCondition(() {
        final task = container.read(downloadControllerProvider).tasks.first;
        return repository.moveToPublicDownloadsCalls.length == 2 &&
            task.status == DownloadTaskStatus.completed;
      });

      final state = container.read(downloadControllerProvider);
      expect(repository.moveToPublicDownloadsCalls, hasLength(2));
      expect(
        repository.moveToPublicDownloadsCalls.first.filePath,
        '/tmp/测试下载.mp3',
      );
      expect(
        repository.moveToPublicDownloadsCalls.first.mimeType,
        'audio/mpeg',
      );
      expect(
        repository.moveToPublicDownloadsCalls.last.filePath,
        '/tmp/测试下载.lrc',
      );
      expect(
        repository.moveToPublicDownloadsCalls.last.mimeType,
        'application/octet-stream',
      );
      expect(state.tasks.first.status, DownloadTaskStatus.completed);
      expect(
        state.tasks.first.filePath,
        '/storage/emulated/0/Download/HEMusic/测试下载.mp3',
      );
      expect(
        state.tasks.first.lyricPath,
        '/storage/emulated/0/Download/HEMusic/测试下载.lrc',
      );
    },
  );

  test('metadata tagging failure marks task as failed', () async {
    final repository = _FakeDownloadRepository();
    final metadataWriter = _FakeDownloadMetadataWriter(
      error: StateError('tagging failed'),
    );
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
        downloadMetadataWriterProvider.overrideWithValue(metadataWriter),
        onlineControllerProvider.overrideWith(() => online),
      ],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .enqueue(
          title: '测试下载',
          songId: 'song-1',
          platform: 'qq',
          artist: '周杰伦',
          album: '十一月的萧邦',
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
        );
    await Future<void>.delayed(Duration.zero);
    final pluginTaskId = repository.enqueueTaskRequests.single.pluginTaskId;

    repository.emit(
      DownloadRunnerEvent(
        pluginTaskId: pluginTaskId,
        status: DownloadRunnerStatus.complete,
        filePath: '/tmp/测试下载.mp3',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final state = container.read(downloadControllerProvider);
    expect(metadataWriter.requests, hasLength(1));
    expect(state.tasks.first.status, DownloadTaskStatus.failed);
    expect(state.tasks.first.tagWriteStatus, DownloadTagWriteStatus.failed);
    expect(state.tasks.first.errorMessage, contains('tagging failed'));
  });

  test('pause delegates to repository and marks task paused', () async {
    final repository = _FakeDownloadRepository(
      initialTasks: <DownloadTask>[
        DownloadTask(
          id: 'task-1',
          title: '测试下载',
          url: 'https://example.com/song.mp3',
          status: DownloadTaskStatus.downloading,
          progress: 0.4,
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.pending,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(downloadControllerProvider.notifier).pause('task-1');

    expect(repository.pauseTaskCalls, <String>['task-1']);
    expect(
      container.read(downloadControllerProvider).tasks.single.status,
      DownloadTaskStatus.paused,
    );
  });

  test('resume delegates to repository and marks task preparing', () async {
    final repository = _FakeDownloadRepository(
      initialTasks: <DownloadTask>[
        DownloadTask(
          id: 'task-1',
          title: '测试下载',
          url: 'https://example.com/song.mp3',
          status: DownloadTaskStatus.paused,
          progress: 0.4,
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.pending,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(downloadControllerProvider.notifier).resume('task-1');

    expect(repository.resumeTaskCalls, <String>['task-1']);
    expect(
      container.read(downloadControllerProvider).tasks.single.status,
      DownloadTaskStatus.preparing,
    );
  });

  test('redownload resets completed task and dispatches it again', () async {
    final repository = _FakeDownloadRepository(
      initialTasks: <DownloadTask>[
        DownloadTask(
          id: 'task-1',
          title: '测试下载',
          url: '',
          songId: 'song-1',
          platform: 'qq',
          status: DownloadTaskStatus.completed,
          progress: 1,
          quality: DownloadTaskQuality(
            label: 'lossless',
            bitrate: 999,
            fileExtension: 'flac',
          ),
          tagWriteStatus: DownloadTagWriteStatus.success,
          lyricFormat: DownloadLyricFormat.timed,
          createdAt: DateTime(2026, 4, 9),
          filePath: '/tmp/测试下载.flac',
        ),
      ],
    );
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
        onlineControllerProvider.overrideWith(() => online),
      ],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .redownload('task-1');
    await Future<void>.delayed(Duration.zero);

    expect(online.fetchSongUrlCalls, 1);
    expect(repository.enqueueTaskRequests, hasLength(1));
    final task = container.read(downloadControllerProvider).tasks.single;
    expect(task.status, DownloadTaskStatus.preparing);
    expect(task.progress, 0);
    expect(task.tagWriteStatus, DownloadTagWriteStatus.pending);
    expect(task.lyricFormat, DownloadLyricFormat.none);
  });

  test('openContainingFolder delegates file path to repository', () async {
    final repository = _FakeDownloadRepository(
      initialTasks: <DownloadTask>[
        DownloadTask(
          id: 'task-1',
          title: '测试下载',
          url: 'https://example.com/song.mp3',
          status: DownloadTaskStatus.completed,
          progress: 1,
          quality: DownloadTaskQuality(
            label: 'standard',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.success,
          lyricFormat: DownloadLyricFormat.timed,
          createdAt: DateTime(2026, 4, 9),
          filePath: '/tmp/测试下载.mp3',
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(downloadControllerProvider.notifier)
        .openContainingFolder('task-1');

    expect(repository.openContainingFolderCalls, <String>['/tmp/测试下载.mp3']);
  });

  test(
    'exportFiles delegates audio, lyric paths and share origin to repository',
    () async {
      final repository = _FakeDownloadRepository(
        initialTasks: <DownloadTask>[
          DownloadTask(
            id: 'task-1',
            title: '测试下载',
            url: 'https://example.com/song.mp3',
            status: DownloadTaskStatus.completed,
            progress: 1,
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
            tagWriteStatus: DownloadTagWriteStatus.success,
            lyricFormat: DownloadLyricFormat.timed,
            createdAt: DateTime(2026, 4, 9),
            filePath: '/tmp/测试下载.mp3',
            lyricPath: '/tmp/测试下载.lrc',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      const sharePositionOrigin = Rect.fromLTWH(24, 48, 36, 36);
      await container
          .read(downloadControllerProvider.notifier)
          .exportFiles('task-1', sharePositionOrigin: sharePositionOrigin);

      expect(repository.exportFilesCalls, hasLength(1));
      expect(repository.exportFilesCalls.single, (
        filePath: '/tmp/测试下载.mp3',
        lyricPath: '/tmp/测试下载.lrc',
        sharePositionOrigin: sharePositionOrigin,
      ));
    },
  );

  test(
    'removeTask removes persisted task without deleting downloaded files',
    () async {
      final repository = _FakeDownloadRepository(
        initialTasks: <DownloadTask>[
          DownloadTask(
            id: 'task-1',
            title: '测试下载',
            url: 'https://example.com/song.mp3',
            status: DownloadTaskStatus.completed,
            progress: 1,
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
            tagWriteStatus: DownloadTagWriteStatus.success,
            lyricFormat: DownloadLyricFormat.timed,
            createdAt: DateTime(2026, 4, 9),
            filePath: '/tmp/测试下载.mp3',
            lyricPath: '/tmp/测试下载.lrc',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .removeTask('task-1');

      expect(repository.deletedTaskIds, <String>['task-1']);
      expect(repository.removedPluginTaskIds, <String>['task-1']);
      expect(repository.deleteDownloadedArtifactsCalls, isEmpty);
      expect(container.read(downloadControllerProvider).tasks, isEmpty);
    },
  );

  test(
    'removeTaskAndFile removes task and deletes downloaded artifacts',
    () async {
      final repository = _FakeDownloadRepository(
        initialTasks: <DownloadTask>[
          DownloadTask(
            id: 'task-1',
            title: '测试下载',
            url: 'https://example.com/song.mp3',
            status: DownloadTaskStatus.completed,
            progress: 1,
            quality: DownloadTaskQuality(
              label: 'standard',
              bitrate: 320,
              fileExtension: 'mp3',
            ),
            tagWriteStatus: DownloadTagWriteStatus.success,
            lyricFormat: DownloadLyricFormat.timed,
            createdAt: DateTime(2026, 4, 9),
            filePath: '/tmp/测试下载.mp3',
            lyricPath: '/tmp/测试下载.lrc',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .removeTaskAndFile('task-1');

      expect(repository.deletedTaskIds, <String>['task-1']);
      expect(repository.removedPluginTaskIds, <String>['task-1']);
      expect(repository.deleteDownloadedArtifactsCalls, hasLength(1));
      expect(repository.deleteDownloadedArtifactsCalls.single, (
        filePath: '/tmp/测试下载.mp3',
        lyricPath: '/tmp/测试下载.lrc',
      ));
      expect(container.read(downloadControllerProvider).tasks, isEmpty);
    },
  );
}

class _FakeDownloadRepository implements DownloadRepository {
  _FakeDownloadRepository({
    List<DownloadTask>? initialTasks,
    this.isAndroid = false,
    this.moveToPublicDownloadsResult,
    this.moveLyricToPublicDownloadsResult,
  }) : savedTasks = List<DownloadTask>.from(
         initialTasks ?? const <DownloadTask>[],
       );

  int resolveSavePathCalls = 0;
  int downloadFileCalls = 0;
  final bool isAndroid;
  final String? moveToPublicDownloadsResult;
  final String? moveLyricToPublicDownloadsResult;
  final List<String> pauseTaskCalls = <String>[];
  final List<String> resumeTaskCalls = <String>[];
  final List<String> openContainingFolderCalls = <String>[];
  final List<({String filePath, String? lyricPath, Rect? sharePositionOrigin})>
  exportFilesCalls =
      <({String filePath, String? lyricPath, Rect? sharePositionOrigin})>[];
  final List<String> removedPluginTaskIds = <String>[];
  final List<String> deletedTaskIds = <String>[];
  final List<DownloadTask> savedTasks;
  final List<({String filePath, String? mimeType})> moveToPublicDownloadsCalls =
      <({String filePath, String? mimeType})>[];
  final List<({String? filePath, String? lyricPath})>
  deleteDownloadedArtifactsCalls = <({String? filePath, String? lyricPath})>[];
  final List<DownloadEnqueueRequest> enqueueTaskRequests =
      <DownloadEnqueueRequest>[];
  final StreamController<DownloadRunnerEvent> _eventsController =
      StreamController<DownloadRunnerEvent>.broadcast();

  void emit(DownloadRunnerEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<bool> enqueueTask(DownloadEnqueueRequest request) async {
    enqueueTaskRequests.add(request);
    return true;
  }

  @override
  Future<void> pauseTask(String pluginTaskId) async {
    pauseTaskCalls.add(pluginTaskId);
  }

  @override
  Future<void> resumeTask(String pluginTaskId) async {
    resumeTaskCalls.add(pluginTaskId);
  }

  @override
  Future<void> removeTask(String pluginTaskId) async {
    removedPluginTaskIds.add(pluginTaskId);
  }

  @override
  Stream<DownloadRunnerEvent> watchEvents() {
    return _eventsController.stream;
  }

  @override
  Future<List<DownloadTask>> restoreTasks() async {
    return List<DownloadTask>.from(savedTasks);
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    savedTasks
      ..removeWhere((item) => item.id == task.id)
      ..add(task);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    deletedTaskIds.add(taskId);
    savedTasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<void> deleteDownloadedArtifacts({
    String? filePath,
    String? lyricPath,
  }) async {
    deleteDownloadedArtifactsCalls.add((
      filePath: filePath,
      lyricPath: lyricPath,
    ));
  }

  @override
  Future<void> openContainingFolder(String filePath) async {
    openContainingFolderCalls.add(filePath);
  }

  @override
  Future<void> exportFiles({
    required String filePath,
    String? lyricPath,
    Rect? sharePositionOrigin,
  }) async {
    exportFilesCalls.add((
      filePath: filePath,
      lyricPath: lyricPath,
      sharePositionOrigin: sharePositionOrigin,
    ));
  }

  @override
  bool get shouldMoveToPublicDownloads => isAndroid;

  @override
  Future<String?> moveToPublicDownloads({
    required String filePath,
    String? mimeType,
  }) async {
    moveToPublicDownloadsCalls.add((filePath: filePath, mimeType: mimeType));
    if (filePath.endsWith('.lrc')) {
      return moveLyricToPublicDownloadsResult;
    }
    return moveToPublicDownloadsResult;
  }

  @override
  Future<String> resolveSavePath({
    required String title,
    required String? artist,
    required String fileExtension,
  }) async {
    resolveSavePathCalls += 1;
    final artistSuffix = (artist ?? '').trim().isEmpty ? '' : ' - ${artist!}';
    return '/tmp/$title$artistSuffix.$fileExtension';
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) async {
    downloadFileCalls += 1;
  }
}

class _FakeDownloadMetadataWriter extends DownloadMetadataWriter {
  _FakeDownloadMetadataWriter({
    this.error,
    this.delay = Duration.zero,
    this.result = const DownloadMetadataWriteResult(
      lyricFormat: DownloadLyricFormat.none,
      artworkEmbedded: false,
      lyricPath: null,
    ),
  }) : super(
         lyricResolver: _FakeDownloadLyricResolver(),
         metadataAdapter: _FakeMetadataAdapter(),
       );

  final Object? error;
  final Duration delay;
  final DownloadMetadataWriteResult result;
  final List<DownloadMetadataRequest> requests = <DownloadMetadataRequest>[];

  @override
  Future<DownloadMetadataWriteResult> write(
    DownloadMetadataRequest request,
  ) async {
    requests.add(request);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

class _FakeOnlineController extends OnlineController {
  _FakeOnlineController({this.resolvedFormat});

  int fetchSongUrlCalls = 0;
  final String? resolvedFormat;

  @override
  OnlineFeatureState build() {
    return OnlineFeatureState.initial;
  }

  @override
  Future<SongUrlResolution> resolveSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    fetchSongUrlCalls += 1;
    final finalFormat = (resolvedFormat ?? format ?? 'mp3')
        .trim()
        .toLowerCase();
    return SongUrlResolution(
      url: 'https://example.com/song.$finalFormat',
      format: finalFormat,
    );
  }
}

class _FakeDownloadLyricResolver extends DownloadLyricResolver {
  _FakeDownloadLyricResolver()
    : super(({required trackId, required platform}) async => null);
}

class _FakeMetadataAdapter implements DownloadMetadataAdapter {
  @override
  Future<void> write({
    required String path,
    required String title,
    required String artist,
    required String album,
    Uint8List? artworkBytes,
    String? lyrics,
  }) async {}
}

Future<void> _waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
  Duration interval = const Duration(milliseconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(interval);
  }
  expect(condition(), isTrue);
}
