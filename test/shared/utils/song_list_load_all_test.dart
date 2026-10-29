import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/utils/song_list_load_all.dart';

void main() {
  test('loads remaining pages sequentially until hasMore=false', () async {
    final runner = SongListLoadAllRunner();
    var page = 1;
    final requests = <int>[];
    var concurrent = 0;
    await runner.loadAll(
      key: 'a',
      isCurrent: () => true,
      readProgress: () => _progress(page: page, hasMore: page < 4),
      loadMore: () async {
        expect(++concurrent, 1);
        requests.add(page + 1);
        await Future<void>.delayed(Duration.zero);
        page++;
        concurrent--;
      },
      onNoProgress: () => fail('pages made progress'),
    );
    expect(requests, [2, 3, 4]);
  });

  test('stops on failure and a retry resumes from the failed page', () async {
    final runner = SongListLoadAllRunner();
    var page = 1;
    String? error;
    var failNext = true;
    final requests = <int>[];
    Future<void> run() => runner.loadAll(
      key: 'a',
      isCurrent: () => true,
      readProgress: () =>
          _progress(page: page, error: error, hasMore: page < 3),
      loadMore: () async {
        requests.add(page + 1);
        error = null;
        if (failNext) {
          failNext = false;
          error = 'failed';
        } else {
          page++;
        }
      },
      onNoProgress: () => fail('an API failure has its own error state'),
    );
    await run();
    expect(requests, [2]);
    await run();
    expect(requests, [2, 2, 3]);
  });

  for (final cancel in [false, true]) {
    test(
      'stops after the current request when generation changes or page closes ($cancel)',
      () async {
        final runner = SongListLoadAllRunner();
        final pending = Completer<void>();
        var current = true;
        var requests = 0;
        final result = runner.loadAll(
          key: 1,
          isCurrent: () => current,
          readProgress: () => _progress(),
          loadMore: () async {
            requests++;
            await pending.future;
          },
          onNoProgress: () =>
              fail('invalidated operations must not update errors'),
        );
        if (cancel) {
          runner.cancel();
        } else {
          current = false;
        }
        pending.complete();
        await result;
        expect(requests, 1);
      },
    );
  }

  test('duplicate clicks share the running operation', () async {
    final runner = SongListLoadAllRunner();
    final pending = Completer<void>();
    var more = true;
    var requests = 0;
    Future<void> run() => runner.loadAll(
      key: 'a',
      isCurrent: () => true,
      readProgress: () => _progress(hasMore: more),
      loadMore: () async {
        requests++;
        await pending.future;
        more = false;
      },
      onNoProgress: () => fail('completed page'),
    );
    final first = run();
    final second = run();
    expect(second, same(first));
    pending.complete();
    await first;
    expect(requests, 1);
  });

  test('stops a cursor that never advances instead of spinning', () async {
    var requests = 0;
    var errors = 0;
    await SongListLoadAllRunner().loadAll(
      key: 'a',
      isCurrent: () => true,
      readProgress: () => _progress(),
      loadMore: () async {
        requests++;
      },
      onNoProgress: () => errors++,
    );
    expect(requests, 1);
    expect(errors, 1);
  });

  test(
    'bounds duplicate-only pages even when page numbers keep advancing',
    () async {
      var page = 1;
      var errors = 0;
      await SongListLoadAllRunner().loadAll(
        key: 'a',
        isCurrent: () => true,
        readProgress: () => _progress(page: page, count: 1000),
        loadMore: () async {
          page++;
        },
        onNoProgress: () => errors++,
      );
      expect(page, 4);
      expect(errors, 1);
    },
  );
}

SongListPageProgress _progress({
  int page = 1,
  int? count,
  bool hasMore = true,
  String? error,
}) => SongListPageProgress(
  pageIndex: page,
  loadedCount: count ?? page * 1000,
  hasMore: hasMore,
  loadingMore: false,
  error: error,
);
