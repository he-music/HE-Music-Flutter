import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';

enum MonetLyricLineStatus { waiting, active, passed }

@immutable
class MonetLyricPosition {
  const MonetLyricPosition({
    required this.playbackPosition,
    required this.timelinePosition,
    required this.activeIndex,
    required this.recentIndex,
    required this.upcomingIndex,
  });

  final Duration playbackPosition;
  final Duration timelinePosition;
  final int? activeIndex;
  final int? recentIndex;
  final int? upcomingIndex;
}

@immutable
class MonetVisibleLyricLine {
  const MonetVisibleLyricLine({
    required this.line,
    required this.index,
    required this.offset,
    required this.status,
    required this.key,
  });

  final LyricLine line;
  final int index;
  final int offset;
  final MonetLyricLineStatus status;
  final String key;
}

/// Owns document-level derived data so a renderer does not rescan every line on
/// each playback tick.
class MonetLyricLayoutEngine {
  MonetLyricLayoutEngine(this.document)
    : documentSignature = _buildDocumentSignature(document);

  final LyricDocument document;
  final String documentSignature;

  MonetLyricPosition resolvePosition(Duration playbackPosition) {
    final lines = document.lines;
    final timelinePosition =
        playbackPosition + Duration(milliseconds: document.offset);
    if (lines.isEmpty) {
      return MonetLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: null,
      );
    }

    final candidateIndex = _lastStartedLineIndex(lines, timelinePosition);
    if (candidateIndex < 0) {
      return MonetLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: 0,
      );
    }

    final candidate = lines[candidateIndex];
    final isBeforeExplicitEnd =
        candidate.end == null || timelinePosition.compareTo(candidate.end!) < 0;
    final activeIndex = isBeforeExplicitEnd ? candidateIndex : null;
    return MonetLyricPosition(
      playbackPosition: playbackPosition,
      timelinePosition: timelinePosition,
      activeIndex: activeIndex,
      recentIndex: activeIndex == null
          ? candidateIndex
          : (candidateIndex > 0 ? candidateIndex - 1 : null),
      upcomingIndex: candidateIndex + 1 < lines.length
          ? candidateIndex + 1
          : null,
    );
  }

  List<MonetVisibleLyricLine> buildVisibleWindow({
    required MonetLyricPosition position,
    int before = 2,
    int after = 2,
    int? manualAnchorIndex,
  }) {
    final lines = document.lines;
    if (lines.isEmpty) {
      return const <MonetVisibleLyricLine>[];
    }

    final requestedAnchor =
        manualAnchorIndex ??
        position.activeIndex ??
        position.upcomingIndex ??
        position.recentIndex ??
        0;
    final anchorIndex = requestedAnchor.clamp(0, lines.length - 1);
    final safeBefore = math.max(before, 0);
    final safeAfter = math.max(after, 0);
    final startIndex = math.max(0, anchorIndex - safeBefore);
    final endIndex = math.min(lines.length - 1, anchorIndex + safeAfter);

    return List<MonetVisibleLyricLine>.generate(endIndex - startIndex + 1, (
      entryIndex,
    ) {
      final index = startIndex + entryIndex;
      final line = lines[index];
      return MonetVisibleLyricLine(
        line: line,
        index: index,
        offset: index - anchorIndex,
        status: _resolveLineStatus(index, position),
        key: _lineKey(index, line),
      );
    }, growable: false);
  }
}

