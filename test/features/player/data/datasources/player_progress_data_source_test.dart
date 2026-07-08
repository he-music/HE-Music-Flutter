import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_progress_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saveProgress should persist latest position', () async {
    const dataSource = PlayerProgressDataSource();
    const track = PlayerTrack(
      id: 'song-1',
      title: 'Song 1',
      url: 'https://example.com/1.mp3',
      platform: 'kuwo',
    );

    await dataSource.saveProgress(track: track, positionMs: 12345);

    expect(await dataSource.readProgress(track), 12345);
  });

  test('clearProgress should remove stored position', () async {
    const dataSource = PlayerProgressDataSource();
    const track = PlayerTrack(
      id: 'song-2',
      title: 'Song 2',
      url: 'https://example.com/2.mp3',
      platform: 'qq',
    );

    await dataSource.saveProgress(track: track, positionMs: 6789);
    await dataSource.clearProgress(track);

    expect(await dataSource.readProgress(track), isNull);
  });
}
