import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';

const double tiltDefaultSplitProbability = 0.75;
const double tiltDefaultStyleProbability = 0.35;
const String tiltInterludeText = '......';
const Duration tiltInterludeGap = Duration(seconds: 3);

/// The source line duration bucket used by the reveal animation.
enum TiltTimingClass { normal, short, micro }

TiltTimingClass resolveTiltTimingClass(LyricLine line) {
  final end = line.end;
  if (end == null || end <= line.start) {
    return TiltTimingClass.normal;
  }
  final duration = end - line.start;
  if (duration < const Duration(milliseconds: 100)) {
    return TiltTimingClass.micro;
  }
  if (duration < const Duration(milliseconds: 180)) {
    return TiltTimingClass.short;
  }
  return TiltTimingClass.normal;
}

@immutable
class TiltLyricPosition {
  const TiltLyricPosition({
    required this.playbackPosition,
    required this.timelinePosition,
    required this.activeIndex,
    required this.upcomingIndex,
  });

  final Duration playbackPosition;
  final Duration timelinePosition;
  final int? activeIndex;
  final int? upcomingIndex;
}

@immutable
class TiltLyricLayoutOptions {
  const TiltLyricLayoutOptions({
    required this.stageSize,
    required this.normalStyle,
    required this.tiltStyle,
    this.textDirection = TextDirection.ltr,
    this.locale,
    this.textScaleFactor = 1,
    this.horizontalInset = 18,
    this.verticalInset = 18,
    this.splitProbability = tiltDefaultSplitProbability,
    this.tiltStyleProbability = tiltDefaultStyleProbability,
    this.hitSlop = 10,
  });

  final Size stageSize;
  final TextStyle normalStyle;
  final TextStyle tiltStyle;
  final TextDirection textDirection;
  final Locale? locale;
  final double textScaleFactor;
  final double horizontalInset;
  final double verticalInset;
  final double splitProbability;
  final double tiltStyleProbability;
  final double hitSlop;
}

