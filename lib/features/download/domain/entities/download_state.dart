import 'download_task.dart';

class DownloadState {
  const DownloadState({
    required this.tasks,
    required this.maxConcurrent,
    required this.isProcessing,
    this.taskListRevision = 0,
  });

  final List<DownloadTask> tasks;
  final int maxConcurrent;
  final bool isProcessing;
  final int taskListRevision;

  List<DownloadTask> get waitingTasks => tasks
      .where((task) => task.status == DownloadTaskStatus.queued)
      .toList(growable: false);

  List<DownloadTask> get runningTasks => tasks
      .where(
        (task) =>
            task.status == DownloadTaskStatus.preparing ||
            task.status == DownloadTaskStatus.downloading ||
            task.status == DownloadTaskStatus.tagging,
      )
      .toList(growable: false);

  List<DownloadTask> get completedTasks => tasks
      .where((task) => task.status == DownloadTaskStatus.completed)
      .toList(growable: false);

  List<DownloadTask> get failedTasks => tasks
      .where((task) => task.status == DownloadTaskStatus.failed)
      .toList(growable: false);

  List<DownloadTask> get pausedTasks => tasks
      .where((task) => task.status == DownloadTaskStatus.paused)
      .toList(growable: false);

  bool get canStartNewTask => runningTasks.length < maxConcurrent;

  int get waitingCount => waitingTasks.length;

  DownloadState copyWith({
    List<DownloadTask>? tasks,
    int? maxConcurrent,
    bool? isProcessing,
  }) {
    final nextTasks = tasks ?? this.tasks;
    final structureChanged =
        tasks != null && _taskListStructureChanged(this.tasks, nextTasks);
    return DownloadState(
      tasks: nextTasks,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      isProcessing: isProcessing ?? this.isProcessing,
      taskListRevision: structureChanged
          ? taskListRevision + 1
          : taskListRevision,
    );
  }

  static bool _taskListStructureChanged(
    List<DownloadTask> current,
    List<DownloadTask> next,
  ) {
    if (current.length != next.length) {
      return true;
    }
    for (var index = 0; index < current.length; index++) {
      final currentTask = current[index];
      final nextTask = next[index];
      if (currentTask.id != nextTask.id ||
          currentTask.createdAt != nextTask.createdAt ||
          (currentTask.status == DownloadTaskStatus.completed) !=
              (nextTask.status == DownloadTaskStatus.completed)) {
        return true;
      }
    }
    return false;
  }

  static const initial = DownloadState(
    tasks: <DownloadTask>[],
    maxConcurrent: 3,
    isProcessing: false,
    taskListRevision: 0,
  );
}
