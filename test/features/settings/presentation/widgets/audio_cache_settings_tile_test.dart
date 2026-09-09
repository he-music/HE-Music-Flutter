import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_provider.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/domain/settings_models.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/audio_cache_settings_tile.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  test('cache size labels match binary targets and available occupancy', () {
    expect(AudioCachePolicy.limits.map(audioCacheSizeLabel), [
      '500 MB',
      '1 GB',
      '2 GB',
      '5 GB',
    ]);
    expect(audioCacheSizeLabel(0), '0 MB');
    expect(audioCacheSizeLabel(1572864), '1.5 MB');
    expect(audioCacheSizeLabel(1610612736), '1.5 GB');
    expect(
      settingsItems
          .where((item) => SettingsItemIds.audioCacheItems.contains(item.id))
          .any((item) => item.kind == SettingsItemKind.navigation),
      isFalse,
    );
  });

  testWidgets(
    'automatic cache health failures stay silent but explicit clear reports a result',
    (tester) async {
      final fixture = await _Fixture.create(tester, locale: 'en');
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList();
      for (final fail in [
        fixture.store.markWriteUnavailable,
        fixture.store.markReadUnavailable,
      ]) {
        fail();
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .toList(),
          labels,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(fixture.store.readHealth, AudioCacheReadHealth.unavailable);
      expect(fixture.store.writeHealth, AudioCacheWriteHealth.unavailable);
      await tester.tap(find.text('Clear Audio Cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(fixture.store.clearCalls, 1);
      expect(find.text('Audio cache cleared'), findsOneWidget);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cache switches preserve disabled cellular preference', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    SwitchListTile tile(String title) => tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile('播放时自动缓存').value, isTrue);
    expect(tile('蜂窝网络自动缓存').value, isFalse);
    await tester.tap(find.text('蜂窝网络自动缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放时自动缓存'));
    await tester.pumpAndSettle();
    expect(tile('蜂窝网络自动缓存').value, isTrue);
    expect(tile('蜂窝网络自动缓存').onChanged, isNull);
    await tester.tap(find.text('蜂窝网络自动缓存'));
    await tester.pumpAndSettle();
    expect(
      fixture.container.read(appConfigProvider).enableCellularAudioCache,
      isTrue,
    );
    await tester.tap(find.text('播放时自动缓存'));
    await tester.pumpAndSettle();
    expect(tile('蜂窝网络自动缓存').onChanged, isNotNull);
    expect(tile('蜂窝网络自动缓存').value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache target sheet offers and persists all four targets', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    for (final target in AudioCachePolicy.limits) {
      await tester.tap(find.text('缓存空间'));
      await tester.pumpAndSettle();
      for (final label in ['500 MB', '1 GB', '2 GB', '5 GB']) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text(audioCacheSizeLabel(target)).last);
      await tester.pumpAndSettle();
      expect(
        fixture.container.read(appConfigProvider).audioCacheLimitBytes,
        target,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(fixture.source.saved.last.audioCacheLimitBytes, target);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel leaves cache intact and confirmed active clear shows zero and feedback',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      addTearDown(fixture.dispose);
      fixture.store.currentSnapshot = const AudioCacheSnapshot(
        publishedBytes: 1572864,
      );
      fixture.store.deferred = true;
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      expect(find.text('可用缓存：1.5 MB'), findsOneWidget);
      await tester.tap(find.text('清除音频缓存'));
      await tester.pumpAndSettle();
      expect(find.text('清除所有音频缓存？已下载的音乐不会删除。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(fixture.store.clearCalls, 0);
      expect(find.text('可用缓存：1.5 MB'), findsOneWidget);
      await tester.tap(find.text('清除音频缓存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(fixture.store.clearCalls, 1);
      expect(find.text('可用缓存：0 MB'), findsOneWidget);
      expect(find.text('音频缓存已清除，当前播放占用的数据将在播放释放后移除。'), findsOneWidget);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear reports ordinary success and explicit operation failure', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester, locale: 'en');
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Audio Cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Audio cache cleared'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    fixture.store.failClear = true;
    await tester.tap(find.text('Clear Audio Cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to clear audio cache. Please retry.'),
      findsOneWidget,
    );
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable capability hides group and search results', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester, supported: false);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    expect(find.text('音频缓存'), findsNothing);
    expect(find.byType(AudioCacheSettingsTile), findsNothing);
    await tester.pumpWidget(fixture.app(child: const SettingsPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '缓存');
    await tester.pumpAndSettle();
    expect(find.text('播放 / 播放时自动缓存'), findsNothing);
    expect(find.text('播放 / 清除音频缓存'), findsNothing);
  });

  testWidgets('cache settings support narrow English layout', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _Fixture.create(tester, locale: 'en');
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    expect(find.text('Cache During Playback'), findsOneWidget);
    expect(find.text('Cache on Cellular'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'playback ticks and cache snapshots do not rebuild cache controls',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      addTearDown(fixture.dispose);
      final counts = <String, int>{};
      final child = Scaffold(
        body: Column(
          children: [
            for (final item in settingsItems.where(
              (item) => SettingsItemIds.audioCacheItems.contains(item.id),
            ))
              _CountingCacheTile(item: item, counts: counts),
            Consumer(
              builder: (context, ref, _) => Text(
                'position:${ref.watch(playerControllerProvider.select((state) => state.position.inMilliseconds))}',
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(fixture.app(child: child));
      await tester.pumpAndSettle();
      final baseline = Map<String, int>.of(counts);
      final player = fixture.container.read(playerControllerProvider.notifier);
      for (var index = 1; index <= 40; index++) {
        player.updateState(
          (state) =>
              state.copyWith(position: Duration(milliseconds: index * 33)),
        );
        await tester.pump();
      }
      expect(find.text('position:1320'), findsOneWidget);
      expect(counts, baseline);
      fixture.store.emit(
        const AudioCacheSnapshot(publishedBytes: 2 * AudioCachePolicy.mebibyte),
      );
      await tester.pumpAndSettle();
      expect(find.text('可用缓存：2 MB'), findsOneWidget);
      expect(counts, baseline);
      fixture.container
          .read(appConfigProvider.notifier)
          .setAutoCheckUpdates(false);
      await tester.pumpAndSettle();
      expect(counts, baseline);
      fixture.store.markWriteUnavailable();
      await tester.pumpAndSettle();
      expect(find.textContaining('失败'), findsNothing);
      expect(counts, baseline);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  _Fixture(this.container, this.source, this.store);
  final ProviderContainer container;
  final RecordingCacheConfigDataSource source;
  final RecordingAudioCacheStore store;

  static Future<_Fixture> create(
    WidgetTester tester, {
    bool supported = true,
    String locale = 'zh',
  }) async {
    final source = RecordingCacheConfigDataSource(
      AppConfigState.initial.copyWith(localeCode: locale),
    );
    final store = RecordingAudioCacheStore();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(source),
        audioCacheRuntimeProvider.overrideWithValue(
          supported
              ? AudioCacheRuntime(store: store, capabilityEnabled: true)
              : null,
        ),
        playerControllerProvider.overrideWith(_TickPlayer.new),
      ],
    );
    await tester.runAsync(
      () => container.read(appConfigProvider.notifier).waitUntilHydrated(),
    );
    return _Fixture(container, source, store);
  }

  Widget app({
    Widget child = const SettingsPage(sectionId: SettingsSectionIds.playback),
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(navigatorKey: rootNavigatorKey, home: child),
  );

  Future<void> dispose() async {
    toastification.dismissAll(delayForAnimation: false);
    container.dispose();
    await store.dispose();
  }
}

class _TickPlayer extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial([]);
}

class _CountingCacheTile extends AudioCacheSettingsTile {
  const _CountingCacheTile({required super.item, required this.counts});
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    counts.update(item.id, (value) => value + 1, ifAbsent: () => 1);
    return super.build(context, ref);
  }
}
