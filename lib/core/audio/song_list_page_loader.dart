import 'package:dio/dio.dart';

import '../../features/artist/data/datasources/artist_detail_api_client.dart';
import '../../features/artist/domain/entities/artist_detail_request.dart';
import '../../features/my/data/datasources/user_playlist_detail_api_client.dart';
import '../../features/my/domain/entities/user_playlist_detail_request.dart';
import '../../features/new_release/new_song/data/datasources/new_song_api_client.dart';
import '../../features/playlist/data/datasources/playlist_detail_api_client.dart';
import '../../features/playlist/domain/entities/playlist_detail_request.dart';
import '../../features/ranking/data/datasources/ranking_api_client.dart';
import '../../shared/models/song_list_page.dart';
import '../../shared/models/song_list_pagination.dart';

/// Reuse the same endpoint parsers as the pages, including ranking cursors and
/// mixed-platform songs in user playlists. The audio service owns the lifetime.
Future<SongListPage> loadSongListPage(
  Dio dio,
  SongListPagination cursor,
) async {
  final id = cursor.parameters['id'] ?? '';
  final platform = cursor.parameters['platform'] ?? '';
  switch (cursor.path) {
    case '/v1/playlist/songs':
      final result = await PlaylistDetailApiClient(dio).fetchSongs(
        PlaylistDetailRequest(id: id, platform: platform, title: ''),
        pageIndex: cursor.nextPageIndex,
        pageSize: cursor.pageSize,
      );
      return SongListPage(songs: result.songs, hasMore: result.hasMore);
    case '/v1/user/playlist/songs':
      final result = await UserPlaylistDetailApiClient(dio).fetchSongs(
        UserPlaylistDetailRequest(id: id, title: ''),
        pageIndex: cursor.nextPageIndex,
        pageSize: cursor.pageSize,
      );
      return SongListPage(songs: result.songs, hasMore: result.hasMore);
    case '/v1/ranking':
      final result = await RankingApiClient(dio).fetchRankingDetail(
        id: id,
        platform: platform,
        pageIndex: cursor.nextPageIndex,
        pageSize: cursor.pageSize,
        lastId: cursor.lastId,
      );
      return SongListPage(
        songs: result.songs,
        hasMore: result.hasMore,
        lastId: result.lastId,
      );
    case '/v1/song/tab/news':
      final result = await NewSongApiClient(dio).fetchSongs(
        platform: platform,
        tabId: cursor.parameters['tab_id'] ?? '',
        pageIndex: cursor.nextPageIndex,
        pageSize: cursor.pageSize,
      );
      return SongListPage(songs: result.list, hasMore: result.hasMore);
    case '/v1/artist/songs':
      final result = await ArtistDetailApiClient(dio).fetchSongsPage(
        ArtistDetailRequest(id: id, platform: platform, title: ''),
        pageIndex: cursor.nextPageIndex,
      );
      return SongListPage(songs: result.items, hasMore: result.hasMore);
    default:
      throw ArgumentError.value(cursor.path, 'path', 'Unsupported song list');
  }
}
