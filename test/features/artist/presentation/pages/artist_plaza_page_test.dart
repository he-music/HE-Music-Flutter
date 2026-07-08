import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_plaza_page_result.dart';
import 'package:he_music_flutter/features/artist/presentation/pages/artist_plaza_page.dart';
import 'package:he_music_flutter/features/artist/presentation/providers/artist_plaza_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets(
    'artist plaza shows loading skeleton before first platform load',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            onlinePlatformsProvider.overrideWith(
              _DelayedOnlinePlatformsController.new,
            ),
            artistPlazaApiClientProvider.overrideWithValue(
              _FakeArtistPlazaApiClient(),
            ),
          ],
          child: const MaterialApp(home: ArtistPlazaPage()),
        ),
      );

      expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();

      expect(find.text('QQ'), findsWidgets);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('测试歌手'), findsOneWidget);
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
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.listArtistTabs,
      ),
    ];
  }
}

class _FakeArtistPlazaApiClient extends ArtistPlazaApiClient {
  _FakeArtistPlazaApiClient() : super(Dio());

  @override
  Future<List<FilterInfo>> fetchFilters({required String platform}) async {
    return const <FilterInfo>[
      FilterInfo(
        id: 'region',
        platform: 'qq',
        options: <FilterOptionInfo>[
          FilterOptionInfo(value: 'all', label: '全部'),
        ],
      ),
    ];
  }

  @override
  Future<ArtistPlazaPageResult> fetchArtists({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    return ArtistPlazaPageResult(
      list: <ArtistInfo>[
        ArtistInfo(
          id: 'artist-1',
          name: '测试歌手',
          cover: '',
          platform: platform,
          description: '',
          mvCount: '2',
          songCount: '10',
          albumCount: '3',
          alias: '',
        ),
      ],
      hasMore: false,
    );
  }
}
