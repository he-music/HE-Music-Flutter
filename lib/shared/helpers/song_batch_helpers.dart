import '../models/he_music_models.dart';

String buildSongBatchKey({required String songId, required String platform}) {
  return '${platform.trim()}|${songId.trim()}';
}

Set<String> buildLoadedSongBatchKeys<T>(
  Iterable<T> songs, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  return songs
      .map(
        (song) => buildSongBatchKey(
          songId: songIdOf(song),
          platform: platformOf(song),
        ),
      )
      .toSet();
}

Set<String> sanitizeSelectedSongBatchKeys<T>(
  Set<String> selectedKeys,
  Iterable<T> songs, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  final loadedKeys = buildLoadedSongBatchKeys(
    songs,
    songIdOf: songIdOf,
    platformOf: platformOf,
  );
  return selectedKeys.where(loadedKeys.contains).toSet();
}

bool areAllLoadedSongsSelected<T>(
  Iterable<T> songs,
  Set<String> selectedKeys, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  final loadedKeys = buildLoadedSongBatchKeys(
    songs,
    songIdOf: songIdOf,
    platformOf: platformOf,
  );
  return loadedKeys.isNotEmpty && loadedKeys.every(selectedKeys.contains);
}

List<IdPlatformInfo> collectSelectedSongIdPlatforms<T>(
  Iterable<T> songs,
  Set<String> selectedKeys, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  return _collectSelectedSongs(
    songs,
    selectedKeys,
    songIdOf: songIdOf,
    platformOf: platformOf,
    select: (song, id, platform) => IdPlatformInfo(id: id, platform: platform),
  );
}

List<T> collectSelectedSongItems<T>(
  Iterable<T> songs,
  Set<String> selectedKeys, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  return _collectSelectedSongs(
    songs,
    selectedKeys,
    songIdOf: songIdOf,
    platformOf: platformOf,
    select: (song, id, platform) => song,
  );
}

List<R> _collectSelectedSongs<T, R>(
  Iterable<T> songs,
  Set<String> selectedKeys, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
  required R Function(T song, String id, String platform) select,
}) {
  final seen = <String>{};
  final results = <R>[];
  for (final song in songs) {
    final id = songIdOf(song).trim();
    final platform = platformOf(song).trim();
    if (id.isEmpty || platform.isEmpty) {
      continue;
    }
    final key = buildSongBatchKey(songId: id, platform: platform);
    if (!selectedKeys.contains(key) || !seen.add(key)) {
      continue;
    }
    results.add(select(song, id, platform));
  }
  return results;
}
