import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/helpers/detail_song_action_handler.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/models/song_list_pagination.dart';

void main() {
  testWidgets(
    'each click replaces the queue with the exact displayed extent and latest cursor',
    (tester) async {
      final player = _Player();
      late DetailSongActionHandler actions;
      late BuildContext actionContext;
      var page = 2;
      var hasMore = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerControllerProvider.overrideWith(() => player),
            appConfigProvider.overrideWith(_Config.new),
            onlinePlatformsProvider.overrideWith(_Platforms.new),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                actionContext = context;
                actions = DetailSongActionHandler(
                  ref: ref,
                  queueSource: const PlayerQueueSource(
                    routePath: '/playlist',
                    queryParameters: {'id': 'a'},
                    title: 'A',
                  ),
                  paginationResolver: () => SongListPagination(
                    path: '/v1/playlist/songs',
                    parameters: const {'id': 'a', 'platform': 'qq'},
                    nextPageIndex: page,
                    pageSize: 1000,
                    hasMore: hasMore,
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await actions.playAll(actionContext, _songs(2000));
      await actions.playAll(actionContext, _songs(1000));
      expect(player.state.queue, hasLength(1000));
      expect(player.state.queueSource!.pagination!.nextPageIndex, 2);
      page = 3;
      hasMore = false;
      await actions.playAll(actionContext, _songs(2000), startIndex: 1499);
      expect(player.state.queue, hasLength(2000));
      expect(player.state.currentTrack!.id, '1499');
      expect(player.state.queueSource!.pagination!.nextPageIndex, 3);
      await actions.playAll(actionContext, _songs(900));
      expect(player.state.queue, hasLength(900));
      expect(player.state.queueSource!.pagination!.hasMore, isFalse);
      await actions.playSelectedSongs(
        actionContext,
        songs: _songs(900),
        selectedSongKeys: {'qq|1', 'qq|8'},
        submittingBatch: false,
      );
      expect(player.state.queue.map((track) => track.id), ['1', '8']);
      expect(
        player.state.queueSource!.pagination,
        isNull,
        reason:
            'an explicit selection must never load the rest of its source list',
      );
    },
  );
}

List<SongInfo> _songs(int count) => List.generate(
  count,
  (i) => SongInfo(
    id: '$i',
    name: 'Song $i',
    subtitle: '',
    duration: 180,
    mvId: '',
    album: null,
    artists: const [],
    links: const [],
    platform: 'qq',
    cover: '',
  ),
);

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial([]);

  @override
  Future<void> replaceQueue(
    List<PlayerTrack> queue, {
    int startIndex = 0,
    bool autoplay = true,
    PlayerQueueSource? queueSource,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    state = state.copyWith(
      queue: queue,
      currentIndex: startIndex,
      queueSource: queueSource,
      clearQueueSource: queueSource == null,
    );
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

class _Platforms extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async => [];
}
