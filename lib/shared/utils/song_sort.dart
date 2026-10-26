import 'package:icu_kit/icu_kit.dart' as icu;

import '../models/he_music_models.dart';

enum SongSortField { original, title, artist, album, duration, size }

class SongSortPreference {
  const SongSortPreference({
    this.field = SongSortField.original,
    this.ascending = true,
  });

  final SongSortField field;
  final bool ascending;

  @override
  bool operator ==(Object other) =>
      other is SongSortPreference &&
      field == other.field &&
      ascending == other.ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}

class SongSortValues {
  const SongSortValues({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.size,
  });

  factory SongSortValues.fromSong(SongInfo song) => SongSortValues(
    title: song.name,
    artist: song.artists.firstOrNull?.name ?? '',
    album: song.album?.name ?? '',
    duration: song.duration > 0 ? song.duration : null,
    size: song.size,
  );

  final String title;
  final String artist;
  final String album;
  final int? duration;
  final int? size;
}

// Reuse the locale collator; comparisons must not construct native resources.
final _songCollator = icu.IcuCollator(locale: 'zh-CN');

/// Keeps the source list intact and preserves source order for equal values.
List<T> sortSongItems<T>(
  List<T> source,
  SongSortPreference preference, {
  required SongSortValues Function(T item) valuesOf,
}) {
  if (preference.field == SongSortField.original || source.length < 2) {
    return source;
  }
  final entries = [
    for (var index = 0; index < source.length; index++)
      (item: source[index], index: index, values: valuesOf(source[index])),
  ];
  if (preference.field == SongSortField.size &&
      entries.any((entry) => entry.values.size == null)) {
    return source;
  }
  if (preference.field == SongSortField.duration &&
      entries.any((entry) => entry.values.duration == null)) {
    return source;
  }
  entries.sort((a, b) {
    final left = a.values;
    final right = b.values;
    final comparison = switch (preference.field) {
      SongSortField.original => 0,
      SongSortField.title => _songCollator.compare(left.title, right.title),
      SongSortField.artist => _songCollator.compare(left.artist, right.artist),
      SongSortField.album => _songCollator.compare(left.album, right.album),
      SongSortField.duration => (left.duration ?? 0).compareTo(
        right.duration ?? 0,
      ),
      SongSortField.size => (left.size ?? 0).compareTo(right.size ?? 0),
    };
    if (comparison == 0) return a.index.compareTo(b.index);
    return preference.ascending ? comparison : -comparison;
  });
  return List<T>.unmodifiable(entries.map((entry) => entry.item));
}
