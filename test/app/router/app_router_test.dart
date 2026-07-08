import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/playlist/data/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('content route keeps mini player visible', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.online),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(find.text('路由测试歌曲'), findsOneWidget);
  });

  testWidgets('settings route covers mini player', (tester) async {
    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: AppRoutes.settings),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayerBar), findsNothing);
    expect(find.text('路由测试歌曲'), findsNothing);
  });

  testWidgets('system back closes playlist detail action sheet before route', (
    tester,
  ) async {
    final initialLocation = Uri(
      path: AppRoutes.playlistDetail,
      queryParameters: const <String, String>{
        'id': 'playlist-1',
        'platform': 'qq',
        'title': '测试歌单',
      },
    ).toString();

    await tester.pumpWidget(
      _buildRouterTestApp(initialLocation: initialLocation),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('路由测试歌单歌曲'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('路由测试歌单歌曲'), findsOneWidget);
  });
}

Widget _buildRouterTestApp({required String initialLocation}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
      playlistDetailRepositoryProvider.overrideWithValue(
        _TestPlaylistDetailRepository(),
      ),
      appRouterProvider.overrideWith((ref) => createAppRouter(initialLocation)),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(routerConfig: router);
      },
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'route-test-song', title: '路由测试歌曲'),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlineController extends OnlineController {
  @override
  OnlineFeatureState build() {
    return OnlineFeatureState.initial;
  }
}

class _TestPlaylistDetailRepository implements PlaylistDetailRepository {
  @override
  Future<PlaylistDetailContent> fetchDetail(
    PlaylistDetailRequest request,
  ) async {
    const song = SongInfo(
      name: '路由测试歌单歌曲',
      subtitle: '测试歌手',
      id: 'song-1',
      duration: 0,
      mvId: '',
      album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
      artists: <SongInfoArtistInfo>[SongInfoArtistInfo(name: '测试歌手', id: 'a1')],
      links: <LinkInfo>[],
      platform: 'qq',
      cover: '',
      sublist: <SongInfo>[],
      originalType: 0,
    );
    return const PlaylistDetailContent(
      info: PlaylistInfo(
        name: '测试歌单',
        id: 'playlist-1',
        cover: '',
        creator: '测试创建者',
        songCount: '1',
        playCount: '0',
        songs: <SongInfo>[song],
        platform: 'qq',
        description: '',
      ),
      songs: <SongInfo>[song],
    );
  }
}
