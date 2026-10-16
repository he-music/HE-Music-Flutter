class SheetMusicDownloadState {
  const SheetMusicDownloadState({
    this.running = false,
    this.processed = 0,
    this.total = 0,
    this.savedCount = 0,
    this.failedPages = const [],
    this.error,
    this.directoryPath,
  });

  final bool running;
  final int processed;
  final int total;
  final int savedCount;
  final List<int> failedPages;
  final Object? error;
  final String? directoryPath;

  bool get finished => !running && total > 0 && processed == total;
}
