import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  test(
    'progress preserves extraction future while changed artwork invalidates it',
    () async {
      final container = ProviderContainer(
        overrides: [playerControllerProvider.overrideWith(_Player.new)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        playerAutoLyricHighlightColorProvider,
        (_, next) {},
      );
      addTearDown(subscription.close);
      final first = container.read(
        playerAutoLyricHighlightColorProvider.future,
      );
      expect(await first, isNull);
      container.read(playerControllerProvider.notifier).state = container
          .read(playerControllerProvider)
          .copyWith(position: const Duration(seconds: 12));
      expect(
        container.read(playerAutoLyricHighlightColorProvider.future),
        same(first),
      );
      container
          .read(playerControllerProvider.notifier)
          .state = PlayerPlaybackState.initial([
        const PlayerTrack(
          id: 'next',
          title: 'Next',
          artist: '',
          album: '',
          platform: 'test',
          artworkUrl: '',
        ),
      ]);
      final next = container.read(playerAutoLyricHighlightColorProvider.future);
      expect(next, isNot(same(first)));
      expect(await next, isNull);
    },
  );
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial([
    const PlayerTrack(
      id: 'first',
      title: 'First',
      artist: '',
      album: '',
      platform: 'test',
    ),
  ]);
}
