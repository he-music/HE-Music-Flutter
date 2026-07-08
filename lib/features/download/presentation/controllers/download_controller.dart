import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../data/services/download_metadata_writer.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_repository.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../providers/download_providers.dart';

class _ResolvedDownloadSource {
  const _ResolvedDownloadSource({
    required this.url,
    required this.fileExtension,
  });

  final String url;
  final String fileExtension;
}

class DownloadController extends Notifier<DownloadState> {
  StreamSubscription<DownloadRunnerEvent>? _eventsSubscription;
  bool _disposed = false;

  @override
  DownloadState build() {
    _bindRunnerEvents();
    unawaited(_restoreTasks());
    ref.onDispose(() {
      _disposed = true;
      unawaited(_eventsSubscription?.cancel());
    });
    return DownloadState.initial;
  }

  Future<void> enqueue({
    required String title,
    String url = '',
    DownloadTaskQuality? quality,
    String? songId,
    String? platform,
    String? artist,
    String? album,
    String? artworkUrl,
  }) async {
    final resolvedQuality =
        quality ??
        DownloadTaskQuality(
          label: 'standard',
          bitrate: 320,
          fileExtension: 'mp3',
        );
    final savePath = await ref
        .read(downloadRepositoryProvider)
        .resolveSavePath(
          title: title,
          artist: artist,
          fileExtension: resolvedQuality.fileExtension,
        );
    if (url.trim().isNotEmpty) {
      _validateUrl(url);
    }
    final task = DownloadTask.queued(
      id: _taskId(),
      title: title,
      url: url,
      quality: resolvedQuality,
      songId: songId,
      platform: platform,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
    );
    final persisted = task.copyWith(filePath: savePath);
    state = state.copyWith(tasks: <DownloadTask>[...state.tasks, persisted]);
    await _persistTask(persisted);
    await _dispatchQueuedTasks();
  }

  Future<void> retry(String taskId) async {
    await _updateTask(
      taskId,
      (task) => task.copyWith(
        status: DownloadTaskStatus.queued,
        progress: 0,
        clearError: true,
      ),
    );
    await _dispatchQueuedTasks();
  }

  Future<void> pause(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    await ref.read(downloadRepositoryProvider).pauseTask(task.id);
    await _updateTask(
      task.id,
      (old) => old.copyWith(status: DownloadTaskStatus.paused),
    );
    await _dispatchQueuedTasks();
  }

  Future<void> resume(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    await ref.read(downloadRepositoryProvider).resumeTask(task.id);
    await _updateTask(
      task.id,
      (old) =>
          old.copyWith(status: DownloadTaskStatus.preparing, clearError: true),
    );
  }

  Future<void> redownload(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    final shouldRefreshUrl =
        (task.songId ?? '').trim().isNotEmpty &&
        (task.platform ?? '').trim().isNotEmpty;
    await _updateTask(
      task.id,
      (old) => old.copyWith(
        status: DownloadTaskStatus.queued,
        progress: 0,
        url: shouldRefreshUrl ? '' : old.url,
        tagWriteStatus: DownloadTagWriteStatus.pending,
        lyricFormat: DownloadLyricFormat.none,
        clearError: true,
      ),
    );
    await _dispatchQueuedTasks();
  }

  Future<void> openContainingFolder(String taskId) async {
    final task = _findTask(taskId);
    final filePath = task?.filePath?.trim() ?? '';
    if (filePath.isEmpty) {
      return;
    }
    await ref.read(downloadRepositoryProvider).openContainingFolder(filePath);
  }

  Future<void> exportFiles(String taskId, {Rect? sharePositionOrigin}) async {
    final task = _findTask(taskId);
    final filePath = task?.filePath?.trim() ?? '';
    if (filePath.isEmpty) {
      return;
    }
    await ref
        .read(downloadRepositoryProvider)
        .exportFiles(
          filePath: filePath,
          lyricPath: task?.lyricPath?.trim(),
          sharePositionOrigin: sharePositionOrigin,
        );
  }

  Future<void> removeTask(String taskId) async {
    await _removeTask(taskId);
  }

  Future<void> removeTaskAndFile(String taskId) async {
    await _removeTask(taskId, deleteFiles: true);
  }

  void clearCompleted() {
    final updated = state.tasks
        .where((task) => task.status != DownloadTaskStatus.completed)
        .toList(growable: false);
    state = _withProcessing(updated);
  }

