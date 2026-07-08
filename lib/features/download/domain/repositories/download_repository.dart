import 'dart:ui';

import '../entities/download_task.dart';

typedef DownloadProgressCallback = void Function(double progress);

class DownloadEnqueueRequest {
  const DownloadEnqueueRequest({
    required this.taskId,
    required this.pluginTaskId,
    required this.url,
    required this.savePath,
    this.metadata,
  });

  final String taskId;
  final String pluginTaskId;
  final String url;
  final String savePath;
  final String? metadata;
}

enum DownloadRunnerStatus {
  enqueued,
  running,
  complete,
  paused,
  canceled,
  failed,
  waitingToRetry,
  notFound,
}

class DownloadRunnerEvent {
  const DownloadRunnerEvent({
    required this.pluginTaskId,
    required this.status,
    this.progress,
    this.expectedFileSize,
    this.filePath,
    this.errorMessage,
  });

  final String pluginTaskId;
  final DownloadRunnerStatus status;
  final double? progress;
  final int? expectedFileSize;
  final String? filePath;
  final String? errorMessage;
}

abstract class DownloadRepository {
  bool get shouldMoveToPublicDownloads;

  Future<String> resolveSavePath({
    required String title,
    required String? artist,
    required String fileExtension,
  });

  Future<bool> enqueueTask(DownloadEnqueueRequest request);

  Future<void> pauseTask(String pluginTaskId);

  Future<void> resumeTask(String pluginTaskId);

  Future<void> removeTask(String pluginTaskId);

  Stream<DownloadRunnerEvent> watchEvents();

  Future<List<DownloadTask>> restoreTasks();

  Future<void> saveTask(DownloadTask task);

  Future<void> deleteTask(String taskId);

  Future<void> deleteDownloadedArtifacts({String? filePath, String? lyricPath});

  Future<void> openContainingFolder(String filePath);

  Future<void> exportFiles({
    required String filePath,
    String? lyricPath,
    Rect? sharePositionOrigin,
  });

  Future<String?> moveToPublicDownloads({
    required String filePath,
    String? mimeType,
  });

  Future<void> downloadFile({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  });
}
