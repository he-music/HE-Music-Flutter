import 'dart:io';

import '../../domain/entities/download_task.dart';
import '../../domain/entities/downloaded_song.dart';
import '../../domain/repositories/downloaded_music_repository.dart';
import '../datasources/download_task_store_data_source.dart';
import '../datasources/downloaded_music_data_source.dart';

class DownloadedMusicRepositoryImpl implements DownloadedMusicRepository {
  DownloadedMusicRepositoryImpl({
    required DownloadedMusicDataSource dataSource,
    required DownloadTaskStoreDataSource taskStore,
  }) : _dataSource = dataSource,
       _taskStore = taskStore;

  final DownloadedMusicDataSource _dataSource;
  final DownloadTaskStoreDataSource _taskStore;
  Future<void>? _initializing;

  Future<void> _initialize() => _initializing ??= _importTasks();

  Future<void> _importTasks() async {
    try {
      await _taskStore.loadTasks();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  @override
  Stream<List<DownloadedSong>> watchSongs() async* {
    await _initialize();
    await for (final tasks in _dataSource.watchTasks()) {
      yield await Future.wait(tasks.map(_resolve));
    }
  }

  @override
  Future<DownloadedSong?> findPlayable({
    required String songId,
    required String platform,
    String? filePath,
  }) async {
    if (songId.trim().isEmpty ||
        platform.trim().isEmpty ||
        platform == 'local') {
      return null;
    }
    await _initialize();
    for (final task in await _dataSource.find(songId, platform)) {
      if (filePath != null && task.filePath != filePath) continue;
      final song = await _resolve(task);
      if (song.isAvailable) return song;
    }
    return null;
  }

  Future<DownloadedSong> _resolve(DownloadTask task) async {
    var available = false;
    try {
      final path = task.filePath!;
      final file = path.startsWith('file:')
          ? File.fromUri(Uri.parse(path))
          : File(path);
      available = await file.exists() && await file.length() > 0;
    } on FileSystemException {
      // Deleted files and revoked access remain visible for redownload.
    }
    return DownloadedSong(task: task, isAvailable: available);
  }

  @override
  Future<void> remove(String id) async {
    await _initialize();
    await _dataSource.remove(id);
  }
}
