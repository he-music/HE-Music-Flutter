import 'download_task.dart';

/// A user-owned download survives removal of its transfer task.
class DownloadedSong {
  const DownloadedSong({required this.task, required this.isAvailable});

  final DownloadTask task;
  final bool isAvailable;

  String get id => task.id;
  String get filePath => task.filePath!;
  bool get hasOnlineIdentity =>
      (task.songId?.trim().isNotEmpty ?? false) &&
      (task.platform?.trim().isNotEmpty ?? false);
}
