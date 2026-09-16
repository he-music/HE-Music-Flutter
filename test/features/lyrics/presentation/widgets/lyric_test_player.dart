import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';

class EmptyLyricTestPlayer extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);
}
