import 'package:icu_kit/icu_kit.dart' as icu;

// This collator is deliberately separate from the SQLite text collation.
final _compareChapterText = icu.IcuCollator(locale: 'zh-CN-u-kn-true').compare;

const _numeral = r'[0-9零〇一二两三四五六七八九十百千]+|[IVXLCDM]+';
final _season = RegExp('第\\s*($_numeral)\\s*[季部]', caseSensitive: false);
final _chapter = RegExp('第\\s*($_numeral)\\s*[集话話章节節回]', caseSensitive: false);
final _englishSeason = RegExp(
  r'\bS([0-9]+)(?:\s*E([0-9]+))?\b',
  caseSensitive: false,
);
final _englishChapter = RegExp(
  r'\b(?:EP?|Episode)\s*([0-9]+)\b',
  caseSensitive: false,
);
final _finalSeason = RegExp(r'(?:第\s*)?(?:最终季|最終季|最后一季|最後一季|末季|完结季|完結季)');
const _markerEnd = r'(?=$|[\s:：,，。!！?？()（）\[\]【】_\-]|第)';
final _prologue = RegExp('(前传|前傳|序章|序幕)$_markerEnd');
final _finale = RegExp(
  '(大结局|大結局|最终集|最終集|最终话|最終話|最后一集|最後一集|最后一话|最後一話|完结篇|完結篇|完结话|完結話)$_markerEnd',
);
final _special = RegExp(
  '(特别篇|特別篇|番外)$_markerEnd|\\b(?:OVA|SP)\\b',
  caseSensitive: false,
);
final _groupEdges = RegExp(
  r'^[\s:：,，。()（）\[\]【】《》_\-]+|[\s:：,，。()（）\[\]【】《》_\-]+$',
);
final _part = RegExp(r'^[\s(（\[【:：_\-]*(上|中|下)(?:集|篇|部分)?(?=$|[\s)）\]】:：_\-])');
const _romanGlyphs = {
  'Ⅰ': 'I',
  'Ⅱ': 'II',
  'Ⅲ': 'III',
  'Ⅳ': 'IV',
  'Ⅴ': 'V',
  'Ⅵ': 'VI',
  'Ⅶ': 'VII',
  'Ⅷ': 'VIII',
  'Ⅸ': 'IX',
  'Ⅹ': 'X',
  'Ⅺ': 'XI',
  'Ⅻ': 'XII',
  'ⅰ': 'I',
  'ⅱ': 'II',
  'ⅲ': 'III',
  'ⅳ': 'IV',
  'ⅴ': 'V',
  'ⅵ': 'VI',
  'ⅶ': 'VII',
  'ⅷ': 'VIII',
  'ⅸ': 'IX',
  'ⅹ': 'X',
  'ⅺ': 'XI',
  'ⅻ': 'XII',
};
final _romanPattern = RegExp('[${_romanGlyphs.keys.join()}]');
final _arabicNumber = RegExp(r'^[0-9]+$');
const _chineseDigits = {
  '零': 0,
  '〇': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};
const _chineseUnits = {'十': 10, '百': 100, '千': 1000};
final _validRoman = RegExp(
  r'^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$',
);

/// The position of unnumbered material within one season, in ascending order.
enum ChapterKind { heading, prologue, regular, finale, special }

class ChapterTitle {
  const ChapterTitle._({
    required this.group,
    required this.season,
    required this.isFinalSeason,
    required this.chapter,
    required this.kind,
    required this.part,
  });

  final String group;
  final int? season;
  final bool isFinalSeason;
  final int? chapter;
  final ChapterKind kind;
  final int part;
}

/// Parses only explicit chapter markers; unrelated numbers in song names do not
/// become chapter numbers. Missing seasons are resolved across the list later.
ChapterTitle? parseChapterTitle(String title) {
  final text =
      String.fromCharCodes(
            title.runes.map((rune) {
              if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
              return rune == 0x3000 ? 0x20 : rune;
            }),
          )
          .replaceAllMapped(_romanPattern, (match) => _romanGlyphs[match[0]]!)
          .replaceAll('兩', '两');
  final seasonMatch = _season.firstMatch(text);
  final englishSeason = _englishSeason.firstMatch(text);
  final chapterMatch = _chapter.firstMatch(text);
  final englishChapter = _englishChapter.firstMatch(text);
  final finalSeason = _finalSeason.firstMatch(text);
  final prologue = _prologue.firstMatch(text);
  final finale = _finale.firstMatch(text);
  final special = _special.firstMatch(text);
  final seasonRaw = seasonMatch?[1] ?? englishSeason?[1];
  final chapterRaw =
      chapterMatch?[1] ?? englishSeason?[2] ?? englishChapter?[1];
  final season = seasonRaw == null ? null : _parseNumber(seasonRaw);
  final chapter = chapterRaw == null ? null : _parseNumber(chapterRaw);
  // Reject malformed explicit numbers instead of treating their title as a
  // season heading or allowing a special marker to hide the invalid number.
  if ((seasonRaw != null && season == null) ||
      (chapterRaw != null && chapter == null)) {
    return null;
  }
  final markers = [
    ?seasonMatch,
    ?englishSeason,
    ?chapterMatch,
    ?englishChapter,
    ?finalSeason,
    ?prologue,
    ?finale,
    ?special,
  ];
  if (markers.isEmpty) return null;
  final start = markers
      .map((match) => match.start)
      .reduce((a, b) => a < b ? a : b);
  final partMatch =
      chapterMatch ??
      (englishSeason?[2] != null ? englishSeason : englishChapter);
  final part = partMatch == null
      ? null
      : _part.firstMatch(text.substring(partMatch.end));
  return ChapterTitle._(
    group: text.substring(0, start).replaceAll(_groupEdges, '').toLowerCase(),
    season: season,
    isFinalSeason: season == null && finalSeason != null,
    chapter: chapter,
    kind: special != null
        ? ChapterKind.special
        : prologue != null
        ? ChapterKind.prologue
        : chapter != null
        ? ChapterKind.regular
        : finale != null
        ? ChapterKind.finale
        : ChapterKind.heading,
    part: switch (part?[1]) {
      '上' => 1,
      '中' => 2,
      '下' => 3,
      _ => 0,
    },
  );
}

