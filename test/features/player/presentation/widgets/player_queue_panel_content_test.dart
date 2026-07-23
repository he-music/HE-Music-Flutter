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
}

class _EmptyQueueTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}