  Future<void> _restoreTasks() async {
    final restoredTasks = await ref
        .read(downloadRepositoryProvider)
        .restoreTasks();
    if (_disposed) {
      return;
    }
    final mergedTasks = <DownloadTask>[
      ...state.tasks,
      for (final restored in restoredTasks)
        if (!state.tasks.any((task) => task.id == restored.id)) restored,
    ];
    state = _withProcessing(mergedTasks);
    await _dispatchQueuedTasks();
  }

  Future<void> _removeTask(String taskId, {bool deleteFiles = false}) async {
    final repository = ref.read(downloadRepositoryProvider);
    final target = _findTask(taskId);
    await repository.deleteTask(taskId);
    if (target != null) {
      await repository.removeTask(target.id);
      if (deleteFiles) {
        await repository.deleteDownloadedArtifacts(
          filePath: target.filePath,
          lyricPath: target.lyricPath,
        );
      }
    }
    final updated = state.tasks
        .where((task) => task.id != taskId)
        .toList(growable: false);
    state = _withProcessing(updated);
  }

  Future<void> _dispatchQueuedTasks() async {
    if (_disposed) {
      return;
    }
    final runningCount = state.runningTasks.length;
    final capacity = state.maxConcurrent - runningCount;
    if (capacity <= 0) {
      return;
    }
    final queued = state.waitingTasks.take(capacity).toList(growable: false);
    for (final task in queued) {
      await _startTask(task);
    }
  }

