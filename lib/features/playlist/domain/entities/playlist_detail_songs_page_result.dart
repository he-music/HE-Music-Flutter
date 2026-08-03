import 'playlist_detail_song.dart';

const int playlistDetailSongsPageSize = 1000;

class PlaylistDetailSongsPageResult {
  const PlaylistDetailSongsPageResult({
    required this.songs,
    required this.pageIndex,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  final List<PlaylistDetailSong> songs;
  final int pageIndex;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
}
