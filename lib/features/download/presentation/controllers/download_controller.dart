import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/audio/audio_player_factory.dart';
import '../../../../core/audio/decrypt/audio_transform_parameters.dart';
import '../../../../core/error/failure.dart';
import '../../../music_library/data/providers/local_library_providers.dart';
import '../../data/services/download_metadata_writer.dart';
import '../../data/services/download_audio_decryptor.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_repository.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../providers/download_providers.dart';
import '../providers/downloaded_music_providers.dart';

class _ResolvedDownloadSource {
  const _ResolvedDownloadSource({
    required this.url,
    required this.fileExtension,
    this.audioParams,
  });

  final String url;
  final String fileExtension;
  final String? audioParams;
}

class DownloadController extends Notifier<DownloadState> {
  StreamSubscription<DownloadRunnerEvent>? _eventsSubscription;
  bool _disposed = false;
  final Map<String, DateTime> _lastProgressWrite = {};
  Future<void>? _restoringTasks;
  final Set<String> _processingTasks = {};
  final Map<String, Completer<void>> _processingCompletions = {};

  @override
  DownloadState build() {
    _bindRunnerEvents();
    _restoringTasks = _restoreTasks();
    unawaited(_restoringTasks);
    ref.onDispose(() {
      _disposed = true;
      unawaited(_eventsSubscription?.cancel());
    });
    return DownloadState.initial;
  }

