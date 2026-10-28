import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import 'local_music_dao.dart';
import 'local_artwork_scan.dart';

/// 后台封面提取器
///
/// 按文件指纹缓存封面检查结果，最多并发读取 3 个文件。
/// 每 30 首批量更新数据库；取消后等待在途任务退出，避免旧任务覆盖新扫描。
class LocalArtworkExtractor {
  LocalArtworkExtractor(
    this._dao,
    this._metadataReader, {
    Future<String> Function()? artworkDirectory,
  }) : _artworkDirectory = artworkDirectory;

  final LocalMusicDao _dao;
  final LocalAudioMetadataReader _metadataReader;
  final Future<String> Function()? _artworkDirectory;

  CancelableOperation? _currentOperation;
  String? _artworkDir;

  /// 获取封面缓存目录
  Future<String> get artworkDir async {
    if (_artworkDir != null) return _artworkDir!;
    _artworkDir = _artworkDirectory != null
        ? await _artworkDirectory()
        : p.join((await getApplicationDocumentsDirectory()).path, 'artwork');
    final dir = Directory(_artworkDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _artworkDir!;
  }

  /// 启动后台封面提取任务
  ///
  /// 只检查未知封面或达到重试时间的失败项；确认无封面的文件无需重读。
  /// 返回本次成功提取的数量。
  Future<int> extractAll() async {
    final previous = _currentOperation;
    previous?.cancel();
    final operation = CancelableOperation();
    _currentOperation = operation;
    try {
      await previous?.done;
      if (operation.isCancelled) return 0;
      final jobs = await _dao.getPendingArtwork();
      if (jobs.isEmpty || operation.isCancelled) return 0;
      final dir = await artworkDir;
      var successCount = 0;
      for (var start = 0; start < jobs.length; start += 30) {
        if (operation.isCancelled) break;
        final chunk = jobs.sublist(start, (start + 30).clamp(0, jobs.length));
        final results = <LocalArtworkResult>[];
        var nextIndex = 0;
        Future<void> worker() async {
          while (!operation.isCancelled && nextIndex < chunk.length) {
            final job = chunk[nextIndex++];
            final result = await _extractSingle(job, dir, operation);
            if (result != null) results.add(result);
          }
        }

        await Future.wait(
          List.generate(chunk.length < 3 ? chunk.length : 3, (_) => worker()),
        );
        if (operation.isCancelled) break;
        await _dao.commitArtworkResults(results);
        successCount += results
            .where((result) => result.state == LocalArtworkState.present)
            .length;
      }
      return successCount;
    } finally {
      operation.complete();
      if (_currentOperation == operation) _currentOperation = null;
    }
  }

  /// 取消当前提取任务
  void cancel() {
    _currentOperation?.cancel();
  }

  Future<void> cancelAndWait() async {
    final operation = _currentOperation;
    operation?.cancel();
    await operation?.done;
  }

  /// 提取单个文件的封面
  Future<LocalArtworkResult?> _extractSingle(
    LocalArtworkJob job,
    String artworkDir,
    CancelableOperation operation,
  ) async {
    try {
      final bytes = await _metadataReader.readArtwork(job.filePath);
      if (operation.isCancelled) return null;
      final hash = sha256.convert(job.filePath.codeUnits).toString();
      final artworkFile = File(p.join(artworkDir, '$hash.jpg'));
      if (bytes == null || bytes.isEmpty) {
        if (await artworkFile.exists()) await artworkFile.delete();
        return LocalArtworkResult(job, LocalArtworkState.absent);
      }
      await artworkFile.writeAsBytes(bytes);
      if (operation.isCancelled) return null;
      return LocalArtworkResult(job, LocalArtworkState.present);
    } catch (_) {
      if (operation.isCancelled) return null;
      return LocalArtworkResult(job, LocalArtworkState.failed);
    }
  }

  /// 根据文件路径获取封面缓存文件
  Future<File?> getArtworkFile(String filePath) async {
    final hash = sha256.convert(filePath.codeUnits).toString();
    final dir = await artworkDir;
    final file = File(p.join(dir, '$hash.jpg'));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// 读取封面字节数据
  Future<List<int>?> getArtworkBytes(String filePath) async {
    final file = await getArtworkFile(filePath);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// 清除全部封面缓存文件
  Future<void> clearAllArtwork() async {
    await cancelAndWait();
    final dir = Directory(await artworkDir);
    if (await dir.exists()) {
      await for (final file in dir.list()) {
        if (file is File) {
          try {
            await file.delete();
          } catch (_) {
            // 忽略删除失败
          }
        }
      }
    }
  }

  /// 清理失效的封面文件
  ///
  /// 删除不在 [activeFilePaths] 中的封面文件。
  /// 用于扫描完成后清理已移除歌曲的封面缓存。
  Future<void> cleanupStaleArtwork(List<String> activeFilePaths) async {
    final activeHashes = activeFilePaths
        .map((p) => sha256.convert(p.codeUnits).toString())
        .toSet();
    final dir = Directory(await artworkDir);
    if (!await dir.exists()) return;
    await for (final file in dir.list()) {
      if (file is File) {
        final fileName = p.basenameWithoutExtension(file.path);
        if (!activeHashes.contains(fileName)) {
          try {
            await file.delete();
          } catch (_) {
            // 忽略删除失败
          }
        }
      }
    }
  }

  /// LRU 缓存清理
  ///
  /// 当缓存目录总大小超过 [maxBytes] 时，按文件最后访问时间删除最旧的文件。
  Future<void> enforceMaxCacheSize(int maxBytes) async {
    final dir = Directory(await artworkDir);
    if (!await dir.exists()) return;

    final files = <FileSystemEntity>[];
    await for (final file in dir.list()) {
      if (file is File) files.add(file);
    }

    // 计算总大小
    var totalSize = 0;
    for (final file in files) {
      totalSize += await (file as File).length();
    }

    if (totalSize <= maxBytes) return;

    // 按最后访问时间排序（最旧的在前）
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return aStat.accessed.compareTo(bStat.accessed);
    });

    // 从最旧的文件开始删除，直到总大小低于限制
    for (final file in files) {
      if (totalSize <= maxBytes) break;
      final fileSize = await (file as File).length();
      try {
        await file.delete();
        totalSize -= fileSize;
      } catch (_) {
        // 忽略删除失败
      }
    }
  }
}

/// 可取消的异步操作
class CancelableOperation {
  bool _isCancelled = false;
  final _completion = Completer<void>();
  Future<void> get done => _completion.future;

  void complete() {
    if (!_completion.isCompleted) _completion.complete();
  }

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