@immutable
class MonetDisplayToken {
  const MonetDisplayToken({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.start,
    required this.end,
    required this.key,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final Duration? start;
  final Duration? end;
  final String key;

  bool get hasTiming => start != null && end != null;
}

List<MonetDisplayToken> buildMonetDisplayTokens(LyricLine line) {
  if (line.tokens.isEmpty || line.end == null) {
    return <MonetDisplayToken>[_fallbackDisplayToken(line)];
  }

  final text = StringBuffer();
  var cursor = 0;
  var previousEnd = Duration.zero;
  final displayTokens = <MonetDisplayToken>[];
  for (var index = 0; index < line.tokens.length; index++) {
    final token = line.tokens[index];
    text.write(token.text);
    final endOffset = cursor + token.text.length;
    final tokenEndOffset = token.endOffset;
    final lineDuration = line.end! - line.start;
    final timingIsValid =
        token.startOffset >= Duration.zero &&
        token.duration > Duration.zero &&
        token.startOffset >= previousEnd &&
        tokenEndOffset > token.startOffset &&
        tokenEndOffset <= lineDuration;
    if (!timingIsValid) {
      return <MonetDisplayToken>[_fallbackDisplayToken(line)];
    }

    displayTokens.add(
      MonetDisplayToken(
        text: token.text,
        startOffset: cursor,
        endOffset: endOffset,
        start: line.start + token.startOffset,
        end: line.start + tokenEndOffset,
        key: '${line.start.inMicroseconds}:$index:$cursor:$endOffset',
      ),
    );
    cursor = endOffset;
    previousEnd = tokenEndOffset;
  }

  if (text.toString() != line.text) {
    return <MonetDisplayToken>[_fallbackDisplayToken(line)];
  }
  return List<MonetDisplayToken>.unmodifiable(displayTokens);
}

double resolveMonetTokenProgress({
  required Duration timelinePosition,
  required MonetDisplayToken token,
}) {
  final start = token.start;
  final end = token.end;
  if (start == null || end == null || end <= start) {
    return 0;
  }
  if (timelinePosition <= start) {
    return 0;
  }
  if (timelinePosition >= end) {
    return 1;
  }
  final elapsed = (timelinePosition - start).inMicroseconds;
  final duration = (end - start).inMicroseconds;
  return (elapsed / duration).clamp(0.0, 1.0);
}

@immutable
class MonetLyricLayoutOptions {
  const MonetLyricLayoutOptions({
    required this.railSize,
    required this.activeTextStyle,
    required this.inactiveTextStyle,
    required this.translationTextStyle,
    this.textDirection = TextDirection.ltr,
    this.textAlign = TextAlign.left,
    this.textScaleFactor = 1,
    this.showTranslation = true,
    this.useRomanizationFallback = true,
    this.translationOnlyForActiveLine = true,
    this.inactiveMaxLines = 2,
    this.horizontalPadding = 8,
    this.verticalPadding = 8,
    this.translationGap = 6,
    this.activeGap = 18,
    this.inactiveGap = 14,
    this.anchorAlignment = 0.46,
  });

  final Size railSize;
  final TextStyle activeTextStyle;
  final TextStyle inactiveTextStyle;
  final TextStyle translationTextStyle;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final double textScaleFactor;
  final bool showTranslation;
  final bool useRomanizationFallback;
  final bool translationOnlyForActiveLine;
  final int inactiveMaxLines;
  final double horizontalPadding;
  final double verticalPadding;
  final double translationGap;
  final double activeGap;
  final double inactiveGap;
  final double anchorAlignment;
}

@immutable
class MonetMeasuredLyricLine {
  const MonetMeasuredLyricLine({
    required this.mainTextSize,
    required this.mainLineCount,
    required this.mainTextClipped,
    required this.translationText,
    required this.translationSize,
    required this.translationLineCount,
    required this.visualSize,
    required this.mainTextOffset,
    required this.translationOffset,
  });

  final Size mainTextSize;
  final int mainLineCount;
  final bool mainTextClipped;
  final String? translationText;
  final Size translationSize;
  final int translationLineCount;
  final Size visualSize;
  final Offset mainTextOffset;
  final Offset? translationOffset;
}

@immutable
class MonetPositionedLyricLine {
  const MonetPositionedLyricLine({
    required this.entry,
    required this.measurement,
    required this.rect,
    required this.hitRect,
    required this.cacheKey,
  });

  final MonetVisibleLyricLine entry;
  final MonetMeasuredLyricLine measurement;
  final Rect rect;
  final Rect hitRect;
  final String cacheKey;
}

class MonetLyricMeasurementCache {
  MonetLyricMeasurementCache({this.maximumEntries = 240});

  final int maximumEntries;
  final Map<String, MonetMeasuredLyricLine> _values =
      <String, MonetMeasuredLyricLine>{};

  int get length => _values.length;

  MonetMeasuredLyricLine resolve(
    String key,
    MonetMeasuredLyricLine Function() measure,
  ) {
    final cached = _values[key];
    if (cached != null) {
      return cached;
    }
    if (maximumEntries > 0 && _values.length >= maximumEntries) {
      _values.remove(_values.keys.first);
    }
    final value = measure();
    if (maximumEntries > 0) {
      _values[key] = value;
    }
    return value;
  }

  void clear() => _values.clear();
}

String buildMonetLyricLayoutCacheKey({
  required String documentSignature,
  required MonetVisibleLyricLine entry,
  required MonetLyricLayoutOptions options,
}) {
  final mainStyle = entry.status == MonetLyricLineStatus.active
      ? options.activeTextStyle
      : options.inactiveTextStyle;
  return <Object?>[
    documentSignature,
    entry.key,
    entry.status.name,
    _encode(entry.line.text),
    _encode(entry.line.translation),
    _encode(entry.line.romanization),
    options.railSize.width,
    options.railSize.height,
    _textStyleMetricsKey(mainStyle),
    _textStyleMetricsKey(options.translationTextStyle),
    options.textDirection.name,
    options.textAlign.name,
    options.textScaleFactor,
    options.showTranslation,
    options.useRomanizationFallback,
    options.translationOnlyForActiveLine,
    options.inactiveMaxLines,
    options.horizontalPadding,
    options.verticalPadding,
    options.translationGap,
  ].join('\u0001');
}

List<MonetPositionedLyricLine> layoutMonetLyricWindow({
  required MonetLyricLayoutEngine engine,
  required List<MonetVisibleLyricLine> entries,
  required MonetLyricLayoutOptions options,
  MonetLyricMeasurementCache? cache,
}) {
  if (entries.isEmpty) {
    return const <MonetPositionedLyricLine>[];
  }

  final measured = entries
      .map((entry) {
        final cacheKey = buildMonetLyricLayoutCacheKey(
          documentSignature: engine.documentSignature,
          entry: entry,
          options: options,
        );
        final measurement =
            cache?.resolve(cacheKey, () => _measureLine(entry, options)) ??
            _measureLine(entry, options);
        return (entry: entry, measurement: measurement, cacheKey: cacheKey);
      })
      .toList(growable: false);

  final anchorIndex = math.max(
    0,
    measured.indexWhere((value) => value.entry.offset == 0),
  );
  final tops = List<double>.filled(measured.length, 0);
  final railHeight = math.max(options.railSize.height, 0.0);
  final anchorHeight = measured[anchorIndex].measurement.visualSize.height;
  final desiredAnchorTop =
      railHeight * options.anchorAlignment.clamp(0.0, 1.0) - anchorHeight / 2;
  tops[anchorIndex] = anchorHeight <= railHeight
      ? desiredAnchorTop.clamp(0.0, railHeight - anchorHeight)
      : 0;
  for (var index = anchorIndex + 1; index < measured.length; index++) {
    tops[index] =
        tops[index - 1] +
        measured[index - 1].measurement.visualSize.height +
        _lineGap(measured[index - 1].entry, measured[index].entry, options);
  }
  for (var index = anchorIndex - 1; index >= 0; index--) {
    tops[index] =
        tops[index + 1] -
        measured[index].measurement.visualSize.height -
        _lineGap(measured[index].entry, measured[index + 1].entry, options);
  }

  final railBounds = Rect.fromLTWH(
    0,
    0,
    math.max(options.railSize.width, 0.0),
    railHeight,
  );
  return List<MonetPositionedLyricLine>.generate(measured.length, (index) {
    final value = measured[index];
    final rect = Rect.fromLTWH(
      0,
      tops[index],
      math.max(options.railSize.width, 0.0),
      value.measurement.visualSize.height,
    );
    return MonetPositionedLyricLine(
      entry: value.entry,
      measurement: value.measurement,
      rect: rect,
      hitRect: _boundedIntersection(rect, railBounds),
      cacheKey: value.cacheKey,
    );
  }, growable: false);
}

int _lastStartedLineIndex(List<LyricLine> lines, Duration position) {
  var low = 0;
  var high = lines.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (lines[middle].start.compareTo(position) <= 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low - 1;
}

MonetLyricLineStatus _resolveLineStatus(
  int index,
  MonetLyricPosition position,
) {
  if (index == position.activeIndex) {
    return MonetLyricLineStatus.active;
  }
  final activeIndex = position.activeIndex;
  if (activeIndex != null) {
    return index < activeIndex
        ? MonetLyricLineStatus.passed
        : MonetLyricLineStatus.waiting;
  }
  final recentIndex = position.recentIndex;
  return recentIndex != null && index <= recentIndex
      ? MonetLyricLineStatus.passed
      : MonetLyricLineStatus.waiting;
}

MonetDisplayToken _fallbackDisplayToken(LyricLine line) {
  return MonetDisplayToken(
    text: line.text,
    startOffset: 0,
    endOffset: line.text.length,
    start: null,
    end: null,
    key: '${line.start.inMicroseconds}:fallback:${_encode(line.text)}',
  );
}

MonetMeasuredLyricLine _measureLine(
  MonetVisibleLyricLine entry,
  MonetLyricLayoutOptions options,
) {
  final isActive = entry.status == MonetLyricLineStatus.active;
  final contentWidth = math.max(
    options.railSize.width - options.horizontalPadding * 2,
    0.0,
  );
  final mainPainter = TextPainter(
    text: TextSpan(
      text: entry.line.text,
      style: isActive ? options.activeTextStyle : options.inactiveTextStyle,
    ),
    textDirection: options.textDirection,
    textAlign: options.textAlign,
    textScaler: TextScaler.linear(options.textScaleFactor),
    maxLines: isActive ? null : math.max(options.inactiveMaxLines, 1),
    ellipsis: isActive ? null : '\u2026',
  )..layout(maxWidth: contentWidth);
  final mainMetrics = mainPainter.computeLineMetrics();

  final translationText = _resolveTranslationText(entry, options);
  TextPainter? translationPainter;
  if (translationText != null) {
    translationPainter = TextPainter(
      text: TextSpan(
        text: translationText,
        style: options.translationTextStyle,
      ),
      textDirection: options.textDirection,
      textAlign: options.textAlign,
      textScaler: TextScaler.linear(options.textScaleFactor),
    )..layout(maxWidth: contentWidth);
  }
  final translationMetrics = translationPainter?.computeLineMetrics();
  final translationHeight = translationPainter?.height ?? 0;
  final hasTranslation = translationPainter != null;
  final mainOffset = Offset(options.horizontalPadding, options.verticalPadding);
  final translationOffset = hasTranslation
      ? Offset(
          options.horizontalPadding,
          options.verticalPadding + mainPainter.height + options.translationGap,
        )
      : null;
  final visualHeight =
      options.verticalPadding * 2 +
      mainPainter.height +
      (hasTranslation ? options.translationGap + translationHeight : 0);

  return MonetMeasuredLyricLine(
    mainTextSize: mainPainter.size,
    mainLineCount: mainMetrics.length,
    mainTextClipped: mainPainter.didExceedMaxLines,
    translationText: translationText,
    translationSize: translationPainter?.size ?? Size.zero,
    translationLineCount: translationMetrics?.length ?? 0,
    visualSize: Size(math.max(options.railSize.width, 0.0), visualHeight),
    mainTextOffset: mainOffset,
    translationOffset: translationOffset,
  );
}

String? _resolveTranslationText(
  MonetVisibleLyricLine entry,
  MonetLyricLayoutOptions options,
) {
  if (!options.showTranslation ||
      (options.translationOnlyForActiveLine &&
          entry.status != MonetLyricLineStatus.active)) {
    return null;
  }
  if (entry.line.translation.trim().isNotEmpty) {
    return entry.line.translation;
  }
  if (options.useRomanizationFallback &&
      entry.line.romanization.trim().isNotEmpty) {
    return entry.line.romanization;
  }
  return null;
}

double _lineGap(
  MonetVisibleLyricLine first,
  MonetVisibleLyricLine second,
  MonetLyricLayoutOptions options,
) {
  return first.status == MonetLyricLineStatus.active ||
          second.status == MonetLyricLineStatus.active
      ? math.max(options.activeGap, 0.0)
      : math.max(options.inactiveGap, 0.0);
}

Rect _boundedIntersection(Rect rect, Rect bounds) {
  final left = math.max(rect.left, bounds.left);
  final top = math.max(rect.top, bounds.top);
  final right = math.min(rect.right, bounds.right);
  final bottom = math.min(rect.bottom, bounds.bottom);
  if (right <= left || bottom <= top) {
    return Rect.fromLTWH(
      left.clamp(bounds.left, bounds.right),
      top.clamp(bounds.top, bounds.bottom),
      0,
      0,
    );
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

String _lineKey(int index, LyricLine line) {
  return '$index:${line.start.inMicroseconds}:${line.end?.inMicroseconds ?? -1}:'
      '${_encode(line.text)}';
}

String _buildDocumentSignature(LyricDocument document) {
  final buffer = StringBuffer(
    'offset=${document.offset};lines=${document.lines.length};',
  );
  for (var index = 0; index < document.lines.length; index++) {
    final line = document.lines[index];
    buffer
      ..write(_lineKey(index, line))
      ..write(':translation=')
      ..write(_encode(line.translation))
      ..write(':romanization=')
      ..write(_encode(line.romanization))
      ..write(':tokens=');
    for (final token in line.tokens) {
      buffer
        ..write(_encode(token.text))
        ..write('@')
        ..write(token.startOffset.inMicroseconds)
        ..write('+')
        ..write(token.duration.inMicroseconds)
        ..write(';');
    }
  }
  return buffer.toString();
}

String _textStyleMetricsKey(TextStyle style) {
  return <Object?>[
    style.fontFamily,
    style.fontFamilyFallback?.join(','),
    style.fontSize,
    style.fontWeight?.value,
    style.fontStyle?.name,
    style.letterSpacing,
    style.wordSpacing,
    style.textBaseline?.name,
    style.height,
    style.leadingDistribution?.name,
    style.locale,
    style.fontFeatures?.join(','),
    style.fontVariations?.join(','),
    style.decorationStyle?.name,
    style.decorationThickness,
  ].join('|');
}

String _encode(String value) => '${value.length}:$value';
