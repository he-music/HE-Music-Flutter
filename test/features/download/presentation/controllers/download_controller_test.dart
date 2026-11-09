import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/providers/local_library_providers.dart';
import 'package:he_music_flutter/features/music_library/domain/repositories/local_music_repository.dart';
import 'package:he_music_flutter/features/download/data/services/download_lyric_resolver.dart';
import 'package:he_music_flutter/features/download/data/services/download_audio_decryptor.dart';
import 'package:he_music_flutter/features/download/data/services/download_metadata_writer.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/download/domain/repositories/download_repository.dart';
import 'package:he_music_flutter/features/download/presentation/providers/download_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  test(
    'encrypted source enqueues CDN ciphertext with backend extension',
    () async {
      final repository = _FakeDownloadRepository();
      final parameters = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'v': 1,
                'kind': 1,
                'key': 'AQ==',
                'user_agent': 'Download-Test-Agent',
              }),
            ),
          )
          .replaceAll('=', '');
      final online = _FakeOnlineController(
        resolvedFormat: 'flac',
        audioParams: parameters,
      );
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(downloadControllerProvider.notifier)
          .enqueue(title: 'Encrypted', songId: 's', platform: 'qq');
      final task = container.read(downloadControllerProvider).tasks.single;
      final request = repository.enqueueTaskRequests.single;
      expect(request.url, 'https://example.com/song.flac');
      expect(request.savePath, task.encryptedFilePath);
      expect(request.savePath, endsWith('.encrypted'));
      expect(task.filePath, endsWith('.flac'));
      expect(task.audioParams, parameters);
      expect(request.headers, {'User-Agent': 'Download-Test-Agent'});
      expect(task.status, DownloadTaskStatus.preparing);
    },
  );

  test(
    'restored download uses the real worker before publishing clear audio',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_real_decrypt_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ciphertext = await File(
        '${directory.path}/source.encrypted',
      ).writeAsBytes([9, 8, 7]);
      final parameters = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'v': 1,
                'kind': 1,
                'key': base64.encode([1]),
              }),
            ),
          )
          .replaceAll('=', '');
      final task =
          DownloadTask.queued(
            id: 'real-worker',
            title: 'Song',
            url: 'https://cdn.example/audio',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypting,
            audioParams: parameters,
            encryptedFilePath: ciphertext.path,
            decryptedFilePath: '${directory.path}/clear.mp3',
            filePath: '${directory.path}/Song.mp3',
          );
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadControllerProvider);
      await _waitForCondition(
        () => [
          DownloadTaskStatus.completed,
          DownloadTaskStatus.failed,
        ].contains(repository.savedTasks.single.status),
        timeout: const Duration(seconds: 10),
      );
      expect(
        repository.savedTasks.single.status,
        DownloadTaskStatus.completed,
        reason: repository.savedTasks.single.errorMessage,
      );
      await _waitForCondition(
        () => repository.deleteDownloadedArtifactsCalls.any(
          (call) => call.filePath == ciphertext.path,
        ),
      );
      expect(await File(task.filePath!).readAsBytes(), [8, 7, 6]);
      expect(
        repository.savedTasks.single.processingStage,
        DownloadProcessingStage.transfer,
      );
      expect(repository.savedTasks.single.audioParams, isNull);
      expect(repository.enqueueTaskRequests, isEmpty);
    },
  );
  test(
    'deletion waits for publication and removes the returned public path',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_delete_publish_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final clear = await File('${directory.path}/clear.mp3').writeAsBytes([1]);
      final task =
          DownloadTask.queued(
            id: 'delete-publish',
            title: 'Song',
            url: 'https://cdn.example/audio',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypted,
            audioParams: 'secret',
            encryptedFilePath: '${directory.path}/cipher',
            decryptedFilePath: clear.path,
            filePath: '${directory.path}/Song.mp3',
          );
      final started = Completer<void>();
      final finish = Completer<void>();
      final repository =
          _FakeDownloadRepository(
              initialTasks: [task],
              isAndroid: true,
              moveToPublicDownloadsResult: '/public/Song.mp3',
            )
            ..onMoveToPublicDownloads = () async {
              started.complete();
              await finish.future;
            };
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await started.future;
      final removal = controller.removeTaskAndFile(task.id);
      await Future<void>.delayed(Duration.zero);
      expect(repository.deletedTaskIds, isEmpty);
      finish.complete();
      await removal;
      expect(
        repository.deleteDownloadedArtifactsCalls.any(
          (call) => call.filePath == '/public/Song.mp3',
        ),
        isTrue,
      );
      expect(
        repository.deleteDownloadedArtifactsCalls.any(
          (call) => call.filePath == task.filePath,
        ),
        isTrue,
      );
      expect(container.read(downloadControllerProvider).tasks, isEmpty);
    },
  );
  test('empty decrypted output fails before tags or publication', () async {
    final directory = await Directory.systemTemp.createTemp(
      'download_empty_clear_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final clear = await File('${directory.path}/clear.mp3').writeAsBytes([]);
    final task =
        DownloadTask.queued(
          id: 'empty-clear',
          title: 'Song',
          url: 'https://cdn.example/audio',
        ).copyWith(
          status: DownloadTaskStatus.tagging,
          processingStage: DownloadProcessingStage.decrypted,
          audioParams: 'secret',
          encryptedFilePath: '${directory.path}/cipher',
          decryptedFilePath: clear.path,
          filePath: '${directory.path}/Song.mp3',
        );
    final repository = _FakeDownloadRepository(
      initialTasks: [task],
      isAndroid: true,
    );
    final container = ProviderContainer(
      overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(downloadControllerProvider);
    await _waitForCondition(
      () => repository.savedTasks.single.status == DownloadTaskStatus.failed,
    );
    expect(repository.moveToPublicDownloadsCalls, isEmpty);
    expect(await File(task.filePath!).exists(), isFalse);
  });
  for (final stage in [
    DownloadProcessingStage.decrypting,
    DownloadProcessingStage.decrypted,
  ]) {
    test(
      'restored $stage completes locally without downloading or double decrypt',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'download_decrypt_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final encrypted = await File(
          '${directory.path}/cipher',
        ).writeAsBytes([9, 8]);
        final clear = File('${directory.path}/clear.flac');
        if (stage == DownloadProcessingStage.decrypted) {
          await clear.writeAsBytes([1, 2]);
        }
        final task =
            DownloadTask.queued(
              id: 'recover',
              title: 'Song',
              url: 'https://cdn.test/a',
            ).copyWith(
              status: DownloadTaskStatus.tagging,
              processingStage: stage,
              audioParams: 'secret',
              encryptedFilePath: encrypted.path,
              decryptedFilePath: clear.path,
              filePath: '${directory.path}/Song.flac',
              resolvedFileExtension: 'flac',
            );
        final repository = _FakeDownloadRepository(initialTasks: [task]);
        var decryptions = 0;
        final container = ProviderContainer(
          overrides: [
            downloadRepositoryProvider.overrideWithValue(repository),
            localMusicRepositoryProvider.overrideWithValue(
              _RecordingLocalMusicRepository(),
            ),
            downloadAudioDecryptorProvider.overrideWithValue(({
              required input,
              required output,
              required encodedParameters,
            }) async {
              decryptions++;
              expect(encodedParameters, 'secret');
              expect(await input.readAsBytes(), [9, 8]);
              await output.writeAsBytes([1, 2]);
            }),
          ],
        );
        addTearDown(container.dispose);
        container.read(downloadControllerProvider);
        await _waitForCondition(
          () =>
              repository.savedTasks.single.status ==
              DownloadTaskStatus.completed,
        );
        expect(
          decryptions,
          stage == DownloadProcessingStage.decrypting ? 1 : 0,
        );
        expect(repository.enqueueTaskRequests, isEmpty);
        expect(await File(task.filePath!).readAsBytes(), [1, 2]);
        expect(repository.savedTasks.single.audioParams, isNull);
      },
    );
  }

  test(
    'decrypt failure retains ciphertext and retry never tags ciphertext',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_decrypt_retry_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final encrypted = await File(
        '${directory.path}/cipher',
      ).writeAsBytes([9]);
      final task =
          DownloadTask.queued(
            id: 'retry',
            title: 'Song',
            url: 'https://cdn.test/a',
            songId: 's',
            platform: 'qq',
            artist: 'Artist',
            album: 'Album',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypting,
            audioParams: 'secret',
            encryptedFilePath: encrypted.path,
            decryptedFilePath: '${directory.path}/clear.mp3',
            filePath: '${directory.path}/Song.mp3',
          );
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final writer = _FakeDownloadMetadataWriter();
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadMetadataWriterProvider.overrideWithValue(writer),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            if (++attempts == 1) throw StateError('secret');
            await output.writeAsBytes([1]);
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await _waitForCondition(
        () => repository.savedTasks.single.status == DownloadTaskStatus.failed,
      );
      expect(writer.requests, isEmpty);
      expect(await encrypted.readAsBytes(), [9]);
      expect(await File(task.filePath!).exists(), isFalse);
      expect(
        repository.savedTasks.single.errorMessage,
        isNot(contains('secret')),
      );
      await controller.retry(task.id);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(attempts, 2);
      expect(writer.requests.single.filePath, task.decryptedFilePath);
      expect(repository.enqueueTaskRequests, isEmpty);
    },
  );

  test(
    'pause during decrypt keeps a reusable clear stage and defers publication',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_decrypt_pause_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final encrypted = await File(
        '${directory.path}/cipher',
      ).writeAsBytes([9]);
      final task =
          DownloadTask.queued(
            id: 'pause',
            title: 'Song',
            url: 'https://cdn.test/a',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypting,
            audioParams: 'secret',
            encryptedFilePath: encrypted.path,
            decryptedFilePath: '${directory.path}/clear.mp3',
            filePath: '${directory.path}/Song.mp3',
          );
      final gate = Completer<void>();
      var started = false;
      var attempts = 0;
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            attempts++;
            started = true;
            await gate.future;
            await output.writeAsBytes([1]);
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await _waitForCondition(() => started);
      await controller.pause(task.id);
      gate.complete();
      await _waitForCondition(
        () =>
            repository.savedTasks.single.processingStage ==
            DownloadProcessingStage.decrypted,
      );
      expect(repository.savedTasks.single.status, DownloadTaskStatus.paused);
      expect(await File(task.filePath!).exists(), isFalse);
      await controller.resume(task.id);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(attempts, 1);
    },
  );

  test(
    'native completion waits for clear audio before tags and final publication',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_complete_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final encrypted = await File(
        '${directory.path}/cipher',
      ).writeAsBytes([9]);
      final clear = File('${directory.path}/clear.flac');
      final task =
          DownloadTask.queued(
            id: 'native',
            title: 'Song',
            url: 'https://cdn.test/a',
            songId: 's',
            platform: 'qq',
            artist: 'Artist',
            album: 'Album',
          ).copyWith(
            status: DownloadTaskStatus.downloading,
            audioParams: 'secret',
            encryptedFilePath: encrypted.path,
            decryptedFilePath: clear.path,
            filePath: '${directory.path}/Song.flac',
            resolvedFileExtension: 'flac',
          );
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final gate = Completer<void>();
      var decryptions = 0;
      final writer = _FakeDownloadMetadataWriter();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadMetadataWriterProvider.overrideWithValue(writer),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            decryptions++;
            await gate.future;
            await output.writeAsBytes([1]);
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: task.id,
          status: DownloadRunnerStatus.complete,
          filePath: encrypted.path,
        ),
      );
      await _waitForCondition(() => decryptions == 1);
      expect(
        repository.savedTasks.single.processingStage,
        DownloadProcessingStage.decrypting,
      );
      expect(writer.requests, isEmpty);
      expect(await File(task.filePath!).exists(), isFalse);
      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: task.id,
          status: DownloadRunnerStatus.complete,
          filePath: encrypted.path,
        ),
      );
      gate.complete();
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(decryptions, 1);
      expect(writer.requests.single.filePath, clear.path);
      expect(await File(task.filePath!).readAsBytes(), [1]);
    },
  );

  test(
    'existing atomic clear output recovers before decrypt journal save',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_atomic_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final clear = await File(
        '${directory.path}/clear.flac',
      ).writeAsBytes([1]);
      final task =
          DownloadTask.queued(
            id: 'atomic',
            title: 'Song',
            url: 'https://cdn.test/a',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypting,
            audioParams: 'secret',
            encryptedFilePath: '${directory.path}/cipher',
            decryptedFilePath: clear.path,
            filePath: '${directory.path}/Song.flac',
          );
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            fail('published clear output must not be decrypted again');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadControllerProvider);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(await File(task.filePath!).readAsBytes(), [1]);
    },
  );

  test(
    'public move failure retries from clear journal with final filename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_publish_retry_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final clear = await File(
        '${directory.path}/clear.flac',
      ).writeAsBytes([1]);
      final task =
          DownloadTask.queued(
            id: 'publish',
            title: 'Song',
            url: 'https://cdn.test/a',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypted,
            audioParams: 'secret',
            encryptedFilePath: '${directory.path}/cipher',
            decryptedFilePath: clear.path,
            filePath: '${directory.path}/Song.flac',
          );
      final repository = _FakeDownloadRepository(
        initialTasks: [task],
        isAndroid: true,
      );
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            fail('publication retry must not decrypt clear audio');
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await _waitForCondition(
        () => repository.savedTasks.single.status == DownloadTaskStatus.failed,
      );
      expect(
        repository.savedTasks.single.processingStage,
        DownloadProcessingStage.publishing,
      );
      expect(await File(task.filePath!).readAsBytes(), [1]);
      expect(
        repository.moveToPublicDownloadsCalls.single.filePath,
        endsWith('/Song.flac'),
      );
      repository.moveToPublicDownloadsResult = '/public/Song.flac';
      await controller.retry(task.id);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(repository.savedTasks.single.filePath, '/public/Song.flac');
      expect(repository.enqueueTaskRequests, isEmpty);
    },
  );

  test(
    'disposed controller leaves a journal that recovers completed decryption',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_restart_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final encrypted = await File(
        '${directory.path}/cipher',
      ).writeAsBytes([9]);
      final clear = File('${directory.path}/clear.flac');
      final task =
          DownloadTask.queued(
            id: 'restart',
            title: 'Song',
            url: 'https://cdn.test/a',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.decrypting,
            audioParams: 'secret',
            encryptedFilePath: encrypted.path,
            decryptedFilePath: clear.path,
            filePath: '${directory.path}/Song.flac',
          );
      final repository = _FakeDownloadRepository(initialTasks: [task]);
      final gate = Completer<void>();
      var started = false;
      final oldContainer = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            started = true;
            await gate.future;
            await output.writeAsBytes([1]);
          }),
        ],
      );
      oldContainer.read(downloadControllerProvider);
      await _waitForCondition(() => started);
      oldContainer.dispose();
      gate.complete();
      await _waitForCondition(() => clear.existsSync());
      final restored = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            fail('restart must reuse atomic clear output');
          }),
        ],
      );
      addTearDown(restored.dispose);
      restored.read(downloadControllerProvider);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(await File(task.filePath!).readAsBytes(), [1]);
      expect(repository.enqueueTaskRequests, isEmpty);
    },
  );

  test(
    'published audio resumes lyric publication without moving audio again',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download_resume_lyrics_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final lyric = await File(
        '${directory.path}/Song.lrc',
      ).writeAsString('[00:01]line');
      final task =
          DownloadTask.queued(
            id: 'lyrics',
            title: 'Song',
            url: 'https://cdn.test/a',
          ).copyWith(
            status: DownloadTaskStatus.tagging,
            processingStage: DownloadProcessingStage.published,
            audioParams: 'secret',
            encryptedFilePath: '${directory.path}/cipher',
            decryptedFilePath: '${directory.path}/.publish-lyrics/Song.flac',
            publicationSourcePath: '${directory.path}/Song.flac',
            filePath: '/public/Song.flac',
            lyricPath: lyric.path,
            tagWriteStatus: DownloadTagWriteStatus.success,
            lyricFormat: DownloadLyricFormat.timed,
          );
      final repository = _FakeDownloadRepository(
        initialTasks: [task],
        isAndroid: true,
        moveLyricToPublicDownloadsResult: '/public/Song.lrc',
      );
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(
            _RecordingLocalMusicRepository(),
          ),
          downloadAudioDecryptorProvider.overrideWithValue(({
            required input,
            required output,
            required encodedParameters,
          }) async {
            fail('published audio cannot be decrypted again');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadControllerProvider);
      await _waitForCondition(
        () =>
            repository.savedTasks.single.status == DownloadTaskStatus.completed,
      );
      expect(
        repository.moveToPublicDownloadsCalls.single.filePath,
        endsWith('/Song.lrc'),
      );
      expect(repository.savedTasks.single.filePath, '/public/Song.flac');
      expect(repository.savedTasks.single.lyricPath, '/public/Song.lrc');
    },
  );
  for (final writeTags in [false, true]) {
    test(
      'completed download imports its final path after tagging=$writeTags',
      () async {
        final repository = _FakeDownloadRepository(
          isAndroid: true,
          moveToPublicDownloadsResult: '/final/song.mp3',
        );
        final library = _RecordingLocalMusicRepository();
        final gate = Completer<void>();
        final writer = _FakeDownloadMetadataWriter()..gate = gate;
        final container = ProviderContainer(
          overrides: [
            downloadRepositoryProvider.overrideWithValue(repository),
            downloadMetadataWriterProvider.overrideWithValue(writer),
            localMusicRepositoryProvider.overrideWithValue(library),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(downloadControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        await controller.enqueue(
          title: 'Song',
          url: 'https://example.com/song.mp3',
          songId: writeTags ? 'song' : null,
          platform: writeTags ? 'qq' : null,
          artist: writeTags ? 'Artist' : null,
          album: writeTags ? 'Album' : null,
        );
        repository.emit(
          DownloadRunnerEvent(
            pluginTaskId: repository.enqueueTaskRequests.single.pluginTaskId,
            status: DownloadRunnerStatus.complete,
            filePath: '/temporary/song.mp3',
          ),
        );
        if (writeTags) {
          await _waitForCondition(() => writer.requests.isNotEmpty);
          expect(library.paths, isEmpty);
          expect(repository.moveToPublicDownloadsCalls, isEmpty);
          expect(
            container.read(downloadControllerProvider).tasks.single.status,
            DownloadTaskStatus.tagging,
          );
        }
        gate.complete();
        await _waitForCondition(() => library.paths.isNotEmpty);
        expect(library.paths, ['/final/song.mp3']);
        expect(repository.savedTasks.single.filePath, '/final/song.mp3');
        expect(
          repository.savedTasks.single.status,
          DownloadTaskStatus.completed,
        );
        expect(writer.requests, hasLength(writeTags ? 1 : 0));
      },
      skip: !Platform.isMacOS && !Platform.isIOS,
    );
  }

  test(
    'local indexing failure leaves a completed download available',
    () async {
      final repository = _FakeDownloadRepository();
      final library = _RecordingLocalMusicRepository(
        error: StateError('index failed'),
      );
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(library),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.enqueue(
        title: 'Song',
        url: 'https://example.com/song.mp3',
      );
      repository.emit(
        DownloadRunnerEvent(
          pluginTaskId: repository.enqueueTaskRequests.single.pluginTaskId,
          status: DownloadRunnerStatus.complete,
          filePath: '/final/song.mp3',
        ),
      );
      await _waitForCondition(() => library.paths.isNotEmpty);
      final task = container.read(downloadControllerProvider).tasks.single;
      expect(task.status, DownloadTaskStatus.completed);
      expect(task.filePath, '/final/song.mp3');
      expect(task.errorMessage, isNull);
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );

  for (final audioDeleted in [false, true]) {
    test(
      'failed file cleanup retains the task and reconciles audioDeleted=$audioDeleted',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'download_delete_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final audio = await File(
          '${directory.path}/song.mp3',
        ).writeAsBytes([1]);
        final task = DownloadTask.queued(
          id: 'delete-task',
          title: 'Song',
          url: 'https://example.com/song.mp3',
        ).copyWith(status: DownloadTaskStatus.completed, filePath: audio.path);
        final repository = _FakeDownloadRepository(initialTasks: [task]);
        repository.onDeleteArtifacts = () async {
          expect(repository.savedTasks.single.id, task.id);
          if (audioDeleted) await audio.delete();
          throw const FileSystemException('cleanup failed');
        };
        final library = _RecordingLocalMusicRepository();
        final container = ProviderContainer(
          overrides: [
            downloadRepositoryProvider.overrideWithValue(repository),
            localMusicRepositoryProvider.overrideWithValue(library),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(downloadControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          controller.removeTaskAndFile(task.id),
          throwsA(isA<FileSystemException>()),
        );
        expect(library.missingPaths, [audio.path]);
        expect(await audio.exists(), !audioDeleted);
        expect(repository.deletedTaskIds, isEmpty);
        expect(repository.savedTasks.single.id, task.id);
        expect(
          container.read(downloadControllerProvider).tasks.single.id,
          task.id,
        );
      },
      skip: !Platform.isIOS && !Platform.isMacOS,
    );
  }

  test(
    'clear completed tasks removes persisted transfers and keeps other tasks',
    () async {
      final completed =
          DownloadTask.queued(
            id: 'completed',
            title: 'Downloaded',
            url: 'https://example.com/song.mp3',
          ).copyWith(
            status: DownloadTaskStatus.completed,
            filePath: '/tmp/saved.mp3',
          );
      final paused = DownloadTask.queued(
        id: 'paused',
        title: 'Paused',
        url: 'https://example.com/song.mp3',
      ).copyWith(status: DownloadTaskStatus.paused);
      final repository = _FakeDownloadRepository(
        initialTasks: [completed, paused],
      );
      final container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(downloadControllerProvider.notifier)
          .clearCompleted();
      expect(
        container.read(downloadControllerProvider).tasks.single.id,
        'paused',
      );
      expect(repository.savedTasks.single.id, 'paused');
      expect(repository.deleteDownloadedArtifactsCalls, isEmpty);
    },
  );

  test(
    'redownload saved song recreates a cleared task with the same identity',
    () async {
      final saved =
          DownloadTask.queued(
            id: 'saved-task',
            title: 'Song',
            url: 'https://example.com/expired.mp3',
            songId: 'song-1',
            platform: 'qq',
          ).copyWith(
            status: DownloadTaskStatus.completed,
            filePath: '/tmp/deleted.mp3',
          );
      final repository = _FakeDownloadRepository();
      final online = _FakeOnlineController();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          onlineControllerProvider.overrideWith(() => online),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(downloadControllerProvider.notifier)
          .redownloadSavedSong(saved);
      final task = container.read(downloadControllerProvider).tasks.single;
      expect(task.id, saved.id);
      expect(task.songId, saved.songId);
      expect(task.platform, saved.platform);
      expect(online.fetchSongUrlCalls, 1);
      expect(repository.enqueueTaskRequests.single.taskId, saved.id);
    },
  );

  test(
    'two queued songs with matching filenames receive distinct output paths',
    () async {
      final repository = _FakeDownloadRepository();
      final container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(downloadControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.enqueue(
        title: 'Same name',
        url: 'https://example.com/a.mp3',
      );
      await controller.enqueue(
        title: 'Same name',
        url: 'https://example.com/b.mp3',
      );
      expect(repository.enqueueTaskRequests, hasLength(2));
      expect(
        repository.enqueueTaskRequests
            .map((request) => request.savePath)
            .toSet(),
        hasLength(2),
      );
    },
  );

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
    final library = _RecordingLocalMusicRepository();
    final metadataWriter = _FakeDownloadMetadataWriter(
      error: StateError('tagging failed'),
    );
    final online = _FakeOnlineController();
    final container = ProviderContainer(
      overrides: [
        localMusicRepositoryProvider.overrideWithValue(library),
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
    expect(library.paths, isEmpty);
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
      final library = _RecordingLocalMusicRepository();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(library),
        ],
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
      expect(library.missingPaths, isEmpty);
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
      final library = _RecordingLocalMusicRepository();
      final container = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          localMusicRepositoryProvider.overrideWithValue(library),
        ],
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
      expect(
        library.missingPaths,
        (Platform.isIOS || Platform.isMacOS) ? ['/tmp/测试下载.mp3'] : isEmpty,
      );
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

  Future<void> Function()? onDeleteArtifacts;
  Future<void> Function()? onMoveToPublicDownloads;
  int resolveSavePathCalls = 0;
  int downloadFileCalls = 0;
  final bool isAndroid;
  String? moveToPublicDownloadsResult;
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
    await onDeleteArtifacts?.call();
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
    await onMoveToPublicDownloads?.call();
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

  Completer<void>? gate;
  final Object? error;
  final Duration delay;
  final DownloadMetadataWriteResult result;
  final List<DownloadMetadataRequest> requests = <DownloadMetadataRequest>[];

  @override
  Future<DownloadMetadataWriteResult> write(
    DownloadMetadataRequest request,
  ) async {
    requests.add(request);
    await gate?.future;
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
  _FakeOnlineController({this.resolvedFormat, this.audioParams});

  int fetchSongUrlCalls = 0;
  final String? resolvedFormat;
  final String? audioParams;

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
      audioParams: audioParams,
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

class _RecordingLocalMusicRepository implements LocalMusicRepository {
  _RecordingLocalMusicRepository({this.error});
  final Object? error;
  final paths = <String>[];
  final missingPaths = <String>[];

  @override
  Future<void> markFileMissingByPath(String filePath) async {
    missingPaths.add(filePath);
  }

  @override
  Future<void> importSong(String filePath) async {
    paths.add(filePath);
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
