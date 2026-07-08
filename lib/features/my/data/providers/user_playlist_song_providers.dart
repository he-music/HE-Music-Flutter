import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../datasources/user_playlist_song_api_client.dart';

final userPlaylistSongApiClientProvider = Provider<UserPlaylistSongApiClient>((
  ref,
) {
  final dio = ref.watch(apiDioProvider);
  return UserPlaylistSongApiClient(dio);
});
