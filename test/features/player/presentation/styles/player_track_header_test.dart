import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/player_track_header.dart';

void main() {
  testWidgets('short artist stays static inside the fixed metadata slot', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHeaderApp(_ShortArtistController.new));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-artist-static')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-artist-marquee')),
      findsNothing,
    );

    final slotRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-artist-slot')),
    );
    final qualityRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-quality-badge')),
    );
    final speedRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-speed-badge')),
    );
    expect(qualityRect.left, greaterThan(slotRect.right));
    expect(speedRect.left, greaterThan(qualityRect.right));

    final title = tester.widget<Text>(
      find.byKey(const ValueKey<String>('player-track-title')),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.text('不应显示的专辑'), findsNothing);
  });

  testWidgets('long artist uses marquee without resizing the slot', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHeaderApp(_LongArtistController.new));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-artist-marquee')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('player-artist-slot'))),
      const Size(100, 20),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('pending header displays target metadata in a fixed slot', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHeaderApp(_PendingHeaderController.new));
    await tester.pump();

    expect(find.text('目标歌曲'), findsOneWidget);
    expect(find.text('目标歌手'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-track-preparing-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('player-track-header'))),
      const Size(300, PlayerTrackHeader.layoutHeight),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('player-track-preparing-slot')),
      ),
      const Size(26, 18),
    );
    expect(
      find.byKey(const ValueKey<String>('player-quality-badge')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-speed-badge')),
      findsOneWidget,
    );
  });
}

Widget _buildHeaderApp(PlayerController Function() controllerFactory) {
  return ProviderScope(
    overrides: [playerControllerProvider.overrideWith(controllerFactory)],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: PlayerTrackHeader(
            noTrackText: 'No track',
            artistSlotWidth: 100,
            onOpenQuality: _noop,
            onOpenSpeed: _noop,
          ),
        ),
      ),
    ),
  );
}

void _noop() {}

abstract class _HeaderController extends PlayerController {
  String get artist;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(<PlayerTrack>[
      PlayerTrack(
        id: 'track-1',
        title: '一首很长但必须省略的歌曲标题',
        artist: artist,
        album: '不应显示的专辑',
      ),
    ]).copyWith(
      speed: 1.25,
      currentAvailableQualities: const <PlayerQualityOption>[
        PlayerQualityOption(
          name: 'SQ',
          quality: 500,
          format: 'flac',
          url: 'https://example.com/song.flac',
        ),
      ],
      currentSelectedQualityName: 'SQ',
    );
  }
}

class _ShortArtistController extends _HeaderController {
  @override
  String get artist => '歌手';
}

class _LongArtistController extends _HeaderController {
  @override
  String get artist => '一位名字非常非常长并且会溢出固定槽位的歌手';
}

class _PendingHeaderController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(id: 'current', title: '当前歌曲', artist: '当前歌手'),
      PlayerTrack(id: 'target', title: '目标歌曲', artist: '目标歌手'),
    ]).copyWith(
      requestedTrackIndex: 1,
      requestedTransitionId: 7,
      currentAvailableQualities: const <PlayerQualityOption>[
        PlayerQualityOption(
          name: 'SQ',
          quality: 500,
          format: 'flac',
          url: 'https://example.com/song.flac',
        ),
      ],
      currentSelectedQualityName: 'SQ',
    );
  }
}
