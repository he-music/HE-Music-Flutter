import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/radio/presentation/controllers/radio_plaza_controller.dart';
import 'package:he_music_flutter/features/radio/presentation/pages/radio_plaza_page.dart';
import 'package:he_music_flutter/features/radio/presentation/providers/radio_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets('电台广场首次加载应显示平台、分组和内容骨架', (tester) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlinePlatformsProvider.overrideWith(
            () => _TestOnlinePlatformsController(platformsCompleter.future),
          ),
        ],
        child: const MaterialApp(home: RadioPlazaPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(PlazaPlatformTabsSkeleton), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(PlazaPlatformTabsSkeleton),
        matching: find.byType(SkeletonBox),
      ),
      findsNWidgets(12),
    );
    expect(find.byType(PlazaGridSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platformsCompleter.complete(const <OnlinePlatform>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('播放进度更新不应重建电台网格', (tester) async {
    final playerController = _TestPlayerController();

    await tester.pumpWidget(_buildReadyRadioPlaza(playerController));
    await tester.pump();
    await tester.pump();

    final initialGrid = tester.widget<GridView>(find.byType(GridView));
    playerController.updatePosition(const Duration(seconds: 1));
    await tester.pump();

    expect(tester.widget<GridView>(find.byType(GridView)), same(initialGrid));
  });

  testWidgets('当前电台变化应更新卡片选中态', (tester) async {
    final playerController = _TestPlayerController();

    await tester.pumpWidget(_buildReadyRadioPlaza(playerController));
    await tester.pump();
    await tester.pump();

    final initialGrid = tester.widget<GridView>(find.byType(GridView));
    expect(
      tester.widget<MediaGridCard>(find.byType(MediaGridCard).first).selected,
      isFalse,
    );

    playerController.updateRadio(id: 'radio-1', platform: 'qq');
    await tester.pump();

    expect(tester.widget<GridView>(find.byType(GridView)), same(initialGrid));
    expect(
      tester.widget<MediaGridCard>(find.byType(MediaGridCard).first).selected,
      isTrue,
    );
  });
  testWidgets('radio selection updates only the old and new cards', (
    tester,
  ) async {
    final player = _TestPlayerController();
    await tester.pumpWidget(_buildReadyRadioPlaza(player));
    await tester.pump();
    await tester.pump();
    final grid = tester.widget<GridView>(find.byType(GridView));
    List<MediaGridCard> cards() =>
        tester.widgetList<MediaGridCard>(find.byType(MediaGridCard)).toList();
    final initial = cards();
    expect(initial, hasLength(3));
    player.updateRadio(id: 'radio-1', platform: 'qq');
    await tester.pump();
    final firstSelection = cards();
    expect(firstSelection[0].selected, isTrue);
    expect(firstSelection[1], same(initial[1]));
    expect(firstSelection[2], same(initial[2]));
    player.updateRadio(id: 'radio-2', platform: 'qq');
    await tester.pump();
    final secondSelection = cards();
    expect(secondSelection[0].selected, isFalse);
    expect(secondSelection[1].selected, isTrue);
    expect(secondSelection[2], same(initial[2]));
    expect(tester.widget<GridView>(find.byType(GridView)), same(grid));
  });

  testWidgets(
    'brightness changes preserve the radio grid and locale still updates',
    (tester) async {
      await tester.pumpWidget(_buildReadyRadioPlaza(_TestPlayerController()));
      await tester.pump();
      await tester.pump();
      final grid = tester.widget<GridView>(find.byType(GridView));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RadioPlazaPage)),
      );
      final config =
          container.read(appConfigProvider.notifier)
              as _TestAppConfigController;
      for (var index = 0; index < 10; index++) {
        config.setLyricPhotoBrightness(0.9 - index * 0.01, persist: false);
        await tester.pump();
        expect(tester.widget<GridView>(find.byType(GridView)), same(grid));
      }
      config.updateLocale('en');
      await tester.pump();
      expect(find.text('Radio'), findsOneWidget);
    },
  );
}

Widget _buildReadyRadioPlaza(_TestPlayerController playerController) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(
          Future<List<OnlinePlatform>>.value(<OnlinePlatform>[
            OnlinePlatform(
              id: 'qq',
              name: 'QQ 音乐',
              shortName: 'QQ',
              status: 1,
              featureSupportFlag: PlatformFeatureSupportFlag.listRadios,
            ),
          ]),
        ),
      ),
      radioPlazaControllerProvider.overrideWith(_TestRadioPlazaController.new),
      playerControllerProvider.overrideWith(() => playerController),
    ],
    child: const MaterialApp(home: RadioPlazaPage()),
  );
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController(this.platformsFuture);

  final Future<List<OnlinePlatform>> platformsFuture;

  @override
  Future<List<OnlinePlatform>> build() => platformsFuture;
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
  void updateLocale(String locale) =>
      state = state.copyWith(localeCode: locale);
}

class _TestRadioPlazaController extends RadioPlazaController {
  @override
  RadioPlazaState build() {
    return const RadioPlazaState(
      selectedPlatformId: 'qq',
      selectedGroupName: '推荐',
      loading: false,
      groups: <RadioGroupInfo>[
        RadioGroupInfo(
          name: '推荐',
          platform: 'qq',
          radios: <RadioInfo>[
            RadioInfo(name: '测试电台', id: 'radio-1', cover: '', platform: 'qq'),
            RadioInfo(name: '第二电台', id: 'radio-2', cover: '', platform: 'qq'),
            RadioInfo(name: '第三电台', id: 'radio-3', cover: '', platform: 'qq'),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> initialize(String platformId) async {}
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void updateRadio({required String id, required String platform}) {
    state = state.copyWith(
      isRadioMode: true,
      currentRadioId: id,
      currentRadioPlatform: platform,
    );
  }
}
