import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_info.dart';
import 'package:he_music_flutter/features/sheet_music/domain/repositories/sheet_music_download_repository.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/providers/sheet_music_providers.dart';

void main() {
  const sheet = SheetMusicInfo(
    title: '曲谱',
    pageCount: 99,
    pageUrls: ['page-z', 'page-a', 'page-b'],
  );
  const request = (platform: 'qq', songId: '0001', id: '0002');

  test(
    'download saves only available pages in order and retries failures in the same destination',
    () async {
      final repository = _Repository()..failures.add(1);
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await controller.download(sheet);
      expect(repository.prepareCalls, 1);
      expect(repository.pages, [0, 1, 2]);
      expect(repository.urls, ['page-z', 'page-a', 'page-b']);
      expect(container.read(provider).savedCount, 2);
      expect(container.read(provider).failedPages, [1]);
      expect(container.read(provider).running, false);
      repository.failures.clear();
      await controller.retryFailed();
      expect(repository.prepareCalls, 1);
      expect(repository.pages, [0, 1, 2, 1]);
      expect(repository.destinations.toSet(), hasLength(1));
      expect(container.read(provider).savedCount, 3);
      expect(container.read(provider).failedPages, isEmpty);
      expect(container.read(provider).finished, true);
    },
  );

  test(
    'duplicate presses do not start another task and current-page save keeps original page index',
    () async {
      final pending = Completer<void>();
      final repository = _Repository()..waitForSave = pending.future;
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      final first = controller.download(sheet, pageIndex: 2);
      await Future<void>.delayed(Duration.zero);
      await controller.download(sheet);
      expect(repository.prepareCalls, 1);
      expect(repository.pages, [2]);
      expect(container.read(provider).running, true);
      pending.complete();
      await first;
      expect(container.read(provider).savedCount, 1);
      expect(container.read(provider).total, 1);
    },
  );

  test(
    'cancelled destination selection restores an earlier failed batch without losing successful pages',
    () async {
      final repository = _Repository()..failures.add(1);
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await controller.download(sheet);
      repository.cancelSelection = true;
      await controller.download(sheet, pageIndex: 0);
      expect(repository.pages, [0, 1, 2]);
      expect(container.read(provider).savedCount, 2);
      expect(container.read(provider).failedPages, [1]);
      repository.failures.clear();
      await controller.retryFailed();
      expect(repository.prepareCalls, 2);
      expect(container.read(provider).savedCount, 3);
      expect(repository.pages, [0, 1, 2, 1]);
    },
  );

  test(
    'permission failure starts no image requests and can be retried explicitly',
    () async {
      final repository = _Repository()..permissionError = true;
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await controller.download(sheet);
      expect(repository.pages, isEmpty);
      expect(container.read(provider).error, isA<SheetMusicSaveException>());
      expect(container.read(provider).failedPages, [0, 1, 2]);
      repository.permissionError = false;
      await controller.retryFailed();
      expect(repository.pages, [0, 1, 2]);
      expect(container.read(provider).savedCount, 3);
    },
  );

  test(
    'empty resource and invalid page index never prepare a destination',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await controller.download(const SheetMusicInfo(pageCount: 3));
      await controller.download(sheet, pageIndex: -1);
      await controller.download(sheet, pageIndex: 3);
      expect(repository.prepareCalls, 0);
    },
  );

  test(
    'leaving the page allows an explicitly started batch to finish',
    () async {
      final pending = Completer<void>();
      final repository = _Repository()..waitForSave = pending.future;
      final container = ProviderContainer(
        overrides: [
          sheetMusicDownloadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = sheetMusicDownloadProvider(request);
      final subscription = container.listen(provider, (_, _) {});
      final future = container.read(provider.notifier).download(sheet);
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await container.pump();
      pending.complete();
      await future;
      expect(repository.pages, [0, 1, 2]);
    },
  );
}

class _Destination extends SheetMusicDownloadDestination {
  @override
  String? get directoryPath => '/selected/sheet';
  @override
  Future<void> save(Uint8List bytes, String fileName) async {}
}

class _Repository implements SheetMusicDownloadRepository {
  int prepareCalls = 0;
  final failures = <int>{};
  final pages = <int>[];
  final urls = <String>[];
  final destinations = <SheetMusicDownloadDestination>[];
  bool cancelSelection = false;
  bool permissionError = false;
  Future<void>? waitForSave;

  @override
  Future<SheetMusicDownloadDestination?> prepare(String title) async {
    prepareCalls++;
    if (permissionError) {
      throw const SheetMusicSaveException('sheet_music.permission_denied');
    }
    return cancelSelection ? null : _Destination();
  }

  @override
  Future<void> downloadPage({
    required SheetMusicDownloadDestination destination,
    required String url,
    required String title,
    required int pageIndex,
  }) async {
    pages.add(pageIndex);
    urls.add(url);
    destinations.add(destination);
    await waitForSave;
    if (failures.contains(pageIndex)) throw StateError('Failed page');
  }
}
