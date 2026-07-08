import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_state.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';

void main() {
  group('DownloadTaskQuality', () {
    test('copyWith keeps quality fields coherent', () {
      final quality = DownloadTaskQuality(
        label: '320kbps',
        bitrate: 320,
        fileExtension: 'mp3',
      );

      final updated = quality.copyWith(
        label: 'FLAC',
        bitrate: 999,
        fileExtension: 'flac',
      );

      expect(updated.label, 'FLAC');
      expect(updated.bitrate, 999);
      expect(updated.fileExtension, 'flac');
    });

    test('rejects invalid quality payload', () {
      expect(
        () => DownloadTaskQuality(label: ' ', bitrate: -1, fileExtension: ' '),
        throwsArgumentError,
      );
    });
  });

  group('DownloadTask', () {
    test('queued factory initializes richer metadata defaults', () {
      final createdAt = DateTime(2024, 1, 1);
      final task = DownloadTask.queued(
        id: 'id',
        title: 'title',
        url: 'https://example.com',
        qualityLabel: '320kbps',
        qualityBitrate: 320.0,
        fileExtension: 'mp3',
        lyricFormat: DownloadLyricFormat.timed,
        createdAt: createdAt,
      );

      expect(task.status, DownloadTaskStatus.queued);
      expect(task.progress, 0);
      expect(task.quality.label, '320kbps');
      expect(task.quality.bitrate, 320.0);
      expect(task.quality.fileExtension, 'mp3');
      expect(task.effectiveFileExtension, 'mp3');
      expect(task.tagWriteStatus, DownloadTagWriteStatus.pending);
      expect(task.metadataPath, isNull);
      expect(task.lyricPath, isNull);
      expect(task.errorMessage, isNull);
      expect(task.downloadedBytes, isNull);
      expect(task.totalBytes, isNull);
    });

    test('copyWith applies metadata updates and clears error', () {
      final createdAt = DateTime(2024, 1, 1);
      final queued = DownloadTask.queued(
        id: 'id',
        title: 'title',
        url: 'https://example.com',
        qualityLabel: '320kbps',
        qualityBitrate: 320.0,
        fileExtension: 'mp3',
        lyricFormat: DownloadLyricFormat.timed,
        createdAt: createdAt,
      );

      final startedAt = createdAt.add(const Duration(seconds: 5));
      final finishedAt = startedAt.add(const Duration(seconds: 40));

      final updated = queued.copyWith(
        status: DownloadTaskStatus.tagging,
        progress: 0.75,
        quality: DownloadTaskQuality(
          label: 'lossless',
          bitrate: 999.0,
          fileExtension: 'flac',
        ),
        tagWriteStatus: DownloadTagWriteStatus.success,
        lyricFormat: DownloadLyricFormat.plain,
        downloadedBytes: 1024,
        totalBytes: 2048,
        filePath: '/tmp/song.flac',
        metadataPath: '/tmp/song.json',
        lyricPath: '/tmp/song.lrc',
        startedAt: startedAt,
        finishedAt: finishedAt,
        resolvedFileExtension: 'aac',
        attempts: 2,
        errorMessage: 'will clear',
        clearError: true,
      );

      expect(updated.status, DownloadTaskStatus.tagging);
      expect(updated.progress, 0.75);
      expect(updated.quality.label, 'lossless');
      expect(updated.quality.bitrate, 999.0);
      expect(updated.quality.fileExtension, 'flac');
      expect(updated.tagWriteStatus, DownloadTagWriteStatus.success);
      expect(updated.lyricFormat, DownloadLyricFormat.plain);
      expect(updated.downloadedBytes, 1024);
      expect(updated.totalBytes, 2048);
      expect(updated.filePath, '/tmp/song.flac');
      expect(updated.effectiveFileExtension, 'aac');
      expect(updated.metadataPath, '/tmp/song.json');
      expect(updated.lyricPath, '/tmp/song.lrc');
      expect(updated.startedAt, startedAt);
      expect(updated.finishedAt, finishedAt);
      expect(updated.attempts, 2);
      expect(updated.errorMessage, isNull);
    });

    test('copyWith can clear nullable lifecycle fields', () {
      final task =
          DownloadTask.queued(
            id: 'id',
            title: 'title',
            url: 'https://example.com',
            createdAt: DateTime(2024, 1, 1),
          ).copyWith(
            startedAt: DateTime(2024, 1, 1, 0, 0, 5),
            finishedAt: DateTime(2024, 1, 1, 0, 1),
            metadataPath: '/tmp/meta.json',
            filePath: '/tmp/song.mp3',
            lyricPath: '/tmp/song.lrc',
          );

      final cleared = task.copyWith(
        clearStartedAt: true,
        clearFinishedAt: true,
        clearMetadataPath: true,
        clearFilePath: true,
        clearLyricPath: true,
      );

      expect(cleared.startedAt, isNull);
      expect(cleared.finishedAt, isNull);
      expect(cleared.metadataPath, isNull);
      expect(cleared.filePath, isNull);
      expect(cleared.lyricPath, isNull);
    });

    test('fromJson falls back to quality file extension for old payload', () {
      final task = DownloadTask.fromJson(<String, dynamic>{
        'id': 'id',
        'title': 'title',
        'url': 'https://example.com',
        'status': 'queued',
        'progress': 0,
        'quality': <String, dynamic>{
          'label': '320kbps',
          'bitrate': 320.0,
          'file_extension': 'mp3',
        },
        'tag_write_status': 'pending',
        'lyric_format': 'none',
        'created_at': '2024-01-01T00:00:00.000',
        'attempts': 0,
      });

      expect(task.resolvedFileExtension, 'mp3');
      expect(task.effectiveFileExtension, 'mp3');
    });
  });

  group('DownloadState', () {
    test('initial state caps concurrency and exposes helpers', () {
      expect(DownloadState.initial.tasks, isEmpty);
      expect(DownloadState.initial.maxConcurrent, 3);
      expect(DownloadState.initial.canStartNewTask, isTrue);
      expect(DownloadState.initial.waitingCount, 0);
      expect(DownloadState.initial.isProcessing, isFalse);
    });

    test('derivatives categorize tasks and respect limits', () {
      final base = DownloadTask.queued(
        id: 'base',
        title: 'track',
        url: 'https://example.com',
        qualityLabel: '320kbps',
        qualityBitrate: 320.0,
        fileExtension: 'mp3',
        createdAt: DateTime(2024, 1, 1),
      );

      final queued = base.copyWith(status: DownloadTaskStatus.queued);
      final preparing = queued.copyWith(status: DownloadTaskStatus.preparing);
      final downloading = queued.copyWith(
        status: DownloadTaskStatus.downloading,
        progress: 0.5,
      );
      final completed = queued.copyWith(
        status: DownloadTaskStatus.completed,
        progress: 1,
        filePath: '/tmp/completed.mp3',
      );
      final failed = queued.copyWith(
        status: DownloadTaskStatus.failed,
        errorMessage: 'error',
      );
      final paused = queued.copyWith(status: DownloadTaskStatus.paused);

      final state = DownloadState(
        tasks: [queued, preparing, downloading, completed, failed, paused],
        maxConcurrent: 1,
        isProcessing: true,
      );

      expect(state.waitingTasks, contains(queued));
      expect(state.waitingTasks, isNot(contains(paused)));
      expect(state.waitingTasks, isNot(contains(preparing)));
      expect(state.runningTasks, contains(preparing));
      expect(state.runningTasks, contains(downloading));
      expect(state.completedTasks, contains(completed));
      expect(state.failedTasks, contains(failed));
      expect(state.pausedTasks, contains(paused));
      expect(state.canStartNewTask, isFalse);
      expect(state.waitingCount, 1);
      expect(state.isProcessing, isTrue);
    });
  });
}
