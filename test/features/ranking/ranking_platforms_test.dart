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
import 'package:he_music_flutter/features/ranking/presentation/pages/ranking_list_page.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets(
    'ranking page should not treat loading platforms as empty platforms',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            onlinePlatformsProvider.overrideWith(
              _DelayedOnlinePlatformsController.new,
            ),
          ],
          child: const MaterialApp(home: RankingListPage()),
        ),
      );

      expect(find.text('没有可用平台'), findsNothing);
      expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.text('QQ'), findsWidgets);
    },
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}

class _DelayedOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _fakePlatforms;
  }
}

final List<OnlinePlatform> _fakePlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
  ),
];