int? _parseNumber(String raw) {
  if (_arabicNumber.hasMatch(raw)) return int.tryParse(raw);
  final roman = raw.toUpperCase();
  if (_validRoman.hasMatch(roman)) {
    const values = {
      'I': 1,
      'V': 5,
      'X': 10,
      'L': 50,
      'C': 100,
      'D': 500,
      'M': 1000,
    };
    var sum = 0;
    var previous = 0;
    for (final rune in roman.split('').reversed) {
      final value = values[rune]!;
      sum += value < previous ? -value : value;
      previous = value;
    }
    return sum;
  }
  if (!raw.split('').any(_chineseUnits.containsKey)) {
    final digits = raw.split('').map((digit) => _chineseDigits[digit]).toList();
    return digits.any((digit) => digit == null)
        ? null
        : int.tryParse(digits.join());
  }
  var sum = 0;
  int? digit;
  var previousUnit = 10000;
  for (final character in raw.split('')) {
    final value = _chineseDigits[character];
    if (value != null) {
      if (digit != null && digit != 0) return null;
      digit = value;
      continue;
    }
    final unit = _chineseUnits[character];
    if (unit == null || unit >= previousUnit || digit == 0) return null;
    // Only a leading ten may omit its multiplier: 十一, but not 百十.
    if (digit == null && !(unit == 10 && sum == 0)) return null;
    sum += (digit ?? 1) * unit;
    previousUnit = unit;
    digit = null;
  }
  return sum + (digit ?? 0);
}

/// Sorts prepared keys consistently, keeping unknown titles last and all ties in
/// source order in both directions. A season is inferred only when its work has
/// exactly one explicit numbered season and no ambiguous final-season marker.
List<T> sortChapterItems<T>(
  List<T> source, {
  required String Function(T item) titleOf,
  required bool ascending,
}) {
  final entries = [
    for (var index = 0; index < source.length; index++)
      (
        item: source[index],
        index: index,
        key: parseChapterTitle(titleOf(source[index])),
      ),
  ];
  final seasons = <String, Set<int>>{};
  final finalSeasonGroups = <String>{};
  for (final entry in entries) {
    final key = entry.key;
    if (key == null) continue;
    if (key.season != null) (seasons[key.group] ??= {}).add(key.season!);
    if (key.isFinalSeason) finalSeasonGroups.add(key.group);
  }
  final prepared = [
    for (final entry in entries)
      (
        item: entry.item,
        index: entry.index,
        key: entry.key,
        season:
            entry.key?.season ??
            (seasons[entry.key?.group]?.length == 1 &&
                    !finalSeasonGroups.contains(entry.key?.group)
                ? seasons[entry.key?.group]!.single
                : null),
      ),
  ];
  int seasonKind(ChapterTitle key, int? season) {
    if (season != null) return 0;
    if (key.isFinalSeason) return 1;
    return seasons.containsKey(key.group) ||
            finalSeasonGroups.contains(key.group)
        ? 2
        : 0;
  }

  prepared.sort((a, b) {
    final left = a.key;
    final right = b.key;
    if (left == null || right == null) {
      if (left == null && right == null) return a.index.compareTo(b.index);
      return left == null ? 1 : -1;
    }
    var comparison = _compareChapterText(left.group, right.group);
    if (comparison == 0) {
      comparison = seasonKind(
        left,
        a.season,
      ).compareTo(seasonKind(right, b.season));
    }
    if (comparison == 0) comparison = (a.season ?? 0).compareTo(b.season ?? 0);
    if (comparison == 0) {
      comparison = left.kind.index.compareTo(right.kind.index);
    }
    if (comparison == 0) {
      comparison = (left.chapter ?? 0).compareTo(right.chapter ?? 0);
    }
    if (comparison == 0) comparison = left.part.compareTo(right.part);
    if (comparison == 0) return a.index.compareTo(b.index);
    return ascending ? comparison : -comparison;
  });
  return List<T>.unmodifiable(prepared.map((entry) => entry.item));
}
