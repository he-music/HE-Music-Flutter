import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/album/presentation/providers/album_detail_providers.dart';
import 'package:he_music_flutter/features/artist/presentation/providers/artist_detail_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/user_playlist_detail_providers.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:he_music_flutter/features/song/presentation/providers/song_detail_providers.dart';

void main() {
  test('detail providers isolate route keys and dispose route state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _expectRouteScoped(
      container,
      first: playlistDetailControllerProvider('qq|playlist-a'),
      second: playlistDetailControllerProvider('qq|playlist-b'),
      isLoading: (state) => state.loading,
    );
    await _expectRouteScoped(
      container,
      first: albumDetailControllerProvider('qq|album-a'),
      second: albumDetailControllerProvider('qq|album-b'),
      isLoading: (state) => state.loading,
    );
    await _expectRouteScoped(
      container,
      first: artistDetailControllerProvider('qq|artist-a'),
      second: artistDetailControllerProvider('qq|artist-b'),
      isLoading: (state) => state.loading,
    );
    await _expectRouteScoped(
      container,
      first: songDetailControllerProvider('qq::song-a'),
      second: songDetailControllerProvider('qq::song-b'),
      isLoading: (state) => state.loading,
    );
    await _expectRouteScoped(
      container,
      first: rankingDetailControllerProvider('qq|ranking-a'),
      second: rankingDetailControllerProvider('qq|ranking-b'),
      isLoading: (state) => state.loading,
    );
    await _expectRouteScoped(
      container,
      first: userPlaylistDetailControllerProvider('playlist-a'),
      second: userPlaylistDetailControllerProvider('playlist-b'),
      isLoading: (state) => state.loading,
    );
  });
}

Future<void> _expectRouteScoped<ControllerT extends Notifier<StateT>, StateT>(
  ProviderContainer container, {
  required NotifierProvider<ControllerT, StateT> first,
  required NotifierProvider<ControllerT, StateT> second,
  required bool Function(StateT state) isLoading,
}) async {
  final firstSubscription = container.listen(first, (_, _) {});
  final secondSubscription = container.listen(second, (_, _) {});
  final firstController = container.read(first.notifier);
  final secondController = container.read(second.notifier);

  expect(isLoading(container.read(first)), isTrue);
  expect(isLoading(container.read(second)), isTrue);
  expect(firstController, isNot(same(secondController)));

  firstSubscription.close();
  await container.pump();

  final reopenedSubscription = container.listen(first, (_, _) {});
  final reopenedController = container.read(first.notifier);
  expect(reopenedController, isNot(same(firstController)));

  reopenedSubscription.close();
  secondSubscription.close();
  await container.pump();
}
