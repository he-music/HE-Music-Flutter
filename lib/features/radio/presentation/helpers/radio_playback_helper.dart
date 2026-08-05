import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../data/providers/radio_providers.dart';

Future<void> handleRadioPlayback(WidgetRef ref, RadioInfo radio) async {
  final config = ref.read(appConfigProvider);
  final playerController = ref.read(playerControllerProvider.notifier);
  final playerState = ref.read(playerControllerProvider);
  final repository = ref.read(radioRepositoryProvider);
  final platforms =
      ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
  final radioId = radio.id.trim();
  final radioPlatform = radio.platform.trim();
  if (radioId.isEmpty || radioPlatform.isEmpty) {
    AppMessageService.showError(AppI18n.t(config, 'radio.play_failed'));
    return;
  }
  if (playerState.isRadioMode &&
      playerState.currentRadioId == radioId &&
      playerState.currentRadioPlatform == radioPlatform &&
      playerState.currentRadioPageIndex == 1) {
    try {
      await playerController.togglePlayPause();
    } catch (error) {
      AppMessageService.showError('$error');
    }
    return;
  }
  try {
    final songs = await repository.fetchSongs(
      id: radioId,
      platform: radioPlatform,
      pageIndex: 1,
    );
    if (songs.isEmpty) {
      AppMessageService.showError(AppI18n.t(config, 'radio.song_empty'));
      return;
    }
    final tracks = songs
        .map(
          (song) => _buildTrack(
            song: song,
            baseUrl: config.apiBaseUrl,
            token: config.authToken ?? '',
            platforms: platforms,
          ),
        )
        .toList(growable: false);
    await playerController.replaceQueue(
      tracks,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.radioPlaza,
        queryParameters: <String, String>{'platform': radioPlatform},
        title: radio.name,
      ),
      isRadioMode: true,
      currentRadioId: radioId,
      currentRadioPlatform: radioPlatform,
      currentRadioPageIndex: 1,
    );
  } catch (error) {
    AppMessageService.showError('$error');
  }
}

PlayerTrack _buildTrack({
  required SongInfo song,
  required String baseUrl,
  required String token,
  required List<OnlinePlatform> platforms,
}) {
  final platformId = song.platform.trim();
  final coverUrl = resolveSongCoverUrl(
    baseUrl: baseUrl,
    token: token,
    platforms: platforms,
    platformId: platformId,
    songId: song.id,
    cover: song.cover,
    size: maxCoverSize,
  );
  final localPath = song.path?.trim();
  return PlayerTrack(
    id: song.id,
    title: song.title,
    path: localPath == null || localPath.isEmpty ? null : localPath,
    duration: song.duration > 0 ? Duration(milliseconds: song.duration) : null,
    links: song.links,
    artist: song.artist,
    albumId: song.album?.id,
    album: song.album?.name,
    artists: song.artists,
    mvId: song.mvId,
    artworkUrl: coverUrl.isEmpty ? null : coverUrl,
    platform: platformId,
  );
}
