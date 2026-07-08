import '../entities/lyric_document.dart';
import '../entities/lyric_line.dart';

const transSeparator = '[lang:trans]';
const romaSeparator = '[lang:roma]';

final _lrcPattern = RegExp(r'\[(\d{2}):(\d{2})(?:[.:](\d{1,3}))?\]');
final _tokenPattern = RegExp(r'<(\d+),(\d+)>([^<]*)');
final _offsetPattern = RegExp(r'^\[offset:([+-]?\d+)\]$', multiLine: true);
final _linePattern = RegExp(
  r'^(?<timestamps>(?:\[.+?\])+)(?!\[)(?<content>.+)$',
);

class _ParsedLrcEntry {
  const _ParsedLrcEntry({
    required this.rawTime,
    required this.start,
    required this.content,
  });

  final String rawTime;
  final Duration start;
  final String content;
}

class SplitLyricParts {
  const SplitLyricParts({
    required this.lyric,
    required this.translation,
    required this.romanization,
  });

  final String lyric;
  final String translation;
  final String romanization;
}

SplitLyricParts splitLocalLyrics(String text) {
  final transIndex = text.indexOf(transSeparator);
  final romaIndex = text.indexOf(romaSeparator);
  final mainEnd = [
    if (transIndex >= 0) transIndex,
    if (romaIndex >= 0) romaIndex,
  ];
  final lyric = text
      .slice(
        0,
        mainEnd.isEmpty ? text.length : mainEnd.reduce((a, b) => a < b ? a : b),
      )
      .trim();
  var translation = '';
  var romanization = '';
  if (transIndex >= 0) {
    final transEnd = text.indexOf(
      romaSeparator,
      transIndex + transSeparator.length,
    );
    translation = text
        .slice(
          transIndex + transSeparator.length,
          transEnd >= 0 && transEnd > transIndex ? transEnd : text.length,
        )
        .trim();
  }
  if (romaIndex >= 0) {
    final romaEnd = text.indexOf(
      transSeparator,
      romaIndex + romaSeparator.length,
    );
    romanization = text
        .slice(
          romaIndex + romaSeparator.length,
          romaEnd >= 0 && romaEnd > romaIndex ? romaEnd : text.length,
        )
        .trim();
  }
  return SplitLyricParts(
    lyric: lyric,
    translation: translation,
    romanization: romanization,
  );
}

bool isWordLyric(String lyric) => _tokenPattern.hasMatch(lyric);

LyricDocument parseLyricDocument({
  required String lyric,
  String translation = '',
  String romanization = '',
}) {
  final normalizedMain = lyric.trim();
  if (normalizedMain.isEmpty) {
    return const LyricDocument.empty();
  }
  final offset = _parseOffset(normalizedMain);
  return isWordLyric(normalizedMain)
      ? _parseWordLyric(
          lyric: normalizedMain,
          translation: translation,
          romanization: romanization,
          offset: offset,
        )
      : _parseLineLyric(
          lyric: normalizedMain,
          translation: translation,
          romanization: romanization,
          offset: offset,
        );
}

List<LyricLine> parseLrc(String raw) {
  return parseLyricDocument(lyric: raw).lines;
}

bool hasTimedLyricEntries(String raw) {
  return parseTimedLyricEntries(raw).isNotEmpty;
}

List<String> parseTimedLyricEntries(String raw) {
  return _parseEntries(
    raw,
    normalizeWordLyric: true,
  ).map((entry) => entry.content).toList(growable: false);
}

LyricDocument _parseWordLyric({
  required String lyric,
  required String translation,
  required String romanization,
  required int offset,
}) {
  final lyrics = _parseEntries(lyric, normalizeWordLyric: false);
  final translations = _parseEntries(translation, normalizeWordLyric: true);
  final romanizations = _parseEntries(romanization, normalizeWordLyric: true);
  final result = <LyricLine>[];
  for (var index = 0; index < lyrics.length; index++) {
    final item = lyrics[index];
    final tokens = _parseTokens(item.content);
    final text = tokens.isEmpty
        ? item.content.trim()
        : tokens.map((token) => token.text).join();
    if (text.isEmpty) {
      continue;
    }
    final translationText = _findByRawTime(translations, item.rawTime);
    final romanizationText = _findByRawTime(romanizations, item.rawTime);
    final end = tokens.isEmpty
        ? (index < lyrics.length - 1 ? lyrics[index + 1].start : null)
        : item.start + tokens.last.endOffset;
    result.add(
      LyricLine(
        start: item.start,
        end: end,
        text: text,
        tokens: tokens,
        translation: translationText ?? '',
        romanization: romanizationText ?? '',
      ),
    );
  }
  return LyricDocument(lines: result, offset: offset);
}

