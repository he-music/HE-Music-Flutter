class FavoriteSongStatusState {
  const FavoriteSongStatusState({required this.songKeys, required this.ready});

  final Set<String> songKeys;
  final bool ready;

  FavoriteSongStatusState copyWith({Set<String>? songKeys, bool? ready}) {
    return FavoriteSongStatusState(
      songKeys: songKeys ?? this.songKeys,
      ready: ready ?? this.ready,
    );
  }

  static const initial = FavoriteSongStatusState(
    songKeys: <String>{},
    ready: false,
  );
}
