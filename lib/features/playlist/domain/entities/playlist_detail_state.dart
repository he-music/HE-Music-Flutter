import '../../../../shared/models/he_music_models.dart';
import 'playlist_detail_content.dart';
import 'playlist_detail_song.dart';

class PlaylistDetailState {
  const PlaylistDetailState({
    required this.loading,
    required this.songsLoading,
    this.info,
    this.songs = const <PlaylistDetailSong>[],
    this.errorMessage,
    this.songsErrorMessage,
  });

  final bool loading;
  final bool songsLoading;
  final PlaylistInfo? info;
  final List<PlaylistDetailSong> songs;
  final String? errorMessage;
  final String? songsErrorMessage;

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
    PlaylistInfo? info,
    List<PlaylistDetailSong>? songs,
    String? errorMessage,
    String? songsErrorMessage,
    bool clearError = false,
    bool clearSongsError = false,
  }) {
    return PlaylistDetailState(
      loading: loading ?? this.loading,
      songsLoading: songsLoading ?? this.songsLoading,
      info: info ?? this.info,
      songs: songs ?? this.songs,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      songsErrorMessage: clearSongsError
          ? null
          : songsErrorMessage ?? this.songsErrorMessage,
    );
  }

  static const initial = PlaylistDetailState(loading: true, songsLoading: true);
}
