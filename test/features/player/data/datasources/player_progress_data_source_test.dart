import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_progress_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'new song replaces the single resume record and rejects another queue',
    () async {
      const ds = PlayerProgressDataSource();
      const first = PlayerTrack(id: 'one', title: 'One', platform: 'qq');
      const second = PlayerTrack(id: 'two', title: 'Two', platform: 'qq');
      await ds.saveProgress(
        track: first,
        positionMs: 10000,
        queueKey: 'queue:0',
      );
      await ds.saveProgress(
        track: second,
        positionMs: 20000,
        queueKey: 'queue:1',
      );
      await ds.clearProgress(first, queueKey: 'queue:0');
      expect(await ds.readProgress(first, queueKey: 'queue:0'), isNull);
      expect(await ds.readProgress(second, queueKey: 'another:1'), isNull);
      expect(await ds.readProgress(second, queueKey: 'queue:1'), 20000);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'player_resume_v1'});
    },
  );

  test('legacy progress imports only the restored current song', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'player_progress_v1',
      jsonEncode({
        'one|qq': {'position_ms': 12345},
        'two|qq': {'position_ms': 99999},
      }),
    );
    const ds = PlayerProgressDataSource();
    const track = PlayerTrack(id: 'one', title: 'One', platform: 'qq');
    expect(await ds.readProgress(track, queueKey: 'queue:0'), 12345);
    expect(prefs.containsKey('player_progress_v1'), isFalse);
    expect(
      jsonDecode(prefs.getString('player_resume_v1')!)['track_key'],
      'one|qq',
    );
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
