import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/pages/playlist_detail_page.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/id_platform_key.dart';

void main() {
  testWidgets('playlist detail favorite icon uses error color when liked', (
    tester,
  ) async {
    final repository = _FakePlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          playlistDetailRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _LikedPlaylistCollectionStatusController.new,
          ),
        ],
        child: const MaterialApp(
          home: PlaylistDetailPage(
            id: 'playlist-1',
            platform: 'qq',
            title: '测试歌单',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded).first);
    final context = tester.element(find.byType(PlaylistDetailPage));

    expect(icon.color, Theme.of(context).colorScheme.error);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      apiBaseUrl: 'https://example.com',
      authToken: 'token',
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

class _LikedPlaylistCollectionStatusController
    extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState(
      playlistKeys: <String>{
        buildIdPlatformKey(id: 'playlist-1', platform: 'qq'),
      },
      artistKeys: const <String>{},
      albumKeys: const <String>{},
      ready: true,
    );
  }
}

class _FakePlaylistDetailRepository implements PlaylistDetailRepository {
  @override
  Future<PlaylistDetailContent> fetchDetail(
    PlaylistDetailRequest request,
  ) async {
    return PlaylistDetailContent(
      info: PlaylistInfo(
        name: '测试歌单',
        id: request.id,
        cover: 'https://example.com/cover.jpg',
        creator: '测试用户',
        songCount: '1',
        playCount: '10',
        songs: const <SongInfo>[],
        platform: request.platform,
        description: '测试描述',
      ),
      songs: const <SongInfo>[],
    );
  }
}
