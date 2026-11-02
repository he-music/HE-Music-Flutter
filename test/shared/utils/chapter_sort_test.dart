import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/utils/chapter_sort.dart';
import 'package:he_music_flutter/shared/utils/song_sort.dart';

List<String> _sort(List<String> titles, {bool ascending = true}) =>
    sortSongItems(
      titles,
      SongSortPreference(field: SongSortField.chapter, ascending: ascending),
      valuesOf: (title) =>
          SongSortValues(title: title, artist: '', album: '', duration: null),
    );

void main() {
  test('parses Chinese, Arabic, full-width and Roman chapter markers', () {
    for (final entry in {
      '故事 第一季 第十一集': (season: 1, chapter: 11),
      '故事 第两季 第一百零三话': (season: 2, chapter: 103),
      '故事 第２季 第００９章': (season: 2, chapter: 9),
      '故事 第Ⅳ季 第十二節': (season: 4, chapter: 12),
      '故事 第ⅻ部 第二〇二四回': (season: 12, chapter: 2024),
      '故事 第IV季 第一千零二十集': (season: 4, chapter: 1020),
      '故事 S02E12': (season: 2, chapter: 12),
      '故事 s02 e003': (season: 2, chapter: 3),
      '故事 EP12': (season: null, chapter: 12),
      '故事 Episode 10': (season: null, chapter: 10),
      '故事 第0集': (season: null, chapter: 0),
    }.entries) {
      final key = parseChapterTitle(entry.key)!;
      expect(key.group, '故事', reason: entry.key);
      expect(key.season, entry.value.season, reason: entry.key);
      expect(key.chapter, entry.value.chapter, reason: entry.key);
      expect(key.kind, ChapterKind.regular, reason: entry.key);
    }
  });

  test(
    'does not interpret ordinary titles or malformed numbers as chapters',
    () {
      for (final title in [
        'Nova',
        'WASP',
        'SPARK',
        'OVAtion',
        '1984',
        '七里香',
        '十年',
        '前传主题曲',
        '序章曲',
        '番外之歌',
        '故事 第十十集',
        '故事 第百十章',
        '故事 第一二十集',
        '故事 第IIV季',
      ]) {
        expect(parseChapterTitle(title), isNull, reason: title);
      }
    },
  );

  test('groups works before comparing season and chapter numbers', () {
    final source = [
      '作品10 第1集',
      '作品2 第十集',
      '作品2 第二集',
      '作品2 第二季 第1集',
      '作品2 第一季 第2集',
    ];
    expect(_sort(source), [
      '作品2 第一季 第2集',
      '作品2 第二季 第1集',
      '作品2 第二集',
      '作品2 第十集',
      '作品10 第1集',
    ]);
  });

  test('sorts mixed numeral formats and upper middle lower parts', () {
    expect(
      _sort([
        '【故事】第十二集',
        '故事 - 第十集（下）',
        '故事 第２集',
        '故事 第十集（中）',
        '故事 第十集（上）',
        '故事 第十一集',
      ]),
      [
        '故事 第２集',
        '故事 第十集（上）',
        '故事 第十集（中）',
        '故事 - 第十集（下）',
        '故事 第十一集',
        '【故事】第十二集',
      ],
    );
  });

  test('orders headings, prologue, numbered content, finale then specials', () {
    final source = [
      '故事 第一季 番外',
      '故事 第一季 大结局',
      '故事 第一季 第10001集',
      '故事 第一季 第2集',
      '故事 第一季 序章',
      '故事 第一季',
      '故事 第一季 OVA',
      '故事 第一季 SP',
    ];
    final expected = [
      source[5],
      source[4],
      source[3],
      source[2],
      source[1],
      source[0],
      source[6],
      source[7],
    ];
    expect(_sort(source), expected);
    // Equal special keys keep their source order even in descending order.
    expect(_sort(source, ascending: false), [
      source[0],
      source[6],
      source[7],
      source[1],
      source[2],
      source[3],
      source[4],
      source[5],
    ]);
  });

  test('numbered finales use their number and numbered extras stay extras', () {
    expect(
      _sort(['故事 第2集 番外', '故事 第12集 大结局', '故事 第11集', '故事 第1集 番外', '故事 第13集']),
      ['故事 第11集', '故事 第12集 大结局', '故事 第13集', '故事 第1集 番外', '故事 第2集 番外'],
    );
  });

  test('final-season markers have a category beyond any numbered season', () {
    for (final marker in ['最终季', '最后一季', '末季', '完结季']) {
      expect(_sort(['故事 $marker 第1集', '故事 第10000季 第1集', '故事 第一季 第1集']), [
        '故事 第一季 第1集',
        '故事 第10000季 第1集',
        '故事 $marker 第1集',
      ]);
    }
  });

  test('infers a missing season only for one unambiguous numbered season', () {
    expect(_sort(['故事 大结局', '故事 第二季 第2集', '故事 第1集']), [
      '故事 第1集',
      '故事 第二季 第2集',
      '故事 大结局',
    ]);
    expect(_sort(['故事 第1集', '故事 最终季 第2集', '故事 第一季 第3集']), [
      '故事 第一季 第3集',
      '故事 最终季 第2集',
      '故事 第1集',
    ]);
    // Season context from another work never leaks into this work.
    expect(_sort(['乙剧 第1集', '甲剧 第二季 第2集', '甲剧 大结局']), [
      '甲剧 第二季 第2集',
      '甲剧 大结局',
      '乙剧 第1集',
    ]);
  });

  test('unknown titles stay last and ties retain original order both ways', () {
    final source = [
      '普通歌曲乙',
      '故事 第2集 版本B',
      'Nova',
      '故事 第1集',
      '故事 第2集 版本A',
      '普通歌曲甲',
    ];
    final original = List.of(source);
    expect(_sort(source), [
      source[3],
      source[1],
      source[4],
      source[0],
      source[2],
      source[5],
    ]);
    expect(_sort(source, ascending: false), [
      source[1],
      source[4],
      source[3],
      source[0],
      source[2],
      source[5],
    ]);
    expect(source, original);
    expect(() => _sort(source).add('新内容'), throwsUnsupportedError);
  });

  test(
    'mixed works and unknown titles have consistent order for every triple',
    () {
      final source = [
        '阿剧 第十集',
        '中剧 第二集',
        '北京',
        '故事 第一季 第2集',
        '故事 第二季 第1集',
        '故事 第7集',
        '故事 最终季 第1集',
      ];
      // Permutations of a triple share the same season context and must produce
      // the same order, including the mixed-comparator cycle from the userscript.
      for (final ascending in [true, false]) {
        for (var a = 0; a < source.length; a++) {
          for (var b = 0; b < source.length; b++) {
            for (var c = 0; c < source.length; c++) {
              if (a == b || a == c || b == c) continue;
              final triple = [source[a], source[b], source[c]];
              expect(
                _sort(triple, ascending: ascending),
                _sort(
                  source.where(triple.contains).toList(),
                  ascending: ascending,
                ),
                reason: 'ascending=$ascending: $triple',
              );
            }
          }
        }
      }
    },
  );

  test('preparing chapter keys reads every item title only once', () {
    var calls = 0;
    final sorted = sortSongItems(
      ['第12集', '第2集', '第1集'],
      const SongSortPreference(field: SongSortField.chapter),
      valuesOf: (title) {
        calls++;
        return SongSortValues(
          title: title,
          artist: '',
          album: '',
          duration: null,
        );
      },
    );
    expect(sorted, ['第1集', '第2集', '第12集']);
    expect(calls, 3);
  });
}
