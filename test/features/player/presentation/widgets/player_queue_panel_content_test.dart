import 'package:flutter/cupertino.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_snapshot.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_panel_content.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_sheet.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_sheet_close_button.dart';

import '../../../../helpers/expect_text_height_fits.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style short queue fits content and long queue stays lazy', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late _QueueTestController controller;
      var dismissed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(() {
              controller = _QueueTestController();
              return controller;
            }),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await showPlayerStyledBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      fitContent: true,
                      heightFactor: 0.88,
                      builder: (_) => const PlayerQueueSheet(),
                    );
                    dismissed = true;
                  },
                  child: const Text('Open queue'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open queue'));
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('player-sheet-surface'));
      final shortHeight = tester.getSize(surface).height;
      expect(shortHeight, lessThan(300));
      expect(find.byType(AppSheetCloseButton).hitTestable(), findsOneWidget);
      final route = ModalRoute.of(
        tester.element(find.byType(PlayerQueueSheet)),
      );
      expect(route, isA<PopupRoute<void>>());
      controller.updateQueue(
        List.generate(
          200,
          (index) => PlayerTrack(
            id: 'long-$index',
            title: 'Long song $index',
            artist: 'Artist',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).height, greaterThan(650));
      expect(tester.getSize(surface).height, lessThanOrEqualTo(844 * 0.88));
      expect(find.text('Long song 199'), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.byType(PlayerQueueSheet))),
        same(route),
      );
      await tester.fling(
        find.byKey(const ValueKey('player-sheet-drag-handle')),
        const Offset(0, 600),
        1800,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerQueueSheet), findsNothing);
      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  for (final style in AppUiStyle.values) {
    testWidgets('$style queue tabs accommodate large labels and counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          theme: ThemeData(extensions: [AppUiTheme(style: style)]),
          controllerFactory: _QueueTestController.new,
          textScale: 3,
        ),
      );
      await tester.pumpAndSettle();
      expectTextHeightFits(
        tester,
        find.byType(
          style == AppUiStyle.cupertino
              ? CupertinoSlidingSegmentedControl<int>
              : TabBar,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('global queue clear requests the city skin role', (tester) async {
    late _QueueTestController controller;
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: () {
          controller = _QueueTestController();
          return controller;
        },
      ),
    );
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.queueClear), findsOneWidget);

    await tester.tap(_findClearButton());
    await tester.pump();
    expect(controller.clearCalls, 1);
  });

  testWidgets('player queue clear keeps the classic fallback', (tester) async {
    final style = AppPlayerSheetStyle.forBrightness(Brightness.dark);
    await tester.pumpWidget(
      _buildTestApp(
        theme: buildAppPlayerSheetTheme(style, Brightness.dark),
        controllerFactory: _QueueTestController.new,
      ),
    );
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.queueClear), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
  });

  testWidgets('queue clear stays disabled for an empty queue', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: _EmptyQueueTestController.new,
      ),
    );
    await tester.pump();

    expect(tester.widget<IconButton>(_findClearButton()).onPressed, isNull);
  });

  testWidgets('queue uses fallback text when artist is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: _MissingArtistQueueTestController.new,
      ),
    );
    await tester.pump();

    expect(find.text('Unknown Artist').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style position and duration do not rebuild queue panel content',
      (tester) async {
        late _QueueTestController controller;
        await tester.pumpWidget(
          _buildTestApp(
            theme: AppTheme.light(citySoundCreatorSkin(), uiStyle: style),
            controllerFactory: () {
              controller = _QueueTestController();
              return controller;
            },
          ),
        );
        await tester.pump();

        final initialTabView = tester.widget<TabBarView>(
          find.byType(TabBarView),
        );
        controller.updatePosition(const Duration(seconds: 1));
        await tester.pump();

        expect(
          tester.widget<TabBarView>(find.byType(TabBarView)),
          same(initialTabView),
        );

        controller.updateDuration(const Duration(minutes: 3));
        await tester.pump();

        expect(
          tester.widget<TabBarView>(find.byType(TabBarView)),
          same(initialTabView),
        );
      },
    );
  }

  testWidgets('queue updates rebuild queue panel content', (tester) async {
    late _QueueTestController controller;
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: () {
          controller = _QueueTestController();
          return controller;
        },
      ),
    );
    await tester.pump();

    final initialTabView = tester.widget<TabBarView>(find.byType(TabBarView));
    controller.updateQueue(const <PlayerTrack>[
      PlayerTrack(id: 'song-1', title: 'Song', artist: 'Artist'),
      PlayerTrack(id: 'song-2', title: 'Song 2', artist: 'Artist 2'),
    ]);
    await tester.pump();

    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)),
      isNot(same(initialTabView)),
    );
    expect(find.text('Song 2'), findsOneWidget);
  });

  for (final style in AppUiStyle.values) {
    testWidgets('$style queue tabs switch with taps and horizontal swipes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.light(citySoundCreatorSkin(), uiStyle: style),
          controllerFactory: _QueueWithHistoryTestController.new,
        ),
      );
      await tester.pump();

      expect(find.text('Current Song').hitTestable(), findsOneWidget);
      expect(find.text('Previous Song').hitTestable(), findsNothing);

      expect(find.text('History').hitTestable(), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Previous Song').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();
      expect(find.text('Current Song').hitTestable(), findsOneWidget);
      await tester.fling(find.byType(TabBarView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Previous Song').hitTestable(), findsOneWidget);
      expect(
        style == AppUiStyle.cupertino
            ? tester
                  .widget<CupertinoSlidingSegmentedControl<int>>(
                    find.byType(CupertinoSlidingSegmentedControl<int>),
                  )
                  .groupValue
            : tester.widget<TabBar>(find.byType(TabBar)).controller?.index,
        1,
      );

      await tester.fling(find.byType(TabBarView), const Offset(600, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Current Song').hitTestable(), findsOneWidget);
      expect(
        style == AppUiStyle.cupertino
            ? tester
                  .widget<CupertinoSlidingSegmentedControl<int>>(
                    find.byType(CupertinoSlidingSegmentedControl<int>),
                  )
                  .groupValue
            : tester.widget<TabBar>(find.byType(TabBar)).controller?.index,
        0,
      );
    });
  }

  testWidgets('long queue opens around the current track', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: _LongQueueTestController.new,
      ),
    );
    await tester.pump();

    final currentTrack = find.text('Song 41');
    expect(currentTrack, findsOneWidget);
    expect(currentTrack.hitTestable(), findsOneWidget);
    expect(find.text('Song 1'), findsNothing);
  });
}

