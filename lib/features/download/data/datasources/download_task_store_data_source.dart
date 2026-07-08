import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/download_task.dart';

const _downloadTaskStoreKey = 'download.tasks.v2';

class DownloadTaskStoreDataSource {
  Future<List<DownloadTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_downloadTaskStoreKey) ?? const <String>[];
    return raw
        .map(
          (item) =>
              DownloadTask.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> saveTask(DownloadTask task) async {
    final tasks = await loadTasks();
    final updated = <DownloadTask>[
      for (final current in tasks)
        if (current.id != task.id) current,
      task,
    ];
    await _writeTasks(updated);
  }

  Future<void> deleteTask(String taskId) async {
    final tasks = await loadTasks();
    final updated = tasks
        .where((task) => task.id != taskId)
        .toList(growable: false);
    await _writeTasks(updated);
  }

  Future<void> _writeTasks(List<DownloadTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _downloadTaskStoreKey,
      tasks.map((task) => jsonEncode(task.toJson())).toList(growable: false),
    );
  }
}
