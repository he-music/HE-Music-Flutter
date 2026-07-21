import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'late result from another playlist cannot replace current state',
    () async {
      final repository = _ControlledPlaylistDetailRepository();
      final container = ProviderContainer(
        overrides: [
          playlistDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      const requestA = PlaylistDetailRequest(
        id: 'playlist-a',
        platform: 'qq',
        title: '歌单 A',
      );
      const requestB = PlaylistDetailRequest(
        id: 'playlist-b',
        platform: 'qq',
        title: '歌单 B',
      );
      final providerA = playlistDetailControllerProvider(requestA.cacheKey);
      final providerB = playlistDetailControllerProvider(requestB.cacheKey);
      final subscriptionA = container.listen(providerA, (_, _) {});
      final subscriptionB = container.listen(providerB, (_, _) {});
      addTearDown(subscriptionA.close);
      addTearDown(subscriptionB.close);

      final loadingA = container.read(providerA.notifier).initialize(requestA);
      final loadingB = container.read(providerB.notifier).initialize(requestB);

      repository.complete(requestB);
      await loadingB;
      expect(container.read(providerB).content?.title, '歌单 B');

      repository.complete(requestA);
      await loadingA;
      expect(container.read(providerA).content?.title, '歌单 A');
      expect(container.read(providerB).content?.title, '歌单 B');
    },
  );
}

class _ControlledPlaylistDetailRepository implements PlaylistDetailRepository {
  final Map<String, Completer<PlaylistDetailContent>> _completers = {};

  @override
  Future<PlaylistDetailContent> fetchDetail(PlaylistDetailRequest request) {
    return (_completers[request.cacheKey] ??=
            Completer<PlaylistDetailContent>())
        .future;
  }

  void complete(PlaylistDetailRequest request) {
    _completers[request.cacheKey]!.complete(_contentFor(request));
  }
}

PlaylistDetailContent _contentFor(PlaylistDetailRequest request) {
  return PlaylistDetailContent(
    info: PlaylistInfo(
      name: request.title,
      id: request.id,
      cover: '',
      creator: '',
      songCount: '0',
      playCount: '0',
      songs: const <SongInfo>[],
      platform: request.platform,
      description: '',
    ),
    songs: const <SongInfo>[],
  );
}
