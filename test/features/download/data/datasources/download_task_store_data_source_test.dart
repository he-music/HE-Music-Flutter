import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/data/datasources/download_task_store_data_source.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

DownloadTask _task(
  String id, {
  DownloadTaskStatus status = DownloadTaskStatus.queued,
}) {
  return DownloadTask(
    id: id,
    title: 'Song $id',
    url: 'https://a.com/$id.mp3',
    status: status,
    progress: 0,
    quality: DownloadTaskQuality(
      label: 'standard',
      bitrate: 320,
      fileExtension: 'mp3',
    ),
    tagWriteStatus: DownloadTagWriteStatus.pending,
    lyricFormat: DownloadLyricFormat.none,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DownloadTaskStoreDataSource', () {
    test('loadTasks 应在空存储时返回空列表', () async {
      final ds = DownloadTaskStoreDataSource();
      final tasks = await ds.loadTasks();
      expect(tasks, isEmpty);
    });

    test('saveTask + loadTasks 往返应保留完整数据', () async {
      final ds = DownloadTaskStoreDataSource();
      final task = _task('t1');
      await ds.saveTask(task);

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 't1');
      expect(loaded.first.title, 'Song t1');
      expect(loaded.first.status, DownloadTaskStatus.queued);
    });

    test('saveTask 应实现 upsert（相同 id 覆盖）', () async {
      final ds = DownloadTaskStoreDataSource();
      await ds.saveTask(_task('t1'));
      await ds.saveTask(_task('t1', status: DownloadTaskStatus.downloading));

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(1));
      expect(loaded.first.status, DownloadTaskStatus.downloading);
    });

    test('saveTask 多个不同 id 应全部保存', () async {
      final ds = DownloadTaskStoreDataSource();
      await ds.saveTask(_task('t1'));
      await ds.saveTask(_task('t2'));
      await ds.saveTask(_task('t3'));

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(3));
      expect(loaded.map((t) => t.id), ['t1', 't2', 't3']);
    });

    test('deleteTask 应删除指定任务并保留其余', () async {
      final ds = DownloadTaskStoreDataSource();
      await ds.saveTask(_task('t1'));
      await ds.saveTask(_task('t2'));
      await ds.saveTask(_task('t3'));

      await ds.deleteTask('t2');

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(2));
      expect(loaded.map((t) => t.id), ['t1', 't3']);
    });

    test('deleteTask 不存在的 id 应不报错', () async {
      final ds = DownloadTaskStoreDataSource();
      await ds.saveTask(_task('t1'));
      await ds.deleteTask('nonexistent');

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(1));
    });

    test('应正确序列化所有状态枚举', () async {
      final ds = DownloadTaskStoreDataSource();
      final statuses = [
        DownloadTaskStatus.queued,
        DownloadTaskStatus.downloading,
        DownloadTaskStatus.completed,
        DownloadTaskStatus.failed,
        DownloadTaskStatus.paused,
      ];

      for (final status in statuses) {
        await ds.saveTask(_task('s_${status.name}', status: status));
      }

      final loaded = await ds.loadTasks();
      expect(loaded, hasLength(statuses.length));
      for (final task in loaded) {
        final expectedName = task.id.substring(2);
        expect(task.status.name, expectedName);
      }
    });
  });
}
