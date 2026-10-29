import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/song_sort.dart';

void main() {
  SongSortValues title(String value) =>
      SongSortValues(title: value, artist: value, album: value, duration: 0);

  test('Chinese titles follow zh-CN collation rather than code points', () {
    final original = ['重庆', '北京', '上海', '阿里'];
    final sorted = sortSongItems(
      original,
      const SongSortPreference(field: SongSortField.title),
      valuesOf: title,
    );
    expect(sorted, ['阿里', '北京', '重庆', '上海']);
    expect(original, ['重庆', '北京', '上海', '阿里']);
    expect(
      sortSongItems(original, const SongSortPreference(), valuesOf: title),
      same(original),
    );
  });

  test('equal values retain source order in both directions', () {
    final original = [
      (id: 1, duration: 20),
      (id: 2, duration: 10),
      (id: 3, duration: 20),
    ];
    for (final ascending in [true, false]) {
      final sorted = sortSongItems(
        original,
        SongSortPreference(field: SongSortField.duration, ascending: ascending),
        valuesOf: (item) => SongSortValues(
          title: '',
          artist: '',
          album: '',
          duration: item.duration,
        ),
      );
      expect(sorted.map((item) => item.id), ascending ? [2, 1, 3] : [1, 3, 2]);
    }
  });

  test('text fields use locale order and size uses numeric order', () {
    final original = ['上海', '阿里', '北京'];
    for (final field in [
      SongSortField.title,
      SongSortField.artist,
      SongSortField.album,
    ]) {
      expect(
        sortSongItems(
          original,
          SongSortPreference(field: field, ascending: false),
          valuesOf: title,
        ),
        ['上海', '北京', '阿里'],
      );
    }
    expect(
      sortSongItems<int?>(
        [20, 10, 3],
        const SongSortPreference(field: SongSortField.size),
        valuesOf: (size) => SongSortValues(
          title: '',
          artist: '',
          album: '',
          duration: 0,
          size: size,
        ),
      ),
      [3, 10, 20],
    );
  });
  test('unsupported metadata leaves original order intact', () {
    final source = [20, 10, 3];
    for (final field in [SongSortField.size, SongSortField.duration]) {
      expect(
        sortSongItems(
          source,
          SongSortPreference(field: field),
          valuesOf: (_) => const SongSortValues(
            title: '',
            artist: '',
            album: '',
            duration: null,
          ),
        ),
        same(source),
      );
    }
  });
  test('missing online duration is unknown rather than a zero-length song', () {
    final songs = [
      SongInfo.fromMap({'id': 'known', 'name': 'Known', 'duration': 180}),
      SongInfo.fromMap({'id': 'unknown', 'name': 'Unknown'}),
    ];
    expect(SongSortValues.fromSong(songs.last).duration, isNull);
    expect(
      sortSongItems(
        songs,
        const SongSortPreference(field: SongSortField.duration),
        valuesOf: SongSortValues.fromSong,
      ),
      same(songs),
    );
  });

  test(
    'added timestamps use numeric order and missing timestamps preserve source',
    () {
      final timestamps = [30, 10, 20];
      expect(
        sortSongItems(
          timestamps,
          const SongSortPreference(
            field: SongSortField.createdAt,
            ascending: false,
          ),
          valuesOf: (timestamp) => SongSortValues(
            title: '',
            artist: '',
            album: '',
            duration: 0,
            createdAt: timestamp,
          ),
        ),
        [30, 20, 10],
      );
      expect(
        sortSongItems(
          timestamps,
          const SongSortPreference(field: SongSortField.createdAt),
          valuesOf: (_) => title(''),
        ),
        same(timestamps),
      );
    },
  );
}
