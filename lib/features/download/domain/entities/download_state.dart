import 'download_task.dart';

class DownloadState {
  const DownloadState({
    required this.tasks,
    required this.maxConcurrent,
    required this.isProcessing,
  });

  final List<DownloadTask> tasks;
  final int maxConcurrent;
  final bool isProcessing;

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
    return DownloadState(
      tasks: tasks ?? this.tasks,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  static const initial = DownloadState(
    tasks: <DownloadTask>[],
    maxConcurrent: 3,
    isProcessing: false,
  );
}
