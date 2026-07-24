import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_content.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_request.dart';
import 'package:he_music_flutter/features/album/domain/repositories/album_detail_repository.dart';
import 'package:he_music_flutter/features/album/presentation/pages/album_detail_page.dart';
import 'package:he_music_flutter/features/album/presentation/providers/album_detail_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  setUp(_TestPlayerController.reset);

  testWidgets('album detail shows songs from detail payload on first paint', (
    tester,
  ) async {
    final repository = _FakeAlbumDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          albumDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: AlbumDetailPage(id: 'album-1', platform: 'qq', title: '测试专辑'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(find.text('专辑首屏歌曲'), findsOneWidget);
  });

  testWidgets('album detail enters batch mode and toggles loaded songs', (
    tester,
  ) async {
    final repository = _FakeAlbumDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          albumDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: AlbumDetailPage(id: 'album-1', platform: 'qq', title: '测试专辑'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();

    expect(find.text('Batch'), findsOneWidget);

    await tester.tap(find.text('专辑首屏歌曲'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('album detail clears selection when tapping select all twice', (
    tester,
  ) async {
    final repository = _FakeAlbumDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          albumDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: AlbumDetailPage(id: 'album-1', platform: 'qq', title: '测试专辑'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('album detail batch play replaces queue with selected songs', (
    tester,
  ) async {
    final repository = _FakeAlbumDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          albumDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: AlbumDetailPage(id: 'album-1', platform: 'qq', title: '测试专辑'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();
    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(_TestPlayerController.replaceQueueCallCount, 1);
    expect(
      _TestPlayerController.lastReplacedQueue
          .map((track) => track.title)
          .toList(growable: false),
      <String>['专辑首屏歌曲', '专辑第二首'],
    );
  });

  testWidgets('album detail batch add to queue appends selected songs', (
    tester,
  ) async {
    final repository = _FakeAlbumDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          albumDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: AlbumDetailPage(id: 'album-1', platform: 'qq', title: '测试专辑'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();
    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();

    expect(
      _TestPlayerController.appendedTracks
          .map((track) => track.title)
          .toList(growable: false),
      <String>['专辑首屏歌曲', '专辑第二首'],
    );
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _TestPlayerController extends PlayerController {
  static int replaceQueueCallCount = 0;
  static List<PlayerTrack> lastReplacedQueue = <PlayerTrack>[];
  static List<PlayerTrack> appendedTracks = <PlayerTrack>[];

  static void reset() {
    replaceQueueCallCount = 0;
    lastReplacedQueue = <PlayerTrack>[];
    appendedTracks = <PlayerTrack>[];
  }

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

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
    replaceQueueCallCount += 1;
    lastReplacedQueue = List<PlayerTrack>.from(queue);
    state = PlayerPlaybackState.initial(queue);
  }

  @override
  Future<void> appendTrack(PlayerTrack track) async {
    appendedTracks = <PlayerTrack>[...appendedTracks, track];
    state = PlayerPlaybackState.initial(<PlayerTrack>[...state.queue, track]);
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

class _FakeAlbumDetailRepository implements AlbumDetailRepository {
  int fetchDetailCallCount = 0;

  @override
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) async {
    fetchDetailCallCount += 1;
    return AlbumDetailContent(
      info: const AlbumInfo(
        name: '测试专辑',
        id: 'album-1',
        cover: '',
        artists: <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
        ],
        songCount: '1',
        publishTime: '2026-04-01',
        songs: <SongInfo>[],
        description: 'desc',
        platform: 'qq',
        language: '',
        genre: '',
        type: 0,
        isFinished: true,
        playCount: '123',
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '专辑首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
        SongInfo(
          name: '专辑第二首',
          subtitle: '',
          id: 'song-2',
          duration: 200,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
      ],
    );
  }
}
