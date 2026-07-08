import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/player_playback_state.dart';
import '../controllers/player_controller.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlaybackState>(
      PlayerController.new,
    );
