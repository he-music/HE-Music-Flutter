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
  final seen = <String>{};
  final results = <IdPlatformInfo>[];
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
    results.add(IdPlatformInfo(id: id, platform: platform));
  }
  return results;
}

List<T> collectSelectedSongItems<T>(
  Iterable<T> songs,
  Set<String> selectedKeys, {
  required String Function(T song) songIdOf,
  required String Function(T song) platformOf,
}) {
  final seen = <String>{};
  final results = <T>[];
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
    results.add(song);
  }
  return results;
}
