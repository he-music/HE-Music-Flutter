import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/player_playback_state.dart';
import '../controllers/player_controller.dart';
import '../helpers/player_lyric_highlight_color_helper.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlaybackState>(
      PlayerController.new,
    );

/// Only artwork changes invalidate extraction; playback progress is unrelated.
final playerAutoLyricHighlightColorProvider = FutureProvider.autoDispose((ref) {
  final artwork = ref.watch(
    playerControllerProvider.select(
      (state) => (
        url: state.currentTrack?.artworkUrl,
        bytes: state.currentTrack?.artworkBytes,
      ),
    ),
  );
  return loadPlayerLyricHighlightColor(
    artworkUrl: artwork.url,
    artworkBytes: artwork.bytes,
  );
});