LyricDocument _parseLineLyric({
  required String lyric,
  required String translation,
  required String romanization,
  required int offset,
}) {
  final lyrics = _parseEntries(lyric, normalizeWordLyric: true);
  final translations = _parseEntries(translation, normalizeWordLyric: true);
  final romanizations = _parseEntries(romanization, normalizeWordLyric: true);
  final result = <LyricLine>[];
  for (var index = 0; index < lyrics.length; index++) {
    final item = lyrics[index];
    final end = index < lyrics.length - 1 ? lyrics[index + 1].start : null;
    final translationText = _findByRawTimeOrStart(
      translations,
      rawTime: item.rawTime,
      start: item.start,
    );
    final romanizationText = _findByRawTimeOrStart(
      romanizations,
      rawTime: item.rawTime,
      start: item.start,
    );
    result.add(
      LyricLine(
        start: item.start,
        end: end,
        text: item.content,
        translation: translationText ?? '',
        romanization: romanizationText ?? '',
      ),
    );
  }
  return LyricDocument(lines: result, offset: offset);
}

int _parseOffset(String raw) {
  final match = _offsetPattern.firstMatch(raw);
  if (match == null) {
    return 0;
  }
  return int.tryParse(match.group(1) ?? '') ?? 0;
}

String? _findByRawTime(List<_ParsedLrcEntry> entries, String rawTime) {
  return entries
      .where((entry) => entry.rawTime == rawTime)
      .map((entry) => entry.content)
      .firstOrNull;
}

String? _findByRawTimeOrStart(
  List<_ParsedLrcEntry> entries, {
  required String rawTime,
  required Duration start,
}) {
  return entries
      .where((entry) => entry.rawTime == rawTime || entry.start == start)
      .map((entry) => entry.content)
      .firstOrNull;
}

String normalizeWordLyric(String input) {
  return input.replaceAllMapped(_tokenPattern, (match) => match.group(3) ?? '');
}

List<LyricToken> _parseTokens(String raw) {
  final matches = _tokenPattern.allMatches(raw).toList(growable: false);
  if (matches.isEmpty) {
    return const <LyricToken>[];
  }
  return matches
      .map((match) {
        return LyricToken(
          text: match.group(3) ?? '',
          startOffset: Duration(milliseconds: int.parse(match.group(1)!)),
          duration: Duration(milliseconds: int.parse(match.group(2)!)),
        );
      })
      .toList(growable: false);
}

List<_ParsedLrcEntry> _parseEntries(
  String raw, {
  required bool normalizeWordLyric,
}) {
  final source = normalizeWordLyric ? normalizeWordLyricText(raw) : raw;
  if (source.trim().isEmpty) {
    return const <_ParsedLrcEntry>[];
  }
  final result = <_ParsedLrcEntry>[];
  for (final rawLine in source.trim().split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty) {
      continue;
    }
    final match = _linePattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final timestamps = match.namedGroup('timestamps') ?? '';
    final content = _trimContent(match.namedGroup('content') ?? '');
    if (content.isEmpty) {
      continue;
    }
    for (final timestamp in _lrcPattern.allMatches(timestamps)) {
      final rawTime = timestamp.group(0)!;
      final minute = int.parse(timestamp.group(1)!);
      final second = int.parse(timestamp.group(2)!);
      final fractionRaw = timestamp.group(3) ?? '0';
      final fraction = fractionRaw.length == 3
          ? fractionRaw
          : fractionRaw.padRight(3, '0');
      final start = Duration(
        minutes: minute,
        seconds: second,
        milliseconds: int.parse(fraction),
      );
      result.add(
        _ParsedLrcEntry(rawTime: rawTime, start: start, content: content),
      );
    }
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

String normalizeWordLyricText(String input) => normalizeWordLyric(input);

String _trimContent(String content) {
  final trimmed = content.trim();
  return trimmed.isEmpty ? content : trimmed;
}

extension on String {
  String slice(int start, [int? end]) {
    return substring(start, end);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
