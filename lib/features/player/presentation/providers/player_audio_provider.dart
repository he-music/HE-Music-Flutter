import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../core/audio/audio_player_port.dart';
import '../../../../core/audio/audio_handler_player_adapter.dart';
import '../../../../core/audio/he_audio_handler.dart';
import '../../../online/presentation/providers/online_providers.dart';

final audioPlayerPortProvider = Provider<AudioPlayerPort>((ref) {
  final config = ref.watch(appConfigProvider);
  final onlinePlatforms = ref.watch(onlinePlatformsProvider).value;
  final adapter = AudioHandlerPlayerAdapter(globalHeAudioHandler);
  adapter.syncConfig(config);
  if (onlinePlatforms != null) {
    adapter.syncCoverPlatforms(onlinePlatforms);
  }
  return adapter;
});
