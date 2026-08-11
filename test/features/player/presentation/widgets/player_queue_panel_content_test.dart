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

void main() {
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

  testWidgets('position and duration do not rebuild queue panel content', (
    tester,
  ) async {
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
  });

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

  testWidgets('queue tabs switch with horizontal swipes', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        controllerFactory: _QueueWithHistoryTestController.new,
      ),
    );
    await tester.pump();

    expect(find.text('Current Song').hitTestable(), findsOneWidget);
    expect(find.text('Previous Song').hitTestable(), findsNothing);

    await tester.fling(find.byType(TabBarView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Previous Song').hitTestable(), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 1);

    await tester.fling(find.byType(TabBarView), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Current Song').hitTestable(), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 0);
  });

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
  required ThemeData theme,
  required PlayerController Function() controllerFactory,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(controllerFactory),
    ],
    child: MaterialApp(
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
