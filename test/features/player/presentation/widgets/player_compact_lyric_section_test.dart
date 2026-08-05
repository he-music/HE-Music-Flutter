import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_compact_lyric_section.dart';

final _testPositionProvider =
    NotifierProvider<_TestPositionController, Duration>(
      _TestPositionController.new,
    );

void main() {
  testWidgets('position updates within one line do not rebuild compact lyric', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    final initialTapTarget = tester.widget<InkWell>(
      find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerCompactLyricSection)),
    );

    container
        .read(_testPositionProvider.notifier)
        .update(const Duration(seconds: 1));
    await tester.pump();

    expect(
      tester.widget<InkWell>(
        find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
      ),
      same(initialTapTarget),
    );
    expect(find.text('第一句'), findsOneWidget);
  });

  testWidgets('crossing a lyric boundary rebuilds compact lyric text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    final initialTapTarget = tester.widget<InkWell>(
      find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerCompactLyricSection)),
    );

    container
        .read(_testPositionProvider.notifier)
        .update(const Duration(seconds: 2));
    await tester.pump();

    expect(
      tester.widget<InkWell>(
        find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
      ),
      isNot(same(initialTapTarget)),
    );
    expect(find.text('第二句'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      currentLyricDocumentProvider.overrideWithValue(
        const AsyncData<LyricDocument>(
          LyricDocument(
            lines: <LyricLine>[
              LyricLine(start: Duration.zero, text: '第一句'),
              LyricLine(start: Duration(seconds: 2), text: '第二句'),
            ],
          ),
        ),
      ),
      lyricPositionProvider.overrideWith(
        (ref) => ref.watch(_testPositionProvider),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: PlayerCompactLyricSection(onTap: _noop)),
    ),
  );
}

void _noop() {}

class _TestPositionController extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  void update(Duration position) {
    state = position;
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'song-1', title: '测试歌曲', artist: '测试歌手'),
    ]);
  }
}
