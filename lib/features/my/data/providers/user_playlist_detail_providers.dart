import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../datasources/user_playlist_detail_api_client.dart';
import '../repositories/user_playlist_detail_repository_impl.dart';
import 'user_playlist_song_providers.dart';

final userPlaylistDetailApiClientProvider =
    Provider<UserPlaylistDetailApiClient>((ref) {
      final dio = ref.watch(apiDioProvider);
      return UserPlaylistDetailApiClient(dio);
    });

final userPlaylistDetailRepositoryProvider =
    Provider<UserPlaylistDetailRepository>((ref) {
      final apiClient = ref.watch(userPlaylistDetailApiClientProvider);
      final songApiClient = ref.watch(userPlaylistSongApiClientProvider);
      return UserPlaylistDetailRepositoryImpl(apiClient, songApiClient);
    });