Widget _buildTestApp({
  double textScale = 1,
  required ThemeData theme,
  required PlayerController Function() controllerFactory,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(controllerFactory),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      theme: theme,
      home: const Scaffold(body: PlayerQueuePanelContent()),
    ),
  );
}

Finder _findSkinIcon(AppSkinIconRole role) {
  return find.byWidgetPredicate(
    (widget) => widget is AppSkinIcon && widget.role == role,
  );
}

Finder _findClearButton() {
  return find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Clear Queue',
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}

class _QueueTestController extends PlayerController {
  int clearCalls = 0;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-1', title: 'Song', artist: 'Artist'),
    ]);
  }

  @override
  Future<void> clearQueue() async {
    clearCalls += 1;
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void updateDuration(Duration duration) {
    final track = state.currentTrack!;
    state = state.copyWith(
      duration: duration,
      queue: <PlayerTrack>[track.copyWith(duration: duration)],
    );
  }

  void updateQueue(List<PlayerTrack> queue) {
    state = state.copyWith(queue: queue);
  }
}

class _EmptyQueueTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _MissingArtistQueueTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-without-artist', title: 'Song Without Artist'),
    ]);
  }
}

class _QueueWithHistoryTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'current-song',
        title: 'Current Song',
        artist: 'Current Artist',
      ),
    ]).copyWith(
      previousQueueSnapshot: const PlayerQueueSnapshot(
        queue: <PlayerTrack>[
          PlayerTrack(
            id: 'previous-song',
            title: 'Previous Song',
            artist: 'Previous Artist',
          ),
        ],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      ),
    );
  }
}

class _LongQueueTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    final queue = List<PlayerTrack>.generate(
      60,
      (index) => PlayerTrack(
        id: 'song-$index',
        title: 'Song ${index + 1}',
        artist: 'Artist ${index + 1}',
      ),
    );
    return PlayerPlaybackState.initial(queue).copyWith(currentIndex: 40);
  }
}
