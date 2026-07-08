import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/favorite_song_status_state.dart';

class FavoriteSongStatusController extends Notifier<FavoriteSongStatusState> {
  @override
  FavoriteSongStatusState build() {
    ref.listen<String?>(
      appConfigProvider.select((config) => config.authToken),
      (previous, next) {
        final hadToken = (previous?.trim().isNotEmpty ?? false);
        final hasToken = (next?.trim().isNotEmpty ?? false);
        if (hadToken && !hasToken) {
          clear();
        }
      },
    );
    // 已有 token 时自动拉取红心歌曲列表，避免重启后丢失状态
    final currentToken = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (currentToken.isNotEmpty) {
      Future.microtask(() => refresh());
    }

    return FavoriteSongStatusState.initial;
  }

  Future<void> refresh() async {
    final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (token.isEmpty) {
      clear();
      return;
    }
    final items = await ref.read(onlineApiClientProvider).fetchFavoriteSongs();
    replaceAll(items);
  }

  void replaceAll(List<IdPlatformInfo> items) {
    state = state.copyWith(
      songKeys: items
          .map(
            (item) =>
                buildFavoriteSongKey(songId: item.id, platform: item.platform),
          )
          .toSet(),
      ready: true,
    );
  }

  void addSong({required String songId, required String platform}) {
    final next = <String>{...state.songKeys};
    next.add(buildFavoriteSongKey(songId: songId, platform: platform));
    state = state.copyWith(songKeys: next, ready: true);
  }

  void removeSong({required String songId, required String platform}) {
    final next = <String>{...state.songKeys};
    next.remove(buildFavoriteSongKey(songId: songId, platform: platform));
    state = state.copyWith(songKeys: next, ready: true);
  }

  bool contains({required String songId, required String platform}) {
    return state.songKeys.contains(
      buildFavoriteSongKey(songId: songId, platform: platform),
    );
  }

  void clear() {
    state = FavoriteSongStatusState.initial;
  }
}

final favoriteSongStatusProvider =
    NotifierProvider<FavoriteSongStatusController, FavoriteSongStatusState>(
      FavoriteSongStatusController.new,
    );
