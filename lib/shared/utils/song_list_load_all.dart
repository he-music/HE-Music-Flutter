class SongListPageProgress {
  const SongListPageProgress({
    required this.pageIndex,
    required this.loadedCount,
    required this.hasMore,
    required this.loadingMore,
    this.error,
  });

  final int pageIndex;
  final int loadedCount;
  final bool hasMore;
  final bool loadingMore;
  final String? error;
}

/// Drains a page's existing loadMore method. The owner supplies its local
/// request generation so a refresh or source change stops the old operation.
class SongListLoadAllRunner {
  Future<void>? _pending;
  Object? _key;
  int _operation = 0;

  Future<void> loadAll({
    required Object key,
    required bool Function() isCurrent,
    required SongListPageProgress Function() readProgress,
    required Future<void> Function() loadMore,
    required void Function() onNoProgress,
  }) {
    if (_key == key && _pending != null) return _pending!;
    final operation = ++_operation;
    _key = key;
    late final Future<void> future;
    future =
        _run(
          () => operation == _operation && isCurrent(),
          readProgress,
          loadMore,
          onNoProgress,
        ).whenComplete(() {
          if (identical(_pending, future)) _pending = null;
        });
    _pending = future;
    return future;
  }

  Future<void> _run(
    bool Function() isCurrent,
    SongListPageProgress Function() readProgress,
    Future<void> Function() loadMore,
    void Function() onNoProgress,
  ) async {
    var emptyPages = 0;
    while (isCurrent()) {
      final before = readProgress();
      if (!before.hasMore || before.loadingMore) return;
      await loadMore();
      if (!isCurrent()) return;
      final after = readProgress();
      if (after.error != null || !after.hasMore) return;
      emptyPages = after.loadedCount > before.loadedCount ? 0 : emptyPages + 1;
      if (after.pageIndex <= before.pageIndex || emptyPages >= 3) {
        onNoProgress();
        return;
      }
    }
  }

  void cancel() {
    _operation++;
    _pending = null;
    _key = null;
  }
}
