import 'dart:async';

import 'package:background_downloader/background_downloader.dart' as bd;

import '../../domain/repositories/download_repository.dart';

const downloadPublicSubdirectory = 'HEMusic';

class DownloadRunnerDataSource {
  DownloadRunnerDataSource([bd.FileDownloader? downloader])
    : _downloader = downloader ?? bd.FileDownloader();

  final bd.FileDownloader _downloader;
  bool _started = false;

  Stream<DownloadRunnerEvent> watchEvents() async* {
    await _ensureStarted();
    await for (final update in _downloader.updates) {
      switch (update) {
        case bd.TaskProgressUpdate():
          yield DownloadRunnerEvent(
            pluginTaskId: update.task.taskId,
            status: DownloadRunnerStatus.running,
            progress: update.progress,
            expectedFileSize: update.hasExpectedFileSize
                ? update.expectedFileSize
                : null,
          );
        case bd.TaskStatusUpdate():
          yield DownloadRunnerEvent(
            pluginTaskId: update.task.taskId,
            status: _mapStatus(update.status),
            progress: _progressForStatus(update.status),
            filePath: await update.task.filePath(),
            errorMessage: update.exception?.description,
          );
      }
    }
  }

  Future<bool> enqueue(DownloadEnqueueRequest request) async {
    await _ensureStarted();
    final (baseDirectory, directory, filename) = await bd.Task.split(
      filePath: request.savePath,
    );
    final task = bd.DownloadTask(
      taskId: request.pluginTaskId,
      url: request.url,
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      allowPause: true,
      updates: bd.Updates.statusAndProgress,
      metaData: request.metadata ?? '',
    );
    return _downloader.enqueue(task);
  }

  Future<void> pause(String pluginTaskId) async {
    await _ensureStarted();
    final task = await _downloadTaskForId(pluginTaskId);
    if (task == null) {
      return;
    }
    await _downloader.pause(task);
  }

  Future<void> resume(String pluginTaskId) async {
    await _ensureStarted();
    final task = await _downloadTaskForId(pluginTaskId);
    if (task == null) {
      return;
    }
    await _downloader.resume(task);
  }

  Future<void> remove(String pluginTaskId) async {
    await _ensureStarted();
    await _downloader.cancelTaskWithId(pluginTaskId);
  }

  Future<void> download({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) async {
    await _ensureStarted();
    final (baseDirectory, directory, filename) = await bd.Task.split(
      filePath: savePath,
    );
    final task = bd.DownloadTask(
      url: url,
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      allowPause: true,
      updates: bd.Updates.statusAndProgress,
    );
    final result = await _downloader.download(task, onProgress: onProgress);
    if (result.status != bd.TaskStatus.complete) {
      throw StateError('Download failed with status: ${result.status.name}');
    }
  }

  Future<String?> moveToPublicDownloads({
    required String filePath,
    String? mimeType,
  }) async {
    await _ensureStarted();
    return _downloader.moveFileToSharedStorage(
      filePath,
      bd.SharedStorage.downloads,
      directory: downloadPublicSubdirectory,
      mimeType: mimeType,
    );
  }

  Future<bool> openFile({required String filePath, String? mimeType}) async {
    await _ensureStarted();
    return _downloader.openFile(filePath: filePath, mimeType: mimeType);
  }

  Future<void> _ensureStarted() async {
    if (_started) {
      return;
    }
    await _downloader.start(
      doTrackTasks: false,
      markDownloadedComplete: false,
      doRescheduleKilledTasks: false,
      autoCleanDatabase: false,
    );
    _started = true;
  }

  Future<bd.DownloadTask?> _downloadTaskForId(String pluginTaskId) async {
    final task = await _downloader.taskForId(pluginTaskId);
    return task is bd.DownloadTask ? task : null;
  }

  DownloadRunnerStatus _mapStatus(bd.TaskStatus status) {
    switch (status) {
      case bd.TaskStatus.enqueued:
        return DownloadRunnerStatus.enqueued;
      case bd.TaskStatus.running:
        return DownloadRunnerStatus.running;
      case bd.TaskStatus.complete:
        return DownloadRunnerStatus.complete;
      case bd.TaskStatus.paused:
        return DownloadRunnerStatus.paused;
      case bd.TaskStatus.canceled:
        return DownloadRunnerStatus.canceled;
      case bd.TaskStatus.failed:
        return DownloadRunnerStatus.failed;
      case bd.TaskStatus.waitingToRetry:
        return DownloadRunnerStatus.waitingToRetry;
      case bd.TaskStatus.notFound:
        return DownloadRunnerStatus.notFound;
    }
  }

  double? _progressForStatus(bd.TaskStatus status) {
    switch (status) {
      case bd.TaskStatus.complete:
        return 1;
      case bd.TaskStatus.failed:
      case bd.TaskStatus.canceled:
      case bd.TaskStatus.notFound:
        return 0;
      case bd.TaskStatus.enqueued:
      case bd.TaskStatus.running:
      case bd.TaskStatus.waitingToRetry:
      case bd.TaskStatus.paused:
        return null;
    }
  }
}
