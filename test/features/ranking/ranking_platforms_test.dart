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
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_detail.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_group.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_info.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_preview_song.dart';
import 'package:he_music_flutter/features/ranking/domain/repositories/ranking_repository.dart';
import 'package:he_music_flutter/features/ranking/presentation/pages/ranking_list_page.dart';
import 'package:he_music_flutter/features/ranking/presentation/providers/ranking_providers.dart';
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

  testWidgets('ranking row item does not use the card theme background', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _RankingOnlinePlatformsController.new,
          ),
          rankingRepositoryProvider.overrideWithValue(_FakeRankingRepository()),
        ],
        child: MaterialApp(
          theme: ThemeData(cardTheme: const CardThemeData(color: Colors.red)),
          home: const RankingListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试榜单'), findsOneWidget);
    final cardColoredMaterials = tester
        .widgetList<Material>(find.byType(Material))
        .where((material) => material.color == Colors.red);
    expect(cardColoredMaterials, isEmpty);
  });
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

class _RankingOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getTopList,
      ),
    ];
  }
}

class _FakeRankingRepository implements RankingRepository {
  @override
  Future<List<RankingGroup>> fetchRankingGroups({required String platform}) {
    return Future<List<RankingGroup>>.value(<RankingGroup>[
      RankingGroup(
        name: '官方榜',
        rankings: <RankingInfo>[
          RankingInfo(
            id: 'ranking-1',
            platform: platform,
            name: '测试榜单',
            coverUrl: '',
            previewSongs: const <RankingPreviewSong>[
              RankingPreviewSong(name: '测试歌曲', artist: '测试歌手'),
            ],
          ),
        ],
      ),
    ]);
  }

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) {
    throw UnimplementedError();
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
