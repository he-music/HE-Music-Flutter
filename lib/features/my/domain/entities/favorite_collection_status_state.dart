class FavoriteCollectionStatusState {
  const FavoriteCollectionStatusState({
    required this.playlistKeys,
    required this.artistKeys,
    required this.albumKeys,
    required this.ready,
  });

  final Set<String> playlistKeys;
  final Set<String> artistKeys;
  final Set<String> albumKeys;
  final bool ready;

  FavoriteCollectionStatusState copyWith({
    Set<String>? playlistKeys,
    Set<String>? artistKeys,
    Set<String>? albumKeys,
    bool? ready,
  }) {
    return FavoriteCollectionStatusState(
      playlistKeys: playlistKeys ?? this.playlistKeys,
      artistKeys: artistKeys ?? this.artistKeys,
      albumKeys: albumKeys ?? this.albumKeys,
      ready: ready ?? this.ready,
    );
  }

  static const initial = FavoriteCollectionStatusState(
    playlistKeys: <String>{},
    artistKeys: <String>{},
    albumKeys: <String>{},
    ready: false,
  );
}
