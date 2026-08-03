import '../../../../shared/models/he_music_models.dart';
import 'playlist_detail_content.dart';
import 'playlist_detail_song.dart';
import 'playlist_detail_songs_page_result.dart';

class PlaylistDetailState {
  const PlaylistDetailState({
    required this.loading,
    required this.songsLoading,
    this.loadingMore = false,
    this.pageIndex = 0,
    this.pageSize = playlistDetailSongsPageSize,
    this.totalCount = 0,
    this.hasMore = false,
    this.info,
    this.songs = const <PlaylistDetailSong>[],
    this.errorMessage,
    this.songsErrorMessage,
    this.loadMoreErrorMessage,
  });

  final bool loading;
  final bool songsLoading;
  final bool loadingMore;
  final int pageIndex;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final PlaylistInfo? info;
  final List<PlaylistDetailSong> songs;
  final String? errorMessage;
  final String? songsErrorMessage;
  final String? loadMoreErrorMessage;

  PlaylistDetailContent? get content {
    final currentInfo = info;
    if (currentInfo == null) {
      return null;
    }
    return PlaylistDetailContent(
      info: PlaylistInfo(
        name: currentInfo.name,
        id: currentInfo.id,
        cover: currentInfo.cover,
        creator: currentInfo.creator,
        songCount: currentInfo.songCount,
        playCount: currentInfo.playCount,
        songs: songs,
        platform: currentInfo.platform,
        description: currentInfo.description,
        categories: currentInfo.categories,
        isDefault: currentInfo.isDefault,
      ),
      songs: songs,
    );
  }

  PlaylistDetailState copyWith({
    bool? loading,
    bool? songsLoading,
    bool? loadingMore,
    int? pageIndex,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
    PlaylistInfo? info,
    List<PlaylistDetailSong>? songs,
    String? errorMessage,
    String? songsErrorMessage,
    String? loadMoreErrorMessage,
    bool clearError = false,
    bool clearSongsError = false,
    bool clearLoadMoreError = false,
  }) {
    return PlaylistDetailState(
      loading: loading ?? this.loading,
      songsLoading: songsLoading ?? this.songsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      pageIndex: pageIndex ?? this.pageIndex,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      info: info ?? this.info,
      songs: songs ?? this.songs,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      songsErrorMessage: clearSongsError
          ? null
          : songsErrorMessage ?? this.songsErrorMessage,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : loadMoreErrorMessage ?? this.loadMoreErrorMessage,
    );
  }

  static const initial = PlaylistDetailState(loading: true, songsLoading: true);
}