@immutable
class TiltGraphemePlacement {
  const TiltGraphemePlacement({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.localBounds,
    required this.bounds,
    required this.staggerSign,
    this.start,
    this.end,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final Rect localBounds;
  final Rect bounds;
  final int staggerSign;
  final Duration? start;
  final Duration? end;

  bool get isTimed => start != null && end != null && end! > start!;
}

@immutable
class TiltLyricSegmentLayout {
  const TiltLyricSegmentLayout({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.isTilt,
    required this.isShortLast,
    required this.origin,
    required this.size,
    required this.paintScale,
    required this.revealAt,
    required this.hitRect,
    required this.graphemes,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final bool isTilt;
  final bool isShortLast;
  final Offset origin;
  final Size size;
  final double paintScale;
  final Duration revealAt;
  final Rect hitRect;
  final List<TiltGraphemePlacement> graphemes;
}

@immutable
class TiltLyricLineLayout {
  const TiltLyricLineLayout({
    required this.sourceLine,
    required this.sourceLineIndex,
    required this.segments,
    required this.hasFineTiming,
    required this.auxiliaryText,
    required this.cacheKey,
    required this.stageBounds,
  });

  final LyricLine sourceLine;
  final int sourceLineIndex;
  final List<TiltLyricSegmentLayout> segments;
  final bool hasFineTiming;
  final String? auxiliaryText;
  final String cacheKey;
  final Rect stageBounds;
}

class TiltLyricLayoutCache {
  TiltLyricLayoutCache({this.maximumEntries = 48});

  final int maximumEntries;
  final Map<String, TiltLyricLineLayout> _values =
      <String, TiltLyricLineLayout>{};

  int get length => _values.length;

  TiltLyricLineLayout resolve(
    String key,
    TiltLyricLineLayout Function() build,
  ) {
    final cached = _values[key];
    if (cached != null) return cached;
    final value = build();
    if (maximumEntries <= 0) return value;
    if (_values.length >= maximumEntries) _values.remove(_values.keys.first);
    _values[key] = value;
    return value;
  }

  void clear() => _values.clear();
}

@immutable
class _TiltRenderableLine {
  const _TiltRenderableLine({
    required this.line,
    required this.sourceIndex,
    required this.isInterlude,
  });

  final LyricLine line;
  final int sourceIndex;
  final bool isInterlude;
}

List<_TiltRenderableLine> _buildTiltRenderableLines(
  List<LyricLine> sourceLines,
) {
  if (sourceLines.isEmpty) return const <_TiltRenderableLine>[];
  final result = <_TiltRenderableLine>[];
  final first = sourceLines.first;
  if (first.start > tiltInterludeGap) {
    result.add(
      _TiltRenderableLine(
        line: _createTiltInterlude(
          const Duration(milliseconds: 500),
          first.start,
        ),
        sourceIndex: 0,
        isInterlude: true,
      ),
    );
  }
  for (var index = 0; index < sourceLines.length; index++) {
    final current = sourceLines[index];
    final next = index + 1 < sourceLines.length ? sourceLines[index + 1] : null;
    if (next == null || current.end == null) {
      result.add(
        _TiltRenderableLine(
          line: current,
          sourceIndex: index,
          isInterlude: false,
        ),
      );
      continue;
    }
    final gap = next.start - current.end!;
    if (gap > Duration.zero && gap <= tiltInterludeGap) {
      result.add(
        _TiltRenderableLine(
          line: _copyTiltLineWithEnd(current, next.start),
          sourceIndex: index,
          isInterlude: false,
        ),
      );
      continue;
    }
    result.add(
      _TiltRenderableLine(
        line: current,
        sourceIndex: index,
        isInterlude: false,
      ),
    );
    if (gap > tiltInterludeGap) {
      result.add(
        _TiltRenderableLine(
          line: _createTiltInterlude(current.end!, next.start),
          sourceIndex: index,
          isInterlude: true,
        ),
      );
    }
  }
  return List<_TiltRenderableLine>.unmodifiable(result);
}

LyricLine _copyTiltLineWithEnd(LyricLine line, Duration end) => LyricLine(
  start: line.start,
  end: end,
  text: line.text,
  tokens: line.tokens,
  translation: line.translation,
  romanization: line.romanization,
);

LyricLine _createTiltInterlude(Duration start, Duration end) {
  final durationMicros = math.max(end.inMicroseconds - start.inMicroseconds, 1);
  final tokens = List<LyricToken>.generate(6, (index) {
    final tokenStart = Duration(
      microseconds: start.inMicroseconds + durationMicros * index ~/ 6,
    );
    final tokenEnd = Duration(
      microseconds: start.inMicroseconds + durationMicros * (index + 1) ~/ 6,
    );
    return LyricToken(
      text: '.',
      startOffset: tokenStart - start,
      duration: tokenEnd - tokenStart,
    );
  }, growable: false);
  return LyricLine(
    start: start,
    end: end,
    text: tiltInterludeText,
    tokens: tokens,
  );
}

class TiltLyricLayoutEngine {
  TiltLyricLayoutEngine(this.document)
    : documentSignature = _documentSignature(document),
      _renderLines = _buildTiltRenderableLines(document.lines);

  factory TiltLyricLayoutEngine.fromDocument(LyricDocument document) =>
      TiltLyricLayoutEngine(document);

  final LyricDocument document;
  final String documentSignature;
  final List<_TiltRenderableLine> _renderLines;

  int get lineCount => _renderLines.length;

  LyricLine? lineAt(int index) => index < 0 || index >= _renderLines.length
      ? null
      : _renderLines[index].line;

  bool isInterludeAt(int index) =>
      index >= 0 &&
      index < _renderLines.length &&
      _renderLines[index].isInterlude;

  TiltLyricPosition resolvePosition(Duration playbackPosition) {
    final timelinePosition =
        playbackPosition + Duration(milliseconds: document.offset);
    int? activeIndex;
    for (var index = _renderLines.length - 1; index >= 0; index--) {
      final line = _renderLines[index].line;
      if (timelinePosition < line.start) continue;
      if (timelinePosition <= _lineEnd(line, index)) {
        activeIndex = index;
        break;
      }
    }
    final upcomingIndex = activeIndex == null
        ? _firstIndexAfter(timelinePosition)
        : activeIndex + 1 < _renderLines.length
        ? activeIndex + 1
        : null;
    return TiltLyricPosition(
      playbackPosition: playbackPosition,
      timelinePosition: timelinePosition,
      activeIndex: activeIndex,
      upcomingIndex: upcomingIndex,
    );
  }

  Duration seekPositionFor(int renderLineIndex) {
    if (renderLineIndex < 0 ||
        renderLineIndex >= _renderLines.length ||
        isInterludeAt(renderLineIndex)) {
      return Duration.zero;
    }
    final line = _renderLines[renderLineIndex].line;
    final value = line.start - Duration(milliseconds: document.offset);
    return value.isNegative ? Duration.zero : value;
  }

  TiltLyricLineLayout? layoutLine({
    required int sourceLineIndex,
    required TiltLyricLayoutOptions options,
    TiltLyricLayoutCache? cache,
  }) {
    final line = lineAt(sourceLineIndex);
    if (line == null || line.text.isEmpty) return null;
    final cacheKey = buildTiltLyricLayoutCacheKey(
      documentSignature: documentSignature,
      sourceLineIndex: sourceLineIndex,
      line: line,
      options: options,
    );
    return cache?.resolve(
          cacheKey,
          () => _buildLineLayout(
            line: line,
            sourceLineIndex: sourceLineIndex,
            options: options,
            cacheKey: cacheKey,
          ),
        ) ??
        _buildLineLayout(
          line: line,
          sourceLineIndex: sourceLineIndex,
          options: options,
          cacheKey: cacheKey,
        );
  }

  Duration _lineEnd(LyricLine line, int index) {
    if (line.end != null && line.end! > line.start) return line.end!;
    if (index + 1 < _renderLines.length &&
        _renderLines[index + 1].line.start > line.start) {
      return _renderLines[index + 1].line.start;
    }
    final tokenEnd = line.tokens.fold<Duration>(
      Duration.zero,
      (max, token) => token.endOffset > max ? token.endOffset : max,
    );
    return tokenEnd > Duration.zero
        ? line.start + tokenEnd
        : line.start + const Duration(seconds: 3);
  }

  int? _firstIndexAfter(Duration position) {
    for (var index = 0; index < _renderLines.length; index++) {
      if (_renderLines[index].line.start > position) return index;
    }
    return null;
  }

  TiltLyricLineLayout _buildLineLayout({
    required LyricLine line,
    required int sourceLineIndex,
    required TiltLyricLayoutOptions options,
    required String cacheKey,
  }) {
    final hasFineTiming = hasValidTiltTokenTiming(line);
    final timing = hasFineTiming
        ? _buildGraphemeTiming(line)
        : const <_TimedGrapheme>[];
    final maxWidth = math
        .max(options.stageSize.width - options.horizontalInset * 2, 1)
        .toDouble();
    final rawSegments = _buildSegments(
      line.text,
      line.start.inMicroseconds,
      options.splitProbability,
      options.tiltStyleProbability,
      maxWidth: maxWidth,
      options: options,
    );
    final measured = _measureSegments(
      line,
      rawSegments,
      timing,
      options,
      maxWidth,
    );
    final totalHeight = measured.heights.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final gap = math
        .min(18, math.max(5, options.stageSize.height * 0.018))
        .toDouble();
    final contentHeight =
        totalHeight + gap * math.max(measured.segments.length - 1, 0);
    final scale = math
        .min(
          1.0,
          math.min(
            maxWidth / math.max(measured.maxWidth, 1),
            (options.stageSize.height - options.verticalInset * 2) /
                math.max(contentHeight, 1),
          ),
        )
        .clamp(0.5, 1.0)
        .toDouble();
    var top = (options.stageSize.height - contentHeight * scale) / 2;
    final positioned = <TiltLyricSegmentLayout>[];
    for (var index = 0; index < measured.segments.length; index++) {
      final segment = measured.segments[index];
      final y = top + measured.heights[index] * scale / 2;
      final x = options.textDirection == TextDirection.rtl
          ? options.stageSize.width -
                options.horizontalInset -
                measured.widths[index] * scale
          : options.horizontalInset;
      final origin = Offset(x, y - measured.heights[index] * scale / 2);
      final bounds = Rect.fromLTWH(
        x,
        origin.dy,
        measured.widths[index] * scale,
        measured.heights[index] * scale,
      );
      final placements = segment.graphemes
          .map((grapheme) {
            final local = grapheme.localBounds;
            final placed = Rect.fromLTWH(
              origin.dx + local.left * scale,
              origin.dy + local.top * scale,
              local.width * scale,
              local.height * scale,
            );
            return TiltGraphemePlacement(
              text: grapheme.text,
              startOffset: grapheme.startOffset,
              endOffset: grapheme.endOffset,
              localBounds: local,
              bounds: placed,
              staggerSign: grapheme.staggerSign,
              start: grapheme.start,
              end: grapheme.end,
            );
          })
          .toList(growable: false);
      positioned.add(
        TiltLyricSegmentLayout(
          text: segment.text,
          startOffset: segment.startOffset,
          endOffset: segment.endOffset,
          isTilt: segment.isTilt,
          isShortLast: segment.isShortLast,
          origin: origin,
          size: Size(bounds.width, bounds.height),
          paintScale: scale,
          revealAt: segment.revealAt,
          hitRect: bounds.inflate(options.hitSlop),
          graphemes: List<TiltGraphemePlacement>.unmodifiable(placements),
        ),
      );
      top += measured.heights[index] * scale + gap * scale;
    }
    return TiltLyricLineLayout(
      sourceLine: line,
      sourceLineIndex: sourceLineIndex,
      segments: List<TiltLyricSegmentLayout>.unmodifiable(positioned),
      hasFineTiming: hasFineTiming,
      auxiliaryText: line.translation.trim().isNotEmpty
          ? line.translation
          : line.romanization.trim().isNotEmpty
          ? line.romanization
          : null,
      cacheKey: cacheKey,
      stageBounds: Offset.zero & options.stageSize,
    );
  }
}

@immutable
class _RawSegment {
  const _RawSegment({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.isTilt,
    required this.isShortLast,
    required this.revealAt,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final bool isTilt;
  final bool isShortLast;
  final Duration revealAt;
}

@immutable
class _TimedGrapheme {
  const _TimedGrapheme({
    required this.startOffset,
    required this.endOffset,
    required this.start,
    required this.end,
  });

  final int startOffset;
  final int endOffset;
  final Duration start;
  final Duration end;
}

@immutable
class _MeasuredSegments {
  const _MeasuredSegments({
    required this.segments,
    required this.widths,
    required this.heights,
    required this.maxWidth,
  });

  final List<_MeasuredSegment> segments;
  final List<double> widths;
  final List<double> heights;
  final double maxWidth;
}

@immutable
class _MeasuredSegment {
  const _MeasuredSegment({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.isTilt,
    required this.isShortLast,
    required this.revealAt,
    required this.graphemes,
  });

  final String text;
  final int startOffset;
  final int endOffset;
  final bool isTilt;
  final bool isShortLast;
  final Duration revealAt;
  final List<TiltGraphemePlacement> graphemes;
}

List<_RawSegment> _buildSegments(
  String text,
  int seed,
  double splitProbability,
  double tiltProbability, {
  required double maxWidth,
  required TiltLyricLayoutOptions options,
}) {
  final graphemes = text.characters.toList(growable: false);
  final count = graphemes.where((value) => value.trim().isNotEmpty).length;
  final normalized = math.log(count + 4) / math.log(24);
  final score = normalized * (_seeded(seed, 1) * 0.6 + 0.7) * splitProbability;
  var target = score < 0.45
      ? 1
      : score < 1.05
      ? 2
      : score < 1.7
      ? 3
      : 4;
  var segments = _semanticSplit(text, target);
  final tooLong = segments.any(
    (part) => _measureWidth(part, options.normalStyle, options) > maxWidth,
  );
  if (tooLong && segments.length < 4) {
    target = math.min(4, math.max(target + 1, (text.length / 12).ceil()));
    segments = _semanticSplit(text, target);
  }
  final offsets = _offsetSegments(text, segments);
  final candidateIndexes = <int>[];
  for (var index = 0; index < offsets.length; index++) {
    if (_seeded(seed, 100 + index) < tiltProbability &&
        offsets[index].text.trim().isNotEmpty) {
      candidateIndexes.add(index);
    }
  }
  final selected = candidateIndexes.isEmpty
      ? -1
      : candidateIndexes[(_seeded(seed, 200) * candidateIndexes.length)
            .floor()
            .clamp(0, candidateIndexes.length - 1)];
  return offsets.indexed
      .map((entry) {
        final index = entry.$1;
        final value = entry.$2;
        final shortLast =
            index == offsets.length - 1 &&
            value.text.trim().characters.length <= 2 &&
            index > 0 &&
            value.text.trim().characters.length * 2 <=
                offsets[index - 1].text.trim().characters.length;
        return _RawSegment(
          text: value.text,
          startOffset: value.startOffset,
          endOffset: value.endOffset,
          isTilt: index == selected,
          isShortLast: shortLast,
          revealAt: Duration.zero,
        );
      })
      .toList(growable: false);
}

List<_RawSegment> _offsetSegments(String source, List<String> pieces) {
  final result = <_RawSegment>[];
  var cursor = 0;
  for (final piece in pieces) {
    final start = cursor;
    cursor += piece.length;
    result.add(
      _RawSegment(
        text: piece,
        startOffset: start,
        endOffset: cursor,
        isTilt: false,
        isShortLast: false,
        revealAt: Duration.zero,
      ),
    );
  }
  if (cursor != source.length) {
    throw StateError('Tilt segment splitter lost source text');
  }
  return result;
}

List<String> _semanticSplit(String text, int target) {
  if (target <= 1 || text.characters.length < 2) return <String>[text];
  final boundaries = <int>[];
  var offset = 0;
  for (final grapheme in text.characters) {
    offset += grapheme.length;
    if (RegExp(r'[，。；！？、…·.,;!?]').hasMatch(grapheme) ||
        grapheme.trim().isEmpty) {
      boundaries.add(offset);
    }
  }
  final cuts = <int>[];
  for (var index = 1; index < target; index++) {
    final ideal = text.length * index / target;
    final candidates = boundaries.where(
      (value) => value > (cuts.isEmpty ? 0 : cuts.last) && value < text.length,
    );
    final cut = candidates.isEmpty
        ? _nearestGraphemeBoundary(text, ideal.round())
        : candidates.reduce(
            (a, b) => (a - ideal).abs() < (b - ideal).abs() ? a : b,
          );
    if (cut > 0 && cut < text.length && !cuts.contains(cut)) cuts.add(cut);
  }
  cuts.sort();
  final result = <String>[];
  var start = 0;
  for (final cut in cuts) {
    result.add(text.substring(start, cut));
    start = cut;
  }
  result.add(text.substring(start));
  return result.where((value) => value.isNotEmpty).toList(growable: false);
}

int _nearestGraphemeBoundary(String text, int requested) {
  var offset = 0;
  var nearest = 0;
  var distance = double.infinity;
  for (final grapheme in text.characters) {
    offset += grapheme.length;
    final nextDistance = (offset - requested).abs();
    if (nextDistance < distance) {
      nearest = offset;
      distance = nextDistance.toDouble();
    }
  }
  return nearest;
}

_MeasuredSegments _measureSegments(
  LyricLine line,
  List<_RawSegment> raw,
  List<_TimedGrapheme> timing,
  TiltLyricLayoutOptions options,
  double maxWidth,
) {
  final measured = <_MeasuredSegment>[];
  final widths = <double>[];
  final heights = <double>[];
  for (final segment in raw) {
    final style = segment.isTilt ? options.tiltStyle : options.normalStyle;
    final painter = TextPainter(
      text: TextSpan(text: segment.text, style: style),
      textDirection: options.textDirection,
      locale: options.locale,
      textScaler: TextScaler.linear(options.textScaleFactor),
      maxLines: 1,
    )..layout(maxWidth: math.max(maxWidth * 2, 1));
    final graphemes = <TiltGraphemePlacement>[];
    var localOffset = 0;
    var visualIndex = 0;
    for (final grapheme in segment.text.characters) {
      final startOffset = segment.startOffset + localOffset;
      localOffset += grapheme.length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: localOffset - grapheme.length,
          extentOffset: localOffset,
        ),
      );
      final localBounds = boxes.isEmpty
          ? Rect.fromLTWH(0, 0, painter.width, painter.height)
          : boxes
                .map((box) => box.toRect())
                .reduce((a, b) => a.expandToInclude(b));
      final match = timing
          .where(
            (item) =>
                item.startOffset < segment.endOffset &&
                item.endOffset > startOffset,
          )
          .firstOrNull;
      graphemes.add(
        TiltGraphemePlacement(
          text: grapheme,
          startOffset: startOffset,
          endOffset: segment.startOffset + localOffset,
          localBounds: localBounds,
          bounds: localBounds,
          staggerSign: segment.isTilt && grapheme.trim().isNotEmpty
              ? visualIndex.isEven
                    ? -1
                    : 1
              : 0,
          start: match?.start,
          end: match?.end,
        ),
      );
      if (grapheme.trim().isNotEmpty) visualIndex++;
    }
    final segmentTiming = timing.where(
      (item) =>
          item.startOffset < segment.endOffset &&
          item.endOffset > segment.startOffset,
    );
    final reveal = segmentTiming.isEmpty
        ? line.start
        : segmentTiming
                  .map((item) => item.start)
                  .reduce((a, b) => a < b ? a : b) -
              const Duration(milliseconds: 250);
    final resolvedReveal = reveal < line.start ? line.start : reveal;
    measured.add(
      _MeasuredSegment(
        text: segment.text,
        startOffset: segment.startOffset,
        endOffset: segment.endOffset,
        isTilt: segment.isTilt,
        isShortLast: segment.isShortLast,
        revealAt: resolvedReveal,
        graphemes: List<TiltGraphemePlacement>.unmodifiable(graphemes),
      ),
    );
    widths.add(painter.width);
    heights.add(painter.height * (segment.isTilt ? 1.25 : 1.35));
  }
  return _MeasuredSegments(
    segments: measured,
    widths: widths,
    heights: heights,
    maxWidth: widths.fold<double>(0, (a, b) => math.max(a, b).toDouble()),
  );
}

bool hasValidTiltTokenTiming(LyricLine line) {
  if (line.tokens.isEmpty || line.end == null || line.end! <= line.start) {
    return false;
  }
  if (line.tokens.map((token) => token.text).join() != line.text) {
    return false;
  }
  final duration = line.end! - line.start;
  var previousEnd = Duration.zero;
  for (final token in line.tokens) {
    if (token.startOffset < Duration.zero ||
        token.duration <= Duration.zero ||
        token.startOffset < previousEnd ||
        token.endOffset > duration) {
      return false;
    }
    previousEnd = token.endOffset;
  }
  return true;
}

List<_TimedGrapheme> _buildGraphemeTiming(LyricLine line) {
  final result = <_TimedGrapheme>[];
  var offset = 0;
  for (final token in line.tokens) {
    final graphemes = token.text.characters.toList(growable: false);
    for (var index = 0; index < graphemes.length; index++) {
      final grapheme = graphemes[index];
      final start =
          line.start +
          token.startOffset +
          Duration(
            microseconds:
                token.duration.inMicroseconds * index ~/ graphemes.length,
          );
      final end =
          line.start +
          token.startOffset +
          Duration(
            microseconds:
                token.duration.inMicroseconds * (index + 1) ~/ graphemes.length,
          );
      result.add(
        _TimedGrapheme(
          startOffset: offset,
          endOffset: offset + grapheme.length,
          start: start,
          end: end,
        ),
      );
      offset += grapheme.length;
    }
  }
  return result;
}

double _measureWidth(
  String text,
  TextStyle style,
  TiltLyricLayoutOptions options,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: options.textDirection,
    locale: options.locale,
    textScaler: TextScaler.linear(options.textScaleFactor),
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _seeded(int seed, int salt) {
  final value = math.sin(seed * 0.000001 + salt * 17.13) * 10000;
  return value - value.floorToDouble();
}

String buildTiltLyricLayoutCacheKey({
  required String documentSignature,
  required int sourceLineIndex,
  required LyricLine line,
  required TiltLyricLayoutOptions options,
}) {
  return Object.hashAll(<Object?>[
    documentSignature,
    sourceLineIndex,
    line.start,
    line.end,
    line.text,
    line.tokens
        .map((token) => '${token.text}:${token.startOffset}:${token.duration}')
        .join('|'),
    options.stageSize,
    options.normalStyle,
    options.tiltStyle,
    options.textDirection,
    options.locale,
    options.textScaleFactor,
    options.horizontalInset,
    options.verticalInset,
    options.splitProbability,
    options.tiltStyleProbability,
  ]).toString();
}

String _documentSignature(LyricDocument document) => Object.hashAll(<Object?>[
  document.offset,
  for (final line in document.lines)
    Object.hash(
      line.start,
      line.end,
      line.text,
      Object.hashAll(<Object?>[
        for (final token in line.tokens)
          Object.hash(token.text, token.startOffset, token.duration),
      ]),
    ),
]).toString();
