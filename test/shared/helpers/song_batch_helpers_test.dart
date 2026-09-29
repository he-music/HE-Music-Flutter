import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/helpers/song_batch_helpers.dart';

void main() {
  test(
    'batch selection preserves order, first item and distinct platforms',
    () {
      final first = (id: ' song ', platform: ' qq ', name: 'first');
      final otherPlatform = (id: 'song', platform: 'kuwo', name: 'other');
      final songs = [
        first,
        (id: 'song', platform: 'qq', name: 'duplicate'),
        (id: '', platform: 'qq', name: 'empty id'),
        (id: 'song', platform: ' ', name: 'empty platform'),
        (id: 'unselected', platform: 'qq', name: 'unselected'),
        otherPlatform,
      ];
      final selectedKeys = {
        'qq|song',
        'kuwo|song',
        'qq|',
        '|song',
        'qq|missing',
      };
      final items = collectSelectedSongItems(
        songs,
        selectedKeys,
        songIdOf: (song) => song.id,
        platformOf: (song) => song.platform,
      );
      final ids = collectSelectedSongIdPlatforms(
        songs,
        selectedKeys,
        songIdOf: (song) => song.id,
        platformOf: (song) => song.platform,
      );

      expect(items, [first, otherPlatform]);
      expect(items.first.id, ' song ');
      expect(ids.map((song) => (song.id, song.platform)), [
        ('song', 'qq'),
        ('song', 'kuwo'),
      ]);
    },
  );

  test('each selector is evaluated once per song in input order', () {
    for (final collectIds in [false, true]) {
      final calls = <String>[];
      String songIdOf(int song) {
        calls.add('id:$song');
        return '$song';
      }

      String platformOf(int song) {
        calls.add('platform:$song');
        return 'qq';
      }

      if (collectIds) {
        collectSelectedSongIdPlatforms(
          [1, 2, 1],
          {'qq|1'},
          songIdOf: songIdOf,
          platformOf: platformOf,
        );
      } else {
        collectSelectedSongItems(
          [1, 2, 1],
          {'qq|1'},
          songIdOf: songIdOf,
          platformOf: platformOf,
        );
      }
      expect(calls, [
        'id:1',
        'platform:1',
        'id:2',
        'platform:2',
        'id:1',
        'platform:1',
      ]);
    }
  });
}
