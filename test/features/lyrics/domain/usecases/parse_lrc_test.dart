import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/usecases/parse_lrc.dart';

void main() {
  test('parseLrc should parse normal lrc line', () {
    final result = parseLrc('[00:12.340]不要爱借口');

    expect(result, hasLength(1));
    expect(result.first.start, const Duration(seconds: 12, milliseconds: 340));
    expect(result.first.text, '不要爱借口');
    expect(result.first.tokens, isEmpty);
  });

  test('parseLrc should parse karaoke word timing tokens', () {
    final result = parseLrc(
      '[00:00.058]<0,199>可<199,68>能<267,68> - <335,153>程<488,176>响',
    );

    expect(result, hasLength(1));
    expect(result.first.start, const Duration(milliseconds: 58));
    expect(result.first.text, '可能 - 程响');
    expect(result.first.tokens, hasLength(5));
    expect(result.first.tokens[0].text, '可');
    expect(result.first.tokens[0].startOffset, Duration.zero);
    expect(result.first.tokens[0].duration, const Duration(milliseconds: 199));
    expect(result.first.tokens[2].text, ' - ');
    expect(result.first.tokens[4].endOffset, const Duration(milliseconds: 664));
  });

  test('parseLrc should keep multi timestamp order', () {
    final result = parseLrc('[00:02.000][00:01.000]副歌');

    expect(result, hasLength(2));
    expect(result[0].start, const Duration(seconds: 1));
    expect(result[1].start, const Duration(seconds: 2));
    expect(result[0].text, '副歌');
    expect(result[1].text, '副歌');
  });

  test('parseLyricDocument should align translation and romanization', () {
    final result = parseLyricDocument(
      lyric: '[00:01.00]不要爱借口\n[00:03.00]爱淡了就放手',
      translation: '[00:01.00]do not make excuses\n[00:03.00]let it go',
      romanization:
          '[00:01.00]bu yao ai jie kou\n[00:03.00]ai dan le jiu fang shou',
    );

    expect(result.lines, hasLength(2));
    expect(result.lines.first.translation, 'do not make excuses');
    expect(result.lines.first.romanization, 'bu yao ai jie kou');
    expect(result.lines.first.end, const Duration(seconds: 3));
    expect(result.lines.last.translation, 'let it go');
  });

  test(
    'parseLyricDocument should match word lyric translation by rawTime only',
    () {
      final result = parseLyricDocument(
        lyric:
            '[00:00.058]<0,199>可<199,68>能\n[00:00.892]<0,149>词<149,153>Lyricist：',
        translation:
            '[00:00.892]arttist: ningquan\n[00:00.900]should not match previous line',
      );

      expect(result.lines, hasLength(2));
      expect(result.lines.first.translation, isEmpty);
      expect(result.lines.last.translation, 'arttist: ningquan');
    },
  );

  test('splitLocalLyrics should split main trans and roma sections', () {
    final result = splitLocalLyrics('''
[00:01.00]主歌词

[lang:trans]
[00:01.00]翻译歌词

[lang:roma]
[00:01.00]yin yi ge ci
''');

    expect(result.lyric, contains('[00:01.00]主歌词'));
    expect(result.translation, contains('[00:01.00]翻译歌词'));
    expect(result.romanization, contains('[00:01.00]yin yi ge ci'));
  });

  test(
    'normalizeWordLyricText should keep text and strip word timing tokens',
    () {
      final result = normalizeWordLyricText('[00:01.00]<0,500>夜<500,500>曲');

      expect(result, '[00:01.00]夜曲');
    },
  );

  test(
    'parseTimedLyricEntries should preserve word lyric content after normalization',
    () {
      final result = parseTimedLyricEntries('[00:01.00]<0,500>夜<500,500>曲');

      expect(result, <String>['夜曲']);
    },
  );

  test('parseLyricDocument should preserve lrc offset tag', () {
    final result = parseLyricDocument(
      lyric: '[offset:120]\n[00:01.00]第一句\n[00:02.00]第二句',
    );

    expect(result.offset, 120);
    expect(result.lines, hasLength(2));
    expect(result.lines.first.start, const Duration(seconds: 1));
  });
}
