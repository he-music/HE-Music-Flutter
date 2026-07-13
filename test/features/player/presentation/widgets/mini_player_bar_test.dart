import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('mini player hides queue entry in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: _TestRadioMiniPlayerController.new,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });

  testWidgets('mini player shows radio icon in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: _TestRadioMiniPlayerController.new,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.radio_rounded), findsOneWidget);
  });

  testWidgets('mini player previews each target during repeated next swipes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late _TestSwipeMiniPlayerController controller;
    await tester.pumpWidget(
      _buildMiniPlayerTestApp(
        controllerFactory: () {
          controller = _TestSwipeMiniPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('歌曲 A').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 1);
    expect(find.text('歌曲 B').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 2);
    expect(find.text('歌曲 C').hitTestable(), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-900, 0), 1500);
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 3);
    expect(find.text('歌曲 D').hitTestable(), findsOneWidget);
  });
}

Widget _buildMiniPlayerTestApp({
  PlayerController Function()? controllerFactory,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(
        controllerFactory ?? _TestMiniPlayerController.new,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: MiniPlayerBar(onOpenFullPlayer: () {})),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _TestMiniPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/sq.mp3',
          ),
        ],
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestRadioMiniPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '电台歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
      ),
    ]).copyWith(
      playMode: PlayerPlayMode.sequence,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TestSwipeMiniPlayerController extends PlayerController {
  int nextCalls = 0;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-a', title: '歌曲 A', artist: '测试歌手'),
      PlayerTrack(id: 'song-b', title: '歌曲 B', artist: '测试歌手'),
      PlayerTrack(id: 'song-c', title: '歌曲 C', artist: '测试歌手'),
      PlayerTrack(id: 'song-d', title: '歌曲 D', artist: '测试歌手'),
      PlayerTrack(id: 'song-e', title: '歌曲 E', artist: '测试歌手'),
    ]).copyWith(currentIndex: 0, previousPreviewIndex: 4, nextPreviewIndex: 1);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playNext() async {
    nextCalls += 1;
  }
}