  Future<void> _startTask(DownloadTask task) async {
    if (_disposed) {
      return;
    }
    final current = _findTask(task.id);
    if (current == null || current.status != DownloadTaskStatus.queued) {
      return;
    }
    await _updateTask(
      task.id,
      (old) => old.copyWith(
        status: DownloadTaskStatus.preparing,
        progress: 0,
        clearError: true,
      ),
    );
    final repository = ref.read(downloadRepositoryProvider);
    final currentTask = _findTask(task.id);
    if (currentTask == null) {
      return;
    }
    final resolvedSource = await _resolveDownloadSource(currentTask);
    final savePath = await repository.resolveSavePath(
      title: currentTask.title,
      artist: currentTask.artist,
      fileExtension: resolvedSource.fileExtension,
    );
    final request = DownloadEnqueueRequest(
      taskId: task.id,
      pluginTaskId: task.id,
      url: resolvedSource.url,
      savePath: savePath,
    );
    final enqueued = await repository.enqueueTask(request);
    if (!enqueued) {
      await _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.failed,
          errorMessage: 'Failed to enqueue download task.',
        ),
      );
      return;
    }
    await _updateTask(
      task.id,
      (old) => old.copyWith(
        status: DownloadTaskStatus.preparing,
        progress: 0,
        filePath: savePath,
        resolvedFileExtension: resolvedSource.fileExtension,
        url: resolvedSource.url,
        clearError: true,
      ),
    );
  }

  Future<_ResolvedDownloadSource> _resolveDownloadSource(
    DownloadTask task,
  ) async {
    final directUrl = task.url.trim();
    if (directUrl.isNotEmpty) {
      _validateUrl(directUrl);
      return _ResolvedDownloadSource(
        url: directUrl,
        fileExtension: task.effectiveFileExtension,
      );
    }
    final songId = (task.songId ?? '').trim();
    final platform = (task.platform ?? '').trim();
    if (songId.isEmpty || platform.isEmpty) {
      throw const AppException(
        ValidationFailure('Download task missing song source metadata.'),
      );
    }
    final resolution = await ref
        .read(onlineControllerProvider.notifier)
        .resolveSongUrl(
          songId: songId,
          platform: platform,
          quality: task.quality.bitrate > 0
              ? task.quality.bitrate.round()
              : null,
          format: task.quality.fileExtension,
        );
    return _ResolvedDownloadSource(
      url: resolution.url,
      fileExtension: resolution.format.trim().toLowerCase(),
    );
  }

  void _bindRunnerEvents() {
    _eventsSubscription?.cancel();
    _eventsSubscription = ref
        .read(downloadRepositoryProvider)
        .watchEvents()
        .listen((event) {
          unawaited(_handleRunnerEvent(event));
        });
  }

  Future<void> _handleRunnerEvent(DownloadRunnerEvent event) async {
    if (_disposed) {
      return;
    }
    final task = _findTask(event.pluginTaskId);
    if (task == null) {
      return;
    }
    switch (event.status) {
      case DownloadRunnerStatus.enqueued:
        await _updateTask(
          task.id,
          (old) => old.copyWith(
            status: DownloadTaskStatus.preparing,
            progress: 0,
            downloadedBytes: 0,
          ),
        );
      case DownloadRunnerStatus.running:
        await _updateTask(task.id, (old) {
          final nextTotalBytes = _resolveTotalBytes(
            previous: old.totalBytes,
            incoming: event.expectedFileSize,
          );
          return old.copyWith(
            status: DownloadTaskStatus.downloading,
            progress: event.progress ?? old.progress,
            downloadedBytes: _resolveDownloadedBytes(
              progress: event.progress ?? old.progress,
              totalBytes: nextTotalBytes,
              previous: old.downloadedBytes,
            ),
            totalBytes: nextTotalBytes,
            filePath: event.filePath ?? old.filePath,
            clearError: true,
          );
        });
      case DownloadRunnerStatus.complete:
        await _completeTask(task: task, eventFilePath: event.filePath);
        await _dispatchQueuedTasks();
      case DownloadRunnerStatus.paused:
        await _updateTask(
          task.id,
          (old) => old.copyWith(status: DownloadTaskStatus.paused),
        );
        await _dispatchQueuedTasks();
      case DownloadRunnerStatus.failed:
      case DownloadRunnerStatus.canceled:
      case DownloadRunnerStatus.notFound:
        await _updateTask(
          task.id,
          (old) => old.copyWith(
            status: DownloadTaskStatus.failed,
            errorMessage: event.errorMessage ?? 'Download failed.',
          ),
        );
        await _dispatchQueuedTasks();
      case DownloadRunnerStatus.waitingToRetry:
        await _updateTask(
          task.id,
          (old) => old.copyWith(status: DownloadTaskStatus.queued),
        );
        await _dispatchQueuedTasks();
    }
  }

  DownloadTask? _findTask(String pluginTaskId) {
    for (final task in state.tasks) {
      if (task.id == pluginTaskId) {
        return task;
      }
    }
    return null;
  }

  Future<void> _updateTask(
    String taskId,
    DownloadTask Function(DownloadTask task) updater,
  ) async {
    if (_disposed) {
      return;
    }
    final updated = state.tasks
        .map((task) {
          if (task.id != taskId) {
            return task;
          }
          return updater(task);
        })
        .toList(growable: false);
    state = _withProcessing(updated);
    final next = _findTask(taskId);
    if (next != null) {
      await _persistTask(next);
    }
  }

  Future<void> _persistTask(DownloadTask task) {
    if (_disposed) {
      return Future<void>.value();
    }
    return ref.read(downloadRepositoryProvider).saveTask(task);
  }

  bool _canWriteMetadata(DownloadTask task) {
    return (task.songId ?? '').trim().isNotEmpty &&
        (task.platform ?? '').trim().isNotEmpty &&
        (task.artist ?? '').trim().isNotEmpty &&
        (task.album ?? '').trim().isNotEmpty;
  }

  Future<void> _writeMetadata({
    required String taskId,
    required String filePath,
  }) async {
    if (_disposed) {
      return;
    }
    final current = _findTask(taskId);
    if (current == null) {
      return;
    }
    try {
      final result = await ref
          .read(downloadMetadataWriterProvider)
          .write(
            DownloadMetadataRequest(
              filePath: filePath,
              songId: current.songId ?? '',
              platform: current.platform ?? '',
              title: current.title,
              artist: current.artist ?? '',
              album: current.album ?? '',
              artworkUrl: current.artworkUrl,
            ),
          );
      if (_disposed) {
        return;
      }
      final finalizedPaths = await _finalizeDownloadedArtifacts(
        filePath: filePath,
        lyricPath: result.lyricPath,
      );
      if (_disposed) {
        return;
      }
      await _updateTask(
        taskId,
        (old) => old.copyWith(
          status: DownloadTaskStatus.completed,
          tagWriteStatus: DownloadTagWriteStatus.success,
          lyricFormat: result.lyricFormat,
          filePath: finalizedPaths.filePath,
          lyricPath: finalizedPaths.lyricPath,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'DownloadController._writeMetadata failed '
        'taskId=$taskId filePath=$filePath error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      await _updateTask(
        taskId,
        (old) => old.copyWith(
          status: DownloadTaskStatus.failed,
          tagWriteStatus: DownloadTagWriteStatus.failed,
          errorMessage: '$error',
          filePath: filePath,
        ),
      );
    }
  }

  Future<void> _completeTask({
    required DownloadTask task,
    required String? eventFilePath,
  }) async {
    final filePath = eventFilePath ?? task.filePath;
    final completedBytes = await _resolveCompletedFileSize(filePath);
    final totalBytes = completedBytes ?? task.totalBytes;
    if (filePath == null) {
      await _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.completed,
          progress: 1,
          downloadedBytes: old.totalBytes ?? old.downloadedBytes,
          totalBytes: old.totalBytes,
          clearError: true,
        ),
      );
      return;
    }
    if (!_canWriteMetadata(task)) {
      final finalizedPaths = await _finalizeDownloadedArtifacts(
        filePath: filePath,
      );
      await _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.completed,
          progress: 1,
          downloadedBytes: completedBytes ?? totalBytes ?? old.downloadedBytes,
          totalBytes: totalBytes ?? old.totalBytes,
          filePath: finalizedPaths.filePath,
          lyricPath: finalizedPaths.lyricPath,
          clearError: true,
        ),
      );
      return;
    }
    await _updateTask(
      task.id,
      (old) => old.copyWith(
        status: DownloadTaskStatus.tagging,
        progress: 1,
        downloadedBytes: completedBytes ?? totalBytes ?? old.downloadedBytes,
        totalBytes: totalBytes ?? old.totalBytes,
        filePath: filePath,
        clearError: true,
      ),
    );
    await _writeMetadata(taskId: task.id, filePath: filePath);
  }

  Future<_FinalizedDownloadPaths> _finalizeDownloadedArtifacts({
    required String filePath,
    String? lyricPath,
  }) async {
    if (_disposed) {
      return _FinalizedDownloadPaths(filePath: filePath, lyricPath: lyricPath);
    }
    final repository = ref.read(downloadRepositoryProvider);
    if (!repository.shouldMoveToPublicDownloads) {
      return _FinalizedDownloadPaths(filePath: filePath, lyricPath: lyricPath);
    }
    final movedFilePath = await repository.moveToPublicDownloads(
      filePath: filePath,
      mimeType: _mimeTypeForPath(filePath),
    );
    if (movedFilePath == null || movedFilePath.trim().isEmpty) {
      throw StateError('Failed to move downloaded file to public Downloads.');
    }
    String? movedLyricPath;
    final normalizedLyricPath = lyricPath?.trim() ?? '';
    if (normalizedLyricPath.isNotEmpty) {
      movedLyricPath = await repository.moveToPublicDownloads(
        filePath: normalizedLyricPath,
        mimeType: _mimeTypeForPath(normalizedLyricPath),
      );
      if (movedLyricPath == null || movedLyricPath.trim().isEmpty) {
        throw StateError('Failed to move lyric file to public Downloads.');
      }
    }
    return _FinalizedDownloadPaths(
      filePath: movedFilePath,
      lyricPath: movedLyricPath,
    );
  }

  String? _mimeTypeForPath(String filePath) {
    final normalized = filePath.trim().toLowerCase();
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
    if (normalized.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (normalized.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (normalized.endsWith('.lrc')) {
      return 'application/octet-stream';
    }
    return null;
  }

  int? _resolveTotalBytes({required int? previous, required int? incoming}) {
    if (incoming != null && incoming > 0) {
      return incoming;
    }
    return previous;
  }

  int? _resolveDownloadedBytes({
    required double progress,
    required int? totalBytes,
    required int? previous,
  }) {
    if (totalBytes == null || totalBytes <= 0) {
      return previous;
    }
    if (progress <= 0) {
      return 0;
    }
    if (progress >= 1) {
      return totalBytes;
    }
    return (totalBytes * progress).round();
  }

  Future<int?> _resolveCompletedFileSize(String? filePath) async {
    final normalized = filePath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final file = File(normalized);
      if (!await file.exists()) {
        return null;
      }
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  DownloadState _withProcessing(List<DownloadTask> tasks) {
    final hasPending = tasks.any(
      (task) =>
          task.status == DownloadTaskStatus.queued ||
          task.status == DownloadTaskStatus.preparing ||
          task.status == DownloadTaskStatus.downloading,
    );
    return state.copyWith(tasks: tasks, isProcessing: hasPending);
  }

  void _validateUrl(String input) {
    final uri = Uri.tryParse(input);
    final scheme = uri?.scheme.toLowerCase();
    final valid = scheme == 'http' || scheme == 'https';
    if (valid) {
      return;
    }
    throw const AppException(
      ValidationFailure('Download only supports network URL (http/https).'),
    );
  }

  String _taskId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}

class _FinalizedDownloadPaths {
  const _FinalizedDownloadPaths({required this.filePath, this.lyricPath});

  final String filePath;
  final String? lyricPath;
}