  Future<void> enqueue({
    required String title,
    String? taskId,
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
      id: taskId ?? _taskId(),
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
    if (task.processingStage != DownloadProcessingStage.transfer ||
        _processingTasks.contains(task.id)) {
      await _updateTask(
        task.id,
        (old) => old.copyWith(status: DownloadTaskStatus.paused),
      );
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
    if (task.processingStage != DownloadProcessingStage.transfer) {
      await retry(task.id);
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
    if (_processingTasks.contains(taskId)) return;
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    await _deleteProcessingFiles(task);
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
        clearProcessing: true,
        clearFinishedAt: true,
        clearError: true,
      ),
    );
    await _dispatchQueuedTasks();
  }

  Future<void> redownloadSavedSong(DownloadTask saved) async {
    await _restoringTasks;
    if (_disposed) return;
    final retained = _findTask(saved.id);
    if (retained != null) {
      if (state.runningTasks.any((task) => task.id == saved.id) ||
          retained.status == DownloadTaskStatus.queued) {
        return;
      }
      await redownload(saved.id);
      return;
    }
    await enqueue(
      taskId: saved.id,
      title: saved.title,
      url:
          (saved.songId?.isNotEmpty ?? false) &&
              (saved.platform?.isNotEmpty ?? false)
          ? ''
          : saved.url,
      songId: saved.songId,
      platform: saved.platform,
      artist: saved.artist,
      album: saved.album,
      artworkUrl: saved.artworkUrl,
      quality: saved.quality,
    );
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

  Future<void> clearCompleted() async {
    final completed = state.tasks
        .where((task) => task.status == DownloadTaskStatus.completed)
        .map((task) => task.id)
        .toSet();
    final repository = ref.read(downloadRepositoryProvider);
    for (final id in completed) {
      await repository.deleteTask(id);
    }
    if (_disposed) return;
    state = _withProcessing(
      state.tasks.where((task) => !completed.contains(task.id)).toList(),
    );
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
    state = _withProcessing([
      for (final task in mergedTasks)
        if (task.processingStage != DownloadProcessingStage.transfer &&
            (task.status == DownloadTaskStatus.tagging ||
                task.status == DownloadTaskStatus.preparing ||
                task.status == DownloadTaskStatus.downloading))
          task.copyWith(status: DownloadTaskStatus.queued)
        else
          task,
    ]);
    // Local work uses the same queue capacity as native transfers. Do not block
    // background-event replay on a potentially long decryption.
    unawaited(_dispatchQueuedTasks());
  }

  Future<void> _removeTask(String taskId, {bool deleteFiles = false}) async {
    final repository = ref.read(downloadRepositoryProvider);
    final processing = _processingCompletions[taskId]?.future;
    if (processing != null) {
      await _updateTask(
        taskId,
        (old) => old.copyWith(status: DownloadTaskStatus.paused),
      );
      // Publication may already be in the native shared-storage move. Let it
      // journal its returned path before taking the snapshot used for deletion.
      await processing;
      if (_disposed) return;
    }
    final target = _findTask(taskId);
    final localLibrary =
        deleteFiles && target != null && (Platform.isIOS || Platform.isMacOS)
        ? ref.read(localMusicRepositoryProvider)
        : null;
    if (target != null) {
      await repository.removeTask(target.id);
      if (deleteFiles) {
        try {
          await repository.deleteDownloadedArtifacts(
            filePath: target.filePath,
            lyricPath: target.lyricPath,
          );
          if (target.publicationSourcePath != null &&
              target.publicationSourcePath != target.filePath) {
            await repository.deleteDownloadedArtifacts(
              filePath: target.publicationSourcePath,
            );
          }
          if (target.artworkPath != null) {
            await repository.deleteDownloadedArtifacts(
              filePath: target.artworkPath,
            );
          }
        } finally {
          final filePath = target.filePath?.trim() ?? '';
          if (filePath.isNotEmpty) {
            await localLibrary?.markFileMissingByPath(filePath);
          }
          if (!_disposed) ref.invalidate(downloadedSongsProvider);
        }
      }
    }
    await repository.deleteTask(taskId);
    if (target != null && !_processingTasks.contains(taskId)) {
      await _deleteProcessingFiles(target);
    }
    if (_disposed) return;
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
    final queued = state.waitingTasks
        .where((task) => !_processingTasks.contains(task.id))
        .take(capacity)
        .toList(growable: false);
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
    if (currentTask.processingStage != DownloadProcessingStage.transfer) {
      await _finalizeTask(task.id);
      return;
    }
    try {
      final resolvedSource = await _resolveDownloadSource(currentTask);
      var savePath = await repository.resolveSavePath(
        title: currentTask.title,
        artist: currentTask.artist,
        fileExtension: resolvedSource.fileExtension,
      );
      if (state.tasks.any(
        (other) => other.id != task.id && other.filePath == savePath,
      )) {
        final extension = '.${resolvedSource.fileExtension}';
        final base = savePath.substring(0, savePath.length - extension.length);
        savePath = '$base (${task.id})$extension';
      }
      final encrypted = resolvedSource.audioParams != null;
      final encryptedPath = encrypted ? '$savePath.${task.id}.encrypted' : null;
      final decryptedPath = encrypted
          ? '$savePath.${task.id}.clear.${resolvedSource.fileExtension}'
          : null;
      // Persist the source and staging paths before the native runner can finish.
      await _updateTask(
        task.id,
        (old) => old.copyWith(
          filePath: savePath,
          resolvedFileExtension: resolvedSource.fileExtension,
          url: resolvedSource.url,
          audioParams: resolvedSource.audioParams,
          encryptedFilePath: encryptedPath,
          decryptedFilePath: decryptedPath,
        ),
      );
      if (_findTask(task.id)?.status != DownloadTaskStatus.preparing) return;
      final userAgent = encrypted
          ? AudioTransformParameters.parse(
              resolvedSource.audioParams!,
            ).userAgent
          : null;
      final request = DownloadEnqueueRequest(
        taskId: task.id,
        pluginTaskId: task.id,
        url: resolvedSource.url,
        savePath: encryptedPath ?? savePath,
        headers: {
          'User-Agent': userAgent == null || userAgent.trim().isEmpty
              ? heAudioUserAgent
              : userAgent,
        },
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
    } catch (_) {
      await _updateTask(
        task.id,
        (old) => old.copyWith(
          status: DownloadTaskStatus.failed,
          errorMessage: 'Unable to prepare download.',
        ),
      );
    }
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
        audioParams: task.audioParams,
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
      audioParams: resolution.audioParams,
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
    await _restoringTasks;
    if (_disposed) {
      return;
    }
    final task = _findTask(event.pluginTaskId);
    if (task == null ||
        _processingTasks.contains(task.id) ||
        task.processingStage != DownloadProcessingStage.transfer ||
        task.status == DownloadTaskStatus.completed ||
        task.status == DownloadTaskStatus.tagging) {
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
        await _updateTask(
          task.id,
          (old) {
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
              filePath: old.audioParams == null
                  ? event.filePath ?? old.filePath
                  : old.filePath,
              clearError: true,
            );
          },
          persist:
              task.status != DownloadTaskStatus.downloading ||
              DateTime.now().difference(
                    _lastProgressWrite[task.id] ?? DateTime(0),
                  ) >=
                  const Duration(seconds: 2),
        );
      case DownloadRunnerStatus.complete:
        if (task.audioParams != null) {
          await _updateTask(
            task.id,
            (old) => old.copyWith(
              status: DownloadTaskStatus.tagging,
              processingStage: DownloadProcessingStage.decrypting,
              encryptedFilePath: event.filePath ?? old.encryptedFilePath,
              progress: 1,
            ),
          );
        }
        await _finalizeTask(
          task.id,
          filePath: task.audioParams == null ? event.filePath : null,
        );
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
            errorMessage: task.audioParams != null
                ? 'Download failed.'
                : event.errorMessage ?? 'Download failed.',
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
    DownloadTask Function(DownloadTask task) updater, {
    bool persist = true,
  }) async {
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
    if (next != null && persist) {
      await _persistTask(next);
    }
  }

  Future<void> _persistTask(DownloadTask task) {
    if (_disposed) {
      return Future<void>.value();
    }
    _lastProgressWrite[task.id] = DateTime.now();
    return ref.read(downloadRepositoryProvider).saveTask(task);
  }

  bool _canWriteMetadata(DownloadTask task) {
    return (task.songId ?? '').trim().isNotEmpty &&
        (task.platform ?? '').trim().isNotEmpty &&
        (task.artist ?? '').trim().isNotEmpty &&
        (task.album ?? '').trim().isNotEmpty;
  }

  Future<void> _importCompletedSong(String filePath) async {
    if (_disposed || (!Platform.isIOS && !Platform.isMacOS)) return;
    try {
      await ref.read(localMusicRepositoryProvider).importSong(filePath);
    } catch (error, stackTrace) {
      // The completed download stays available even if indexing fails.
      debugPrint('Local song import failed filePath=$filePath error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _canContinueProcessing(String id) {
    if (_disposed) return false;
    final task = _findTask(id);
    return task != null &&
        task.status != DownloadTaskStatus.paused &&
        task.status != DownloadTaskStatus.queued &&
        task.status != DownloadTaskStatus.completed;
  }

  Future<void> _deleteProcessingFiles(DownloadTask task) async {
    if (task.encryptedFilePath == null && task.decryptedFilePath == null) {
      return;
    }
    final repository = ref.read(downloadRepositoryProvider);
    await repository.deleteDownloadedArtifacts(
      filePath: task.encryptedFilePath,
      lyricPath: task.decryptedFilePath,
    );
    final clearPath = task.decryptedFilePath;
    if (clearPath != null) {
      final artwork = '$clearPath.cover';
      final lyric = clearPath.replaceFirst(RegExp(r'\.[^.]+$'), '.lrc');
      await repository.deleteDownloadedArtifacts(
        filePath: artwork == task.artworkPath ? null : artwork,
        lyricPath: lyric == task.lyricPath ? null : lyric,
      );
    }
  }

  Future<void> _finalizeTask(String taskId, {String? filePath}) async {
    if (!_processingTasks.add(taskId)) return;
    final completion = Completer<void>();
    _processingCompletions[taskId] = completion;
    final original = _findTask(taskId);
    try {
      await _processDownloadedTask(taskId, filePath: filePath);
    } catch (_) {
      if (_canContinueProcessing(taskId)) {
        await _updateTask(
          taskId,
          (old) => old.copyWith(
            status: DownloadTaskStatus.failed,
            errorMessage:
                'Unable to process downloaded audio. Retry to continue.',
          ),
        );
      }
    } finally {
      try {
        if (!_disposed && _findTask(taskId) == null && original != null) {
          await _deleteProcessingFiles(original);
        }
      } finally {
        _processingTasks.remove(taskId);
        _processingCompletions.remove(taskId);
        completion.complete();
        if (!_disposed) unawaited(_dispatchQueuedTasks());
      }
    }
  }

  Future<void> _processDownloadedTask(String taskId, {String? filePath}) async {
    final task = _findTask(taskId);
    if (task == null) return;
    await _updateTask(
      taskId,
      (old) => old.copyWith(
        status: DownloadTaskStatus.tagging,
        progress: 1,
        clearError: true,
      ),
    );
    if (!_canContinueProcessing(taskId)) return;
    var audioPath = filePath ?? task.filePath;
    final encrypted = task.processingStage != DownloadProcessingStage.transfer;
    final publicationStarted =
        task.processingStage == DownloadProcessingStage.publishing ||
        task.processingStage == DownloadProcessingStage.published;
    if (encrypted && !publicationStarted) {
      final output = File(task.decryptedFilePath!);
      if (task.processingStage == DownloadProcessingStage.decrypting) {
        // The shared executor publishes this output only on success. This also
        // recovers a process exit between output publication and journal save.
        if (!await output.exists()) {
          await ref.read(downloadAudioDecryptorProvider)(
            input: File(task.encryptedFilePath!),
            output: output,
            encodedParameters: task.audioParams!,
          );
        }
        if (_disposed || _findTask(taskId) == null) return;
        await _updateTask(
          taskId,
          (old) =>
              old.copyWith(processingStage: DownloadProcessingStage.decrypted),
        );
      }
      if (!_canContinueProcessing(taskId)) return;
      // A rename may have completed before the journal was updated.
      audioPath = await output.exists() ? output.path : task.filePath;
      if (audioPath == null || !await File(audioPath).exists()) {
        throw const FileSystemException('Decrypted audio is missing');
      }
    }
    final completedBytes = await _resolveCompletedFileSize(audioPath);
    if (encrypted &&
        !publicationStarted &&
        (completedBytes == null || completedBytes <= 0)) {
      throw const FileSystemException(
        'Decrypted audio is empty or unavailable',
      );
    }
    DownloadMetadataWriteResult? metadata;
    if (!publicationStarted && audioPath != null && _canWriteMetadata(task)) {
      try {
        metadata = await ref
            .read(downloadMetadataWriterProvider)
            .write(
              DownloadMetadataRequest(
                filePath: audioPath,
                songId: task.songId!,
                platform: task.platform!,
                title: task.title,
                artist: task.artist!,
                album: task.album!,
                artworkUrl: task.artworkUrl,
              ),
            );
      } catch (error) {
        if (_canContinueProcessing(taskId)) {
          await _updateTask(
            taskId,
            (old) => old.copyWith(
              status: DownloadTaskStatus.failed,
              tagWriteStatus: DownloadTagWriteStatus.failed,
              errorMessage: encrypted
                  ? 'Unable to write download metadata.'
                  : '$error',
            ),
          );
        }
        return;
      }
    }
    if (!_canContinueProcessing(taskId)) return;
    var lyricPath = metadata?.lyricPath ?? task.lyricPath;
    if (encrypted && !publicationStarted && audioPath != task.filePath) {
      await File(audioPath!).rename(task.filePath!);
      // Sidecar names must follow the final audio basename too.
      if (lyricPath != null) {
        final finalLyric = task.filePath!.replaceFirst(
          RegExp(r'\.[^.]+$'),
          '.lrc',
        );
        await File(lyricPath).rename(finalLyric);
        lyricPath = finalLyric;
      }
      audioPath = task.filePath;
    }
    if (encrypted && !publicationStarted) {
      final publicationDirectory = Directory(
        '${File(audioPath!).parent.path}/.publish-${task.id}',
      );
      final publicationCopy =
          '${publicationDirectory.path}/${File(audioPath).uri.pathSegments.last}';
      await _updateTask(
        taskId,
        (old) => old.copyWith(
          processingStage: DownloadProcessingStage.publishing,
          publicationSourcePath: audioPath,
          downloadedBytes: completedBytes ?? old.downloadedBytes,
          totalBytes: completedBytes ?? old.totalBytes,
          decryptedFilePath: publicationCopy,
          lyricPath: lyricPath,
          artworkPath: metadata?.artworkPath,
          tagWriteStatus: metadata == null
              ? old.tagWriteStatus
              : DownloadTagWriteStatus.success,
          lyricFormat: metadata?.lyricFormat ?? old.lyricFormat,
        ),
      );
    }
    final paths = audioPath == null
        ? null
        : await _finalizeDownloadedArtifacts(
            taskId: taskId,
            filePath: audioPath,
            lyricPath: lyricPath,
          );
    if (!_canContinueProcessing(taskId)) return;
    final processingTask = _findTask(taskId)!;
    await _updateTask(
      taskId,
      (old) => old.copyWith(
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes:
            completedBytes ?? old.totalBytes ?? old.downloadedBytes,
        totalBytes: completedBytes ?? old.totalBytes,
        finishedAt: DateTime.now(),
        filePath: paths?.filePath,
        lyricPath: paths?.lyricPath,
        artworkPath: metadata?.artworkPath,
        tagWriteStatus: metadata == null
            ? old.tagWriteStatus
            : DownloadTagWriteStatus.success,
        lyricFormat: metadata?.lyricFormat ?? old.lyricFormat,
        clearProcessing: true,
        clearError: true,
      ),
    );
    if (encrypted) {
      await _deleteProcessingFiles(processingTask);
      final source = _findTask(taskId)?.filePath;
      final publicationSource =
          processingTask.publicationSourcePath ?? audioPath;
      if (publicationSource != null && source != publicationSource) {
        await ref
            .read(downloadRepositoryProvider)
            .deleteDownloadedArtifacts(
              filePath: publicationSource,
              lyricPath: processingTask.lyricPath != paths?.lyricPath
                  ? processingTask.lyricPath
                  : null,
            );
      }
    }
    if (paths != null) await _importCompletedSong(paths.filePath);
  }

  Future<_FinalizedDownloadPaths> _finalizeDownloadedArtifacts({
    required String taskId,
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
    final task = _findTask(taskId)!;
    final encrypted = task.processingStage != DownloadProcessingStage.transfer;
    var moveSource = filePath;
    if (encrypted &&
        task.processingStage != DownloadProcessingStage.published) {
      // Shared-storage moves are destructive. Retain the clear source until the
      // returned public path has been journaled, including across process exits.
      await File(task.decryptedFilePath!).parent.create(recursive: true);
      moveSource = (await File(filePath).copy(task.decryptedFilePath!)).path;
    }
    final movedFilePath =
        task.processingStage == DownloadProcessingStage.published
        ? filePath
        : await repository.moveToPublicDownloads(
            filePath: moveSource,
            mimeType: _mimeTypeForPath(filePath),
          );
    if (movedFilePath == null || movedFilePath.trim().isEmpty) {
      throw StateError('Failed to move downloaded file to public Downloads.');
    }
    await _updateTask(
      taskId,
      (old) => old.copyWith(
        filePath: movedFilePath,
        processingStage: old.processingStage == DownloadProcessingStage.transfer
            ? old.processingStage
            : DownloadProcessingStage.published,
      ),
    );
    String? movedLyricPath;
    final normalizedLyricPath = lyricPath?.trim() ?? '';
    if (normalizedLyricPath.isNotEmpty) {
      var lyricMoveSource = normalizedLyricPath;
      if (encrypted) {
        final copyDirectory = File(task.decryptedFilePath!).parent;
        await copyDirectory.create(recursive: true);
        lyricMoveSource = (await File(normalizedLyricPath).copy(
          '${copyDirectory.path}/${File(normalizedLyricPath).uri.pathSegments.last}',
        )).path;
      }
      movedLyricPath = await repository.moveToPublicDownloads(
        filePath: lyricMoveSource,
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
