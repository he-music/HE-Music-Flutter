import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  group('SearchSongInfo', () {
    test('parses nested song metadata and recursive versions', () {
      final result = SearchSongInfo.fromMap(<String, dynamic>{
        'song': <String, dynamic>{
          'id': 'song-1',
          'name': '主版本',
          'artists': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'artist-1', 'name': '歌手'},
          ],
        },
        'sublist': <Map<String, dynamic>>[
          <String, dynamic>{
            'song': <String, dynamic>{'id': 'song-2', 'name': '现场版'},
            'original_type': 0,
            'lyric_snippet': '现场歌词',
            'lyric': '',
            'matched_keywords': <String>['现场'],
          },
        ],
        'original_type': 1,
        'lyric_snippet': '命中的歌词片段',
        'lyric': '第一行\n第二行',
        'matched_keywords': <String>['歌词', '片段'],
      }, fallbackPlatform: 'qq');

      expect(result.song.id, 'song-1');
      expect(result.song.platform, 'qq');
      expect(result.originalType, 1);
      expect(result.lyricSnippet, '命中的歌词片段');
      expect(result.lyric, '第一行\n第二行');
      expect(result.matchedKeywords, <String>['歌词', '片段']);
      expect(result.sublist.single.song.id, 'song-2');
      expect(result.sublist.single.song.platform, 'qq');
    });

    test('does not accept the removed flat song structure', () {
      expect(
        () => SearchSongInfo.fromMap(<String, dynamic>{
          'id': 'legacy-song',
          'name': '旧结构',
        }),
        throwsFormatException,
      );
    });
  });
}
