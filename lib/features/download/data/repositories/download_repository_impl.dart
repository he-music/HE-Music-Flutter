import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/download_path_data_source.dart';
import '../datasources/download_runner_data_source.dart';
import '../datasources/download_task_store_data_source.dart';

const _fallbackExtension = 'mp3';
const _safeNameFallback = 'audio';

abstract interface class PlatformInfo {
  bool get isAndroid;
  bool get isIOS;
  bool get isMacOS;
}

class _DefaultPlatformInfo implements PlatformInfo {
  const _DefaultPlatformInfo();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isMacOS => Platform.isMacOS;
}

typedef PlatformResolver = PlatformInfo Function();
typedef DirectoryOpener = Future<bool> Function(Uri directoryUri);
typedef FileRevealHandler = Future<void> Function(String filePath);
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef SharedFileHandler =
    Future<void> Function(List<SharedFile> files, {Rect? sharePositionOrigin});

class SharedFile {
  const SharedFile({required this.path, this.mimeType});

  final String path;
  final String? mimeType;
}

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl(
    this._runnerDataSource,
    this._taskStoreDataSource,
    this._pathDataSource, {
    PlatformResolver? platformResolver,
    DirectoryOpener? openDirectory,
    FileRevealHandler? revealInFileManager,
    SharedFileHandler? shareFiles,
  }) : _platformResolver = platformResolver ?? _defaultPlatformResolver,
       _openDirectory = openDirectory ?? _defaultOpenDirectory,
       _revealInFileManager = revealInFileManager ?? buildRevealInFileManager(),
       _shareFilesOverride = shareFiles;

  final DownloadRunnerDataSource _runnerDataSource;
  final DownloadTaskStoreDataSource _taskStoreDataSource;
  final DownloadPathDataSource _pathDataSource;
  final PlatformResolver _platformResolver;
  final DirectoryOpener _openDirectory;
  final FileRevealHandler _revealInFileManager;
  final SharedFileHandler? _shareFilesOverride;

  @override
  bool get shouldMoveToPublicDownloads => _platformResolver().isAndroid;

  @override
  Future<String> resolveSavePath({
    required String title,
    required String? artist,
    required String fileExtension,
  }) async {
    final extension = _normalizeExtension(fileExtension);
    final fileBaseName = _buildFileBaseName(title: title, artist: artist);
    final dir = await _pathDataSource.ensureDownloadDirectory();
    return '${dir.path}/$fileBaseName.$extension';
  }

  @override
  Future<bool> enqueueTask(DownloadEnqueueRequest request) {
    return _runnerDataSource.enqueue(request);
  }

  @override
  Future<void> pauseTask(String pluginTaskId) {
    return _runnerDataSource.pause(pluginTaskId);
  }

  @override
  Future<void> resumeTask(String pluginTaskId) {
    return _runnerDataSource.resume(pluginTaskId);
  }

  @override
  Future<void> removeTask(String pluginTaskId) {
    return _runnerDataSource.remove(pluginTaskId);
  }

  @override
  Stream<DownloadRunnerEvent> watchEvents() {
    return _runnerDataSource.watchEvents();
  }

  @override
  Future<List<DownloadTask>> restoreTasks() {
    return _taskStoreDataSource.loadTasks();
  }

  @override
  Future<void> saveTask(DownloadTask task) {
    return _taskStoreDataSource.saveTask(task);
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _taskStoreDataSource.deleteTask(taskId);
  }

  @override
  Future<void> deleteDownloadedArtifacts({
    String? filePath,
    String? lyricPath,
  }) async {
    await _deleteFileIfExists(filePath);
    await _deleteFileIfExists(lyricPath);
  }

  @override
  Future<void> openContainingFolder(String filePath) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      return;
    }
    final platform = _platformResolver();
    if (platform.isMacOS) {
      await _revealInFileManager(normalizedPath);
      return;
    }
    if (platform.isAndroid || platform.isIOS) {
      await _runnerDataSource.openFile(
        filePath: normalizedPath,
        mimeType: _mimeTypeForPath(normalizedPath),
      );
      return;
    }
    final directoryUri = File(normalizedPath).parent.uri;
    await _openDirectory(directoryUri);
  }

  @override
  Future<void> exportFiles({
    required String filePath,
    String? lyricPath,
    Rect? sharePositionOrigin,
  }) async {
    final normalizedFilePath = filePath.trim();
    if (normalizedFilePath.isEmpty) {
      return;
    }
    final files = <SharedFile>[
      SharedFile(
        path: normalizedFilePath,
        mimeType: _mimeTypeForPath(normalizedFilePath),
      ),
    ];
    final normalizedLyricPath = lyricPath?.trim() ?? '';
    if (normalizedLyricPath.isNotEmpty) {
      files.add(
        SharedFile(
          path: normalizedLyricPath,
          mimeType: _mimeTypeForPath(normalizedLyricPath),
        ),
      );
    }
    await (_shareFilesOverride ?? _defaultShareFiles)(
      files,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  @override
  Future<String?> moveToPublicDownloads({
    required String filePath,
    String? mimeType,
  }) {
    return _runnerDataSource.moveToPublicDownloads(
      filePath: filePath,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) {
    return _runnerDataSource.download(
      url: url,
      savePath: savePath,
      onProgress: onProgress,
    );
  }

  String _normalizeExtension(String fileExtension) {
    final normalized = fileExtension.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _fallbackExtension;
    }
    return normalized.startsWith('.') ? normalized.substring(1) : normalized;
  }

  String _sanitize(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return _safeNameFallback;
    }
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '、')
        .replaceAll(RegExp(r'、+'), '、')
        .replaceAll(RegExp(r'\.+$'), '')
        .trim();
    return sanitized.isEmpty ? _safeNameFallback : sanitized;
  }

  String _buildFileBaseName({required String title, required String? artist}) {
    final normalizedTitle = _sanitize(title);
    final normalizedArtist = _normalizeArtist(artist);
    if (normalizedArtist == null) {
      return normalizedTitle;
    }
    return '$normalizedTitle - $normalizedArtist';
  }

  String? _normalizeArtist(String? artist) {
    final raw = (artist ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final parts = raw
        .split(RegExp(r'\s*(?:/|,|，|&)\s*'))
        .map((item) => _sanitize(item))
        .where((item) => item.isNotEmpty && item != _safeNameFallback)
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('、');
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

  Future<void> _deleteFileIfExists(String? path) async {
    final normalizedPath = (path ?? '').trim();
    if (normalizedPath.isEmpty) {
      return;
    }
    final file = File(normalizedPath);
    if (!await file.exists()) {
      return;
    }
    await file.delete();
  }

  static PlatformInfo _defaultPlatformResolver() {
    return const _DefaultPlatformInfo();
  }

  static Future<bool> _defaultOpenDirectory(Uri directoryUri) {
    return launchUrl(directoryUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _defaultShareFiles(
    List<SharedFile> files, {
    Rect? sharePositionOrigin,
  }) async {
    if (files.isEmpty) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        sharePositionOrigin: sharePositionOrigin,
        files: files
            .map((file) => XFile(file.path, mimeType: file.mimeType))
            .toList(growable: false),
      ),
    );
  }

  static FileRevealHandler buildRevealInFileManager({
    ProcessRunner? processRunner,
    String executablePath = 'open',
  }) {
    final runner = processRunner ?? Process.run;
    return (filePath) async {
      final result = await runner(executablePath, <String>['-R', filePath]);
      if (result.exitCode != 0) {
        throw ProcessException(
          executablePath,
          <String>['-R', filePath],
          result.stderr?.toString() ?? '',
          result.exitCode,
        );
      }
    };
  }
}
