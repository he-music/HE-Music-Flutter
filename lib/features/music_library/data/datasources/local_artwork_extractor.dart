import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import 'local_music_dao.dart';

/// 后台封面提取器
///
/// 扫描结束后查询 has_artwork=0 的歌曲，使用 Isolate 并发提取封面写入磁盘缓存。
/// - 并发控制：最多 3 个文件同时处理
/// - 可取消：用户离开页面或新扫描启动时取消当前任务
/// - 容错：单个文件提取失败跳过，不阻塞后续
class LocalArtworkExtractor {
  LocalArtworkExtractor(this._dao, this._metadataReader);

  final LocalMusicDao _dao;
  final LocalAudioMetadataReader _metadataReader;

  CancelableOperation? _currentOperation;
  String? _artworkDir;

  /// 获取封面缓存目录
  Future<String> get artworkDir async {
    if (_artworkDir != null) return _artworkDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _artworkDir = p.join(appDir.path, 'artwork');
    final dir = Directory(_artworkDir!);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return _artworkDir!;
  }

  /// 启动后台封面提取任务
  ///
  /// 查询所有 has_artwork=0 的歌曲，并发提取封面。
  /// 返回提取成功的数量。
  Future<int> extractAll() async {
    // 取消之前的任务
    cancel();

    final operation = CancelableOperation();
    _currentOperation = operation;

    try {
      final songsWithoutArtwork = await _dao.getSongsWithoutArtwork();
      if (songsWithoutArtwork.isEmpty || operation.isCancelled) return 0;

      final dir = await artworkDir;
      var successCount = 0;
      // 并发控制信号量
      var running = 0;
      final completer = Completer<void>();
      var index = 0;

      void processNext() {
        while (running < 3 && index < songsWithoutArtwork.length) {
          if (operation.isCancelled) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          final filePath = songsWithoutArtwork[index++];
          running++;
          _extractSingle(filePath, dir)
              .then((success) {
                if (success) successCount++;
              })
              .catchError((_) {
                // 单个文件失败跳过
              })
              .whenComplete(() {
                running--;
                if (index >= songsWithoutArtwork.length && running == 0) {
                  if (!completer.isCompleted) completer.complete();
                } else {
                  processNext();
                }
              });
        }
      }

      processNext();
      await completer.future;
      return successCount;
    } finally {
      if (_currentOperation == operation) {
        _currentOperation = null;
      }
    }
  }

  /// 取消当前提取任务
  void cancel() {
    _currentOperation?.cancel();
    _currentOperation = null;
  }

  /// 提取单个文件的封面
  Future<bool> _extractSingle(String filePath, String artworkDir) async {
    try {
      final metadata = await _metadataReader.read(filePath, fetchArtwork: true);
      if (metadata?.artworkBytes == null || metadata!.artworkBytes!.isEmpty) {
        return false;
      }

      // SHA-256 文件名
      final hash = sha256.convert(filePath.codeUnits).toString();
      final artworkFile = File(p.join(artworkDir, '$hash.jpg'));
      await artworkFile.writeAsBytes(metadata.artworkBytes!);

      // 更新 DB 标记
      await _dao.markArtworkExtractedByFilePath(filePath);
      return true;
    } catch (_) {
      return false;
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
    cancel();
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

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
