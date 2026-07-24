class SearchTextSegment {
  const SearchTextSegment({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;
}

List<SearchTextSegment> splitSearchHighlightText({
  required String text,
  required List<String> matchedKeywords,
  required String fallbackKeyword,
}) {
  if (text.isEmpty) {
    return const <SearchTextSegment>[];
  }
  final keywords = _normalizeKeywords(matchedKeywords, fallbackKeyword);
  if (keywords.isEmpty) {
    return <SearchTextSegment>[
      SearchTextSegment(text: text, highlighted: false),
    ];
  }

  final lowerText = text.toLowerCase();
  final segments = <SearchTextSegment>[];
  var plainStart = 0;
  var cursor = 0;
  while (cursor < text.length) {
    String? matched;
    for (final keyword in keywords) {
      if (lowerText.startsWith(keyword.toLowerCase(), cursor)) {
        matched = keyword;
        break;
      }
    }
    if (matched == null) {
      cursor += 1;
      continue;
    }
    if (plainStart < cursor) {
      segments.add(
        SearchTextSegment(
          text: text.substring(plainStart, cursor),
          highlighted: false,
        ),
      );
    }
    final end = cursor + matched.length;
    segments.add(
      SearchTextSegment(text: text.substring(cursor, end), highlighted: true),
    );
    cursor = end;
    plainStart = end;
  }
  if (plainStart < text.length) {
    segments.add(
      SearchTextSegment(text: text.substring(plainStart), highlighted: false),
    );
  }
  return segments;
}

List<String> _normalizeKeywords(
  List<String> matchedKeywords,
  String fallbackKeyword,
) {
  final source = matchedKeywords
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final candidates = source.isEmpty ? <String>[fallbackKeyword.trim()] : source;
  final seen = <String>{};
  final result = <String>[];
  for (final keyword in candidates) {
    if (keyword.isEmpty || !seen.add(keyword.toLowerCase())) {
      continue;
    }
    result.add(keyword);
  }
  result.sort((left, right) => right.length.compareTo(left.length));
  return result;
}
