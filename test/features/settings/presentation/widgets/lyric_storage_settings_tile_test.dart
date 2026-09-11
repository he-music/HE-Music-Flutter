import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/lyric_storage_settings_tile.dart';

void main() {
  late Directory root;
  late LyricStore store;
  const target = LyricRequest(trackId: 'song', platform: 'qq');
  const bundle = RawLyricBundle(lyric: '[00:00.00]original');
  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_config.locale_code': 'zh'});
    root = await Directory.systemTemp.createTemp('lyric-settings-test');
    store = LyricStore(
      manualDirectory: () async => Directory('${root.path}/manual'),
      automaticDirectory: () async => Directory('${root.path}/automatic'),
    );
    await store.saveManual(
      target,
      bundle,
      sourcePlatform: 'kg',
      sourceId: 'candidate',
      title: 'Song',
      artist: '',
      token: store.beginSelection(target),
    );
    await store.saveAutomatic(target, bundle, 0);
  });
  tearDown(() async => root.delete(recursive: true));

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<T> runStore<T>(
    WidgetTester tester,
    Future<T> Function() action,
  ) async {
    late Future<T> result;
    await tester.runAsync(() async {
      result = action();
    });
    // Store notifications queue UI statistics in the widget test's fake zone.
    // Keep pumping while the serialized disk operations drain.
    await settleIo(tester);
    return tester.runAsync(() => result).then((value) => value as T);
  }

  testWidgets(
    'manual deletion requires confirmation and automatic clear preserves choices',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [lyricStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  LyricStorageSettingsTile(manual: false),
                  LyricStorageSettingsTile(manual: true),
                ],
              ),
            ),
          ),
        ),
      );
      await settleIo(tester);
      expect(find.textContaining('1 首'), findsOneWidget);
      expect(find.textContaining('50 MiB'), findsOneWidget);
      await tester.tap(find.text('自动歌词缓存'));
      await settleIo(tester);
      var stats = await runStore(tester, store.statistics);
      expect(stats.automaticBytes, 0);
      expect(stats.manualCount, 1);
      await tester.tap(find.text('手动选择歌词'));
      await tester.pumpAndSettle();
      expect(find.text('删除全部手动选择歌词？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await runStore(tester, () => store.hasManual(target)), isTrue);
      await tester.tap(find.text('手动选择歌词'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部删除'));
      await settleIo(tester);
      stats = await runStore(tester, store.statistics);
      expect(stats.manualCount, 0);
      expect(find.textContaining('0 首'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mounted statistics follow external writes, restores and clears without playback reloads',
    (tester) async {
      await runStore(tester, store.clearAutomatic);
      await runStore(tester, store.clearManual);
      final playbackChanges = <String?>[];
      final subscription = store.changes.listen(playbackChanges.add);
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [lyricStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  LyricStorageSettingsTile(manual: false),
                  LyricStorageSettingsTile(manual: true),
                ],
              ),
            ),
          ),
        ),
      );
      await settleIo(tester);
      expect(find.text('0 B / 50 MiB · 清除缓存'), findsOneWidget);
      expect(find.text('0 首 · 0 B · 全部删除'), findsOneWidget);
      await runStore(
        tester,
        () => store.saveAutomatic(target, bundle, store.automaticEpoch),
      );
      await settleIo(tester);
      final stats = (await runStore(tester, store.statistics));
      expect(stats.automaticBytes, greaterThan(0));
      expect(
        find.text(
          '${lyricStorageSizeLabel(stats.automaticBytes)} / 50 MiB · 清除缓存',
        ),
        findsOneWidget,
      );
      expect(playbackChanges, isEmpty);
      await runStore(
        tester,
        () => store.saveManual(
          target,
          bundle,
          sourcePlatform: 'kg',
          sourceId: 'candidate',
          title: 'Song',
          artist: '',
          token: store.beginSelection(target),
        ),
      );
      await settleIo(tester);
      expect(find.textContaining('1 首'), findsOneWidget);
      await runStore(tester, () => store.restoreDefault(target));
      await settleIo(tester);
      expect(find.text('0 首 · 0 B · 全部删除'), findsOneWidget);
      playbackChanges.clear();
      await runStore(tester, store.clearAutomatic);
      await settleIo(tester);
      expect(find.text('0 B / 50 MiB · 清除缓存'), findsOneWidget);
      expect(playbackChanges, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test('small lyric files show nonzero byte usage', () {
    expect(lyricStorageSizeLabel(350), '350 B');
    expect(lyricStorageSizeLabel(2048), '2.0 KiB');
  });
}
