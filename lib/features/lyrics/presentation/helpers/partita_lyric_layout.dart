import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';

const double partitaActiveWordScale = 1.32;

enum PartitaTimingClass { normal, short, micro }

PartitaTimingClass resolvePartitaTimingClass(LyricLine line) {
  final end = line.end;
  if (end == null) return PartitaTimingClass.normal;
  final duration = end > line.start ? end - line.start : Duration.zero;
  if (duration < const Duration(milliseconds: 100)) {
    return PartitaTimingClass.micro;
  }
  if (duration < const Duration(milliseconds: 180)) {
    return PartitaTimingClass.short;
  }
  return PartitaTimingClass.normal;
}

Duration resolvePartitaLineTransitionDuration(LyricLine line) {
  return switch (resolvePartitaTimingClass(line)) {
    PartitaTimingClass.normal => const Duration(milliseconds: 300),
    PartitaTimingClass.short => const Duration(milliseconds: 160),
    PartitaTimingClass.micro => const Duration(milliseconds: 120),
  };
}

Duration? resolvePartitaLineRenderEnd(LyricLine line) {
  final end = line.end;
  if (end == null) return null;
  final rawDuration = end > line.start ? end - line.start : Duration.zero;
  final lastWordEnd = hasValidPartitaTokenTiming(line)
      ? _lastValidTokenEnd(line) ?? end
      : end;
  switch (resolvePartitaTimingClass(line)) {
    case PartitaTimingClass.micro:
      return _maxDuration(end, line.start + const Duration(milliseconds: 67));
    case PartitaTimingClass.short:
      final enter = Duration(
        microseconds: (rawDuration.inMicroseconds * 0.45).round().clamp(
          45000,
          60000,
        ),
      );
      final exit = Duration(
        microseconds: (rawDuration.inMicroseconds * 0.22).round().clamp(
          30000,
          40000,
        ),
      );
      final linePassStart =
          _maxDuration(lastWordEnd, line.start) +
          const Duration(milliseconds: 30);
      final exitStart = _maxDuration(
        line.start + enter + const Duration(milliseconds: 10),
        _maxDuration(linePassStart, end - exit),
      );
      return _maxDuration(end, exitStart + exit);
    case PartitaTimingClass.normal:
      final exit = Duration(
        microseconds: (rawDuration.inMicroseconds * 0.18).round().clamp(
          180000,
          320000,
        ),
      );
      final linePassStart =
          _maxDuration(lastWordEnd, line.start) +
          const Duration(milliseconds: 60);
      final exitStart = _maxDuration(linePassStart, end - exit);
      return _maxDuration(end, exitStart + exit);
  }
}

Duration? resolvePartitaWordActiveEnd({
  required LyricLine line,
  required Duration? start,
  required Duration? end,
}) {
  if (start == null || end == null) return end;
  final lineRenderEnd = resolvePartitaLineRenderEnd(line) ?? line.end;
  return switch (resolvePartitaTimingClass(line)) {
    PartitaTimingClass.normal => end,
    PartitaTimingClass.short =>
      lineRenderEnd == null
          ? _maxDuration(end, start + const Duration(milliseconds: 120))
          : _minDuration(
              lineRenderEnd,
              _maxDuration(end, start + const Duration(milliseconds: 120)),
            ),
    PartitaTimingClass.micro => lineRenderEnd ?? end,
  };
}

Duration? _lastValidTokenEnd(LyricLine line) {
  Duration? result;
  for (final token in line.tokens) {
    if (token.startOffset.isNegative || token.duration <= Duration.zero) {
      continue;
    }
    final tokenEnd = line.start + token.startOffset + token.duration;
    result = result == null ? tokenEnd : _maxDuration(result, tokenEnd);
  }
  return result;
}

Duration _maxDuration(Duration first, Duration second) {
  return first >= second ? first : second;
}

Duration _minDuration(Duration first, Duration second) {
  return first <= second ? first : second;
}

/// The source-line position resolved against a document's offset timeline.
@immutable
class PartitaLyricPosition {
  const PartitaLyricPosition({
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

/// Resolves Partita directly from [LyricDocument.lines].
///
/// Unlike Monet, Partita has no render window and never inserts interludes.
class PartitaLyricLayoutEngine {
  PartitaLyricLayoutEngine(this.document)
    : documentSignature = _buildDocumentSignature(document);

  factory PartitaLyricLayoutEngine.fromDocument(LyricDocument document) {
    return PartitaLyricLayoutEngine(document);
  }

  final LyricDocument document;
  final String documentSignature;

  int get lineCount => document.lines.length;

  LyricLine? lineAt(int index) {
    if (index < 0 || index >= document.lines.length) return null;
    return document.lines[index];
  }

  PartitaLyricPosition resolvePosition(Duration playbackPosition) {
    final lines = document.lines;
    final timelinePosition =
        playbackPosition + Duration(milliseconds: document.offset);
    if (lines.isEmpty) {
      return PartitaLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: null,
      );
    }

    final lastStartedIndex = _lastStartedLineIndex(lines, timelinePosition);
    if (lastStartedIndex < 0) {
      return PartitaLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: 0,
      );
    }

    int? activeIndex;
    for (var index = lastStartedIndex; index >= 0; index--) {
      final renderEnd = resolvePartitaLineRenderEnd(lines[index]);
      if (renderEnd == null || timelinePosition <= renderEnd) {
        activeIndex = index;
        break;
      }
    }
    final upcomingIndex = lastStartedIndex + 1 < lines.length
        ? lastStartedIndex + 1
        : null;
    final recentIndex = activeIndex == null
        ? lastStartedIndex
        : lastStartedIndex == activeIndex
        ? (activeIndex > 0 ? activeIndex - 1 : null)
        : lastStartedIndex;
    return PartitaLyricPosition(
      playbackPosition: playbackPosition,
      timelinePosition: timelinePosition,
      activeIndex: activeIndex,
      recentIndex: recentIndex,
      upcomingIndex: upcomingIndex,
    );
  }

  PartitaLineLayout? layoutLine({
    required int sourceLineIndex,
    required PartitaLyricLayoutOptions options,
    PartitaLyricLayoutCache? cache,
  }) {
    final line = lineAt(sourceLineIndex);
    if (line == null) return null;
    final cacheKey = buildPartitaLineLayoutCacheKey(
      documentSignature: documentSignature,
      sourceLineIndex: sourceLineIndex,
      line: line,
      options: options,
    );
    return cache?.resolve(
          cacheKey,
          () => layoutPartitaLine(
            line: line,
            sourceLineIndex: sourceLineIndex,
            options: options,
            cacheKey: cacheKey,
          ),
        ) ??
        layoutPartitaLine(
          line: line,
          sourceLineIndex: sourceLineIndex,
          options: options,
          cacheKey: cacheKey,
        );
  }
}

@immutable
class PartitaSemanticUnit {
  const PartitaSemanticUnit({
    required this.index,
    required this.text,
    required this.sourceTokenIndexes,
    required this.rawTokens,
    required this.start,
    required this.end,
    required this.isSemantic,
    required this.isSticky,
  });

  final int index;
  final String text;
  final List<int> sourceTokenIndexes;
  final List<LyricToken> rawTokens;
  final Duration? start;
  final Duration? end;

  /// Reserved for parser-provided or locale-aware semantic grouping.
  ///
  /// This implementation deliberately does not claim CJK word segmentation.
  final bool isSemantic;
  final bool isSticky;

  bool get isTimed => start != null && end != null && end! > start!;
}

@immutable
class PartitaGraphemeSlice {
  const PartitaGraphemeSlice({
    required this.grapheme,
    required this.index,
    required this.textStartOffset,
    required this.textEndOffset,
    required this.sourceTokenIndex,
    required this.start,
    required this.end,
  });

  final String grapheme;
  final int index;
  final int textStartOffset;
  final int textEndOffset;
  final int? sourceTokenIndex;
  final Duration? start;
  final Duration? end;

  bool get isTimed => start != null && end != null && end! > start!;
}

@immutable
class PartitaDisplayWord {
  const PartitaDisplayWord({
    required this.id,
    required this.text,
    required this.sourceTokenIndexes,
    required this.rawTokens,
    required this.start,
    required this.end,
    required this.graphemes,
  });

  final String id;
  final String text;
  final List<int> sourceTokenIndexes;
  final List<LyricToken> rawTokens;
  final Duration? start;
  final Duration? end;
  final List<PartitaGraphemeSlice> graphemes;

  bool get isTimed =>
      start != null &&
      end != null &&
      end! > start! &&
      graphemes.every((grapheme) => grapheme.isTimed);
}

@immutable
class PartitaWordTransform {
  const PartitaWordTransform({
    required this.offset,
    required this.rotation,
    required this.passedRotation,
  });

  final Offset offset;
  final double rotation;
  final double passedRotation;
}

@immutable
class PartitaChunkTransform {
  const PartitaChunkTransform({
    required this.offset,
    required this.scale,
    required this.rotation,
    required this.passedRotation,
    required this.marginBottom,
  });

  final Offset offset;
  final double scale;
  final double rotation;
  final double passedRotation;
  final double marginBottom;
}

@immutable
class PartitaGraphemeGeometry {
  const PartitaGraphemeGeometry({
    required this.slice,
    required this.localBounds,
    required this.bounds,
  });

  final PartitaGraphemeSlice slice;
  final Rect localBounds;
  final Rect bounds;
}

@immutable
class PartitaMeasuredWordGeometry {
  const PartitaMeasuredWordGeometry({
    required this.center,
    required this.textSize,
    required this.paintScale,
    required this.paintRotation,
    required this.bounds,
    required this.graphemes,
  });

  /// Stage-space center. A painter can translate here, rotate, scale, and paint
  /// the measured text at `-textSize / 2` without laying text out again.
  final Offset center;
  final Size textSize;
  final double paintScale;
  final double paintRotation;
  final Rect bounds;
  final List<PartitaGraphemeGeometry> graphemes;
}

@immutable
class PartitaWordLayout {
  const PartitaWordLayout({
    required this.word,
    required this.transform,
    required this.geometry,
  });

  final PartitaDisplayWord word;
  final PartitaWordTransform transform;
  final PartitaMeasuredWordGeometry geometry;
}

enum PartitaGuideSide { left, right }

@immutable
class PartitaGuideSegment {
  const PartitaGuideSegment({required this.start, required this.end});

  final Offset start;
  final Offset end;

  Rect get bounds => Rect.fromPoints(start, end);
}

@immutable
class PartitaGuideLayout {
  const PartitaGuideLayout({
    required this.side,
    required this.segments,
    required this.bounds,
  });

  final PartitaGuideSide side;
  final List<PartitaGuideSegment> segments;
  final Rect bounds;
}

@immutable
class PartitaChunkLayout {
  const PartitaChunkLayout({
    required this.rowIndex,
    required this.units,
    required this.sourceTokenIndexes,
    required this.rawTokens,
    required this.words,
    required this.start,
    required this.end,
    required this.transform,
    required this.guide,
    required this.textBounds,
    required this.visualBounds,
    required this.hitRect,
  });

  final int rowIndex;
  final List<PartitaSemanticUnit> units;
  final List<int> sourceTokenIndexes;
  final List<LyricToken> rawTokens;
  final List<PartitaWordLayout> words;
  final Duration? start;
  final Duration? end;
  final PartitaChunkTransform transform;
  final PartitaGuideLayout guide;
  final Rect textBounds;
  final Rect visualBounds;
  final Rect hitRect;

  bool get isTimed =>
      start != null &&
      end != null &&
      end! > start! &&
      words.every((word) => word.word.isTimed);
}

@immutable
class PartitaColumnLayout {
  const PartitaColumnLayout({required this.id, required this.chunks});

  final String id;
  final List<PartitaChunkLayout> chunks;
}

@immutable
class PartitaLineLayout {
  const PartitaLineLayout({
    required this.sourceLine,
    required this.sourceLineIndex,
    required this.units,
    required this.hasFineTiming,
    required this.columns,
    required this.totalGraphemes,
    required this.contentBounds,
    required this.visualBounds,
    required this.stageBounds,
    required this.fitScale,
    required this.auxiliaryText,
    required this.cacheKey,
  });

  final LyricLine sourceLine;
  final int sourceLineIndex;
  final List<PartitaSemanticUnit> units;
  final bool hasFineTiming;
  final List<PartitaColumnLayout> columns;
  final int totalGraphemes;
  final Rect contentBounds;
  final Rect visualBounds;
  final Rect stageBounds;
  final double fitScale;

  /// Translation, then romanization. It is line-owned so it is rendered once.
  final String? auxiliaryText;
  final String cacheKey;

  List<PartitaChunkLayout> get chunks =>
      columns.isEmpty ? const <PartitaChunkLayout>[] : columns.single.chunks;

  List<PartitaDisplayWord> get displayWords =>
      List<PartitaDisplayWord>.unmodifiable(
        chunks.expand((chunk) => chunk.words.map((word) => word.word)),
      );
}

@immutable
class PartitaLyricLayoutOptions {
  const PartitaLyricLayoutOptions({
    required this.stageSize,
    required this.textStyle,
    this.textDirection = TextDirection.ltr,
    this.locale,
    this.textScaleFactor = 1,
    this.horizontalInset = 18,
    this.verticalInset = 18,
    this.wordGap = 8,
    this.chunkMarginBottom = 10,
    this.staggerMin = 20,
    this.staggerMax = 100,
    this.guideLength = 32,
    this.guideOverhang = 18,
    this.hitSlop = 8,
  });

  final Size stageSize;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final Locale? locale;
  final double textScaleFactor;
  final double horizontalInset;
  final double verticalInset;
  final double wordGap;
  final double chunkMarginBottom;
  final double staggerMin;
  final double staggerMax;
  final double guideLength;
  final double guideOverhang;
  final double hitSlop;
}

class PartitaLyricLayoutCache {
  PartitaLyricLayoutCache({this.maximumEntries = 48});

  final int maximumEntries;
  final Map<String, PartitaLineLayout> _values = <String, PartitaLineLayout>{};

  int get length => _values.length;

  PartitaLineLayout resolve(String key, PartitaLineLayout Function() build) {
    final cached = _values[key];
    if (cached != null) return cached;
    final value = build();
    if (maximumEntries <= 0) return value;
    if (_values.length >= maximumEntries) {
      _values.remove(_values.keys.first);
    }
    _values[key] = value;
    return value;
  }

  void clear() => _values.clear();
}

/// Strict all-or-nothing gate for token-level timing.
bool hasValidPartitaTokenTiming(LyricLine line) {
  final lineEnd = line.end;
  if (line.tokens.isEmpty || lineEnd == null || lineEnd <= line.start) {
    return false;
  }
  if (line.tokens.map((token) => token.text).join() != line.text) {
    return false;
  }

  final lineDuration = lineEnd - line.start;
  var previousEnd = Duration.zero;
  for (final token in line.tokens) {
    if (token.startOffset < Duration.zero ||
        token.duration <= Duration.zero ||
        token.startOffset < previousEnd ||
        token.endOffset > lineDuration) {
      return false;
    }
    previousEnd = token.endOffset;
  }
  return true;
}

List<PartitaSemanticUnit> buildPartitaSemanticUnits(LyricLine line) {
  final timingIsValid = hasValidPartitaTokenTiming(line);
  final tokenTextMatches =
      line.tokens.map((token) => token.text).join() == line.text;
  final builders = line.tokens.isEmpty
      ? _buildTextUnitBuilders(line.text)
      : timingIsValid || tokenTextMatches
      ? _buildTokenUnitBuilders(line.tokens)
      : _buildTextUnitBuilders(line.text);
  final stickyBuilders = _applyStickyGrouping(builders);

  return List<PartitaSemanticUnit>.unmodifiable(
    stickyBuilders.indexed.map((entry) {
      final index = entry.$1;
      final builder = entry.$2;
      final start = timingIsValid && builder.sourceTokenIndexes.isNotEmpty
          ? line.start +
                line.tokens[builder.sourceTokenIndexes.first].startOffset
          : null;
      final end = timingIsValid && builder.sourceTokenIndexes.isNotEmpty
          ? line.start + line.tokens[builder.sourceTokenIndexes.last].endOffset
          : null;
      return PartitaSemanticUnit(
        index: index,
        text: builder.text,
        sourceTokenIndexes: List<int>.unmodifiable(builder.sourceTokenIndexes),
        rawTokens: List<LyricToken>.unmodifiable(builder.rawTokens),
        start: start,
        end: end,
        isSemantic: false,
        isSticky: builder.isSticky,
      );
    }),
  );
}

List<PartitaDisplayWord> buildPartitaDisplayWords(LyricLine line) {
  final units = buildPartitaSemanticUnits(line);
  final timingIsValid = hasValidPartitaTokenTiming(line);
  return List<PartitaDisplayWord>.unmodifiable(
    units.map((unit) => _displayWordForUnit(line, unit, timingIsValid)),
  );
}

String buildPartitaLineLayoutCacheKey({
  required String documentSignature,
  required int sourceLineIndex,
  required LyricLine line,
  required PartitaLyricLayoutOptions options,
}) {
  return <Object?>[
    'folia-partita-d5b8b24-v1',
    documentSignature,
    sourceLineIndex,
    _lineSignature(line),
    options.stageSize.width,
    options.stageSize.height,
    _textStyleMetricsKey(options.textStyle),
    options.textDirection.name,
    options.locale?.toLanguageTag(),
    options.textScaleFactor,
    options.horizontalInset,
    options.verticalInset,
    options.wordGap,
    options.chunkMarginBottom,
    options.staggerMin,
    options.staggerMax,
    options.guideLength,
    options.guideOverhang,
    options.hitSlop,
  ].join('\u0001');
}

PartitaLineLayout layoutPartitaLine({
  required LyricLine line,
  required int sourceLineIndex,
  required PartitaLyricLayoutOptions options,
  String cacheKey = '',
}) {
  final units = buildPartitaSemanticUnits(line);
  final hasFineTiming = hasValidPartitaTokenTiming(line);
  final wordsByUnit = <int, PartitaDisplayWord>{
    for (final unit in units)
      unit.index: _displayWordForUnit(line, unit, hasFineTiming),
  };
  final totalGraphemes = line.text.characters
      .where((grapheme) => grapheme.trim().isNotEmpty)
      .length;
  final stageBounds =
      Offset.zero &
      Size(
        math.max(options.stageSize.width, 0),
        math.max(options.stageSize.height, 0),
      );
  final auxiliaryText = line.translation.trim().isNotEmpty
      ? line.translation
      : (line.romanization.trim().isNotEmpty ? line.romanization : null);

  if (units.isEmpty || stageBounds.isEmpty) {
    return PartitaLineLayout(
      sourceLine: line,
      sourceLineIndex: sourceLineIndex,
      units: units,
      hasFineTiming: hasFineTiming,
      columns: const <PartitaColumnLayout>[],
      totalGraphemes: totalGraphemes,
      contentBounds: Rect.zero,
      visualBounds: Rect.zero,
      stageBounds: stageBounds,
      fitScale: 1,
      auxiliaryText: auxiliaryText,
      cacheKey: cacheKey,
    );
  }

  final chunks = _splitUnits(
    units,
    stageHeight: options.stageSize.height,
    seed: line.start.inMicroseconds / Duration.microsecondsPerSecond,
  );
  final random = _SeededSineRandom(
    line.start.inMicroseconds / Duration.microsecondsPerSecond,
  );
  for (var index = 0; index < chunks.length - 1; index++) {
    random.next();
  }

  final densityScale = totalGraphemes > 40 ? 0.8 : 1.0;
  final effectiveStyle = options.textStyle.copyWith(
    fontSize: (options.textStyle.fontSize ?? 48) * densityScale,
  );
  final drafts = <_DraftChunk>[];
  for (var rowIndex = 0; rowIndex < chunks.length; rowIndex++) {
    final chunkUnits = chunks[rowIndex];
    final displayWords = chunkUnits
        .map((unit) => wordsByUnit[unit.index]!)
        .toList(growable: false);
    final staggerRange = math.max(options.staggerMax - options.staggerMin, 0);
    final staggerMagnitude =
        math.min(options.staggerMin, options.staggerMax) +
        random.next() * staggerRange;
    final rowBias = rowIndex - (chunks.length - 1) / 2;
    final chunkScale = 0.8 + random.next() * 0.9;
    final transform = PartitaChunkTransform(
      offset: Offset(
        rowIndex.isEven ? -staggerMagnitude : staggerMagnitude,
        rowBias * 2.5,
      ),
      scale: chunkScale,
      rotation: 0,
      passedRotation: _degreesToRadians(rowIndex.isEven ? 3 : -3),
      marginBottom: math.max(options.chunkMarginBottom, 0),
    );
    drafts.add(
      _measureDraftChunk(
        line: line,
        rowIndex: rowIndex,
        units: chunkUnits,
        words: displayWords,
        transform: transform,
        style: effectiveStyle,
        options: options,
      ),
    );
  }

  var verticalCursor = 0.0;
  for (final draft in drafts) {
    final scaledHeight = draft.localBounds.height * draft.transform.scale;
    draft.sourceCenter = Offset(
      draft.transform.offset.dx,
      verticalCursor + scaledHeight / 2 + draft.transform.offset.dy,
    );
    verticalCursor += scaledHeight + draft.transform.marginBottom;
  }
  if (drafts.isNotEmpty) {
    verticalCursor -= drafts.last.transform.marginBottom;
  }
  final verticalShift = verticalCursor / 2;
  for (final draft in drafts) {
    draft.sourceCenter = draft.sourceCenter.translate(0, -verticalShift);
    draft.resolveSourceGeometry(options);
  }

  final sourceVisualBounds = _unionRects(
    drafts.map((draft) => draft.sourceVisualBounds),
  );
  final safeBounds = _safeStageBounds(stageBounds, options);
  final widthScale = sourceVisualBounds.width <= 0
      ? 1.0
      : safeBounds.width / sourceVisualBounds.width;
  final heightScale = sourceVisualBounds.height <= 0
      ? 1.0
      : safeBounds.height / sourceVisualBounds.height;
  final fitScale = math.min(1.0, math.min(widthScale, heightScale));
  final translation = safeBounds.center - sourceVisualBounds.center * fitScale;
  Offset mapPoint(Offset point) => point * fitScale + translation;

  final layouts = drafts
      .map(
        (draft) => draft.toLayout(
          fitScale: fitScale,
          mapPoint: mapPoint,
          stageBounds: stageBounds,
          hitSlop: options.hitSlop,
        ),
      )
      .toList(growable: false);
  final contentBounds = _boundedRect(
    _unionRects(layouts.map((chunk) => chunk.textBounds)),
    stageBounds,
  );
  final visualBounds = _boundedRect(
    _unionRects(layouts.map((chunk) => chunk.visualBounds)),
    stageBounds,
  );
  final column = PartitaColumnLayout(
    id: 'column-${line.start.inMicroseconds}-0',
    chunks: List<PartitaChunkLayout>.unmodifiable(layouts),
  );

  return PartitaLineLayout(
    sourceLine: line,
    sourceLineIndex: sourceLineIndex,
    units: units,
    hasFineTiming: hasFineTiming,
    columns: List<PartitaColumnLayout>.unmodifiable(<PartitaColumnLayout>[
      column,
    ]),
    totalGraphemes: totalGraphemes,
    contentBounds: contentBounds,
    visualBounds: visualBounds,
    stageBounds: stageBounds,
    fitScale: fitScale,
    auxiliaryText: auxiliaryText,
    cacheKey: cacheKey,
  );
}

class _MutableUnit {
  _MutableUnit();

  String text = '';
  final List<int> sourceTokenIndexes = <int>[];
  final List<LyricToken> rawTokens = <LyricToken>[];
  bool isSticky = false;

  void appendToken(int index, LyricToken token) {
    text += token.text;
    sourceTokenIndexes.add(index);
    rawTokens.add(token);
  }

  void appendText(String value) => text += value;

  void appendUnit(_MutableUnit other) {
    text += other.text;
    sourceTokenIndexes.addAll(other.sourceTokenIndexes);
    rawTokens.addAll(other.rawTokens);
    isSticky = true;
  }

  _MutableUnit copy() {
    return _MutableUnit()
      ..text = text
      ..sourceTokenIndexes.addAll(sourceTokenIndexes)
      ..rawTokens.addAll(rawTokens)
      ..isSticky = isSticky;
  }
}

List<_MutableUnit> _buildTokenUnitBuilders(List<LyricToken> tokens) {
  final units = <_MutableUnit>[];
  final pendingLeading = <(int, LyricToken)>[];
  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    if (token.text.trim().isEmpty) {
      if (units.isEmpty) {
        pendingLeading.add((index, token));
      } else {
        units.last.appendToken(index, token);
      }
      continue;
    }

    final unit = _MutableUnit();
    for (final pending in pendingLeading) {
      unit.appendToken(pending.$1, pending.$2);
    }
    pendingLeading.clear();
    unit.appendToken(index, token);
    units.add(unit);
  }
  if (pendingLeading.isNotEmpty && units.isNotEmpty) {
    for (final pending in pendingLeading) {
      units.last.appendToken(pending.$1, pending.$2);
    }
  }
  return units;
}

List<_MutableUnit> _buildTextUnitBuilders(String text) {
  final units = <_MutableUnit>[];
  var pendingWhitespace = '';
  var separatedByWhitespace = false;
  for (final grapheme in text.characters) {
    if (grapheme.trim().isEmpty) {
      if (units.isEmpty) {
        pendingWhitespace += grapheme;
      } else {
        units.last.appendText(grapheme);
      }
      separatedByWhitespace = true;
      continue;
    }

    final isCjk = _containsCjk(grapheme);
    final isPunctuation = _isStickyPunctuation(grapheme);
    final canJoinPrevious =
        units.isNotEmpty &&
        !separatedByWhitespace &&
        pendingWhitespace.isEmpty &&
        !isCjk &&
        !isPunctuation &&
        !_containsCjk(units.last.text) &&
        !_isStickyPunctuation(units.last.text.trim());
    if (canJoinPrevious) {
      units.last.appendText(grapheme);
    } else {
      units.add(_MutableUnit()..text = '$pendingWhitespace$grapheme');
      pendingWhitespace = '';
    }
    separatedByWhitespace = false;
  }
  if (pendingWhitespace.isNotEmpty && units.isNotEmpty) {
    units.last.appendText(pendingWhitespace);
  }
  return units;
}

List<_MutableUnit> _applyStickyGrouping(List<_MutableUnit> source) {
  final merged = <_MutableUnit>[];
  for (var index = 0; index < source.length; index++) {
    final current = source[index].copy();
    final previous = merged.isEmpty ? null : merged.last;
    if (previous == null) {
      merged.add(current);
      continue;
    }

    final next = index + 1 < source.length ? source[index + 1] : null;
    if (_isApostropheOnly(current.text) &&
        next != null &&
        _canAttachToPrevious(previous.text) &&
        _isContractionSuffix(next.text)) {
      previous
        ..appendUnit(current)
        ..appendUnit(next);
      index++;
      continue;
    }
    if (_isDirectContraction(current.text) &&
        _canAttachToPrevious(previous.text)) {
      previous.appendUnit(current);
      continue;
    }
    if (_isContractionSuffix(current.text) &&
        _endsWithApostrophe(previous.text)) {
      previous.appendUnit(current);
      continue;
    }
    if (_isStickyPunctuation(current.text.trim()) &&
        _canAttachToPrevious(previous.text)) {
      previous.appendUnit(current);
      continue;
    }
    merged.add(current);
  }
  return merged;
}

PartitaDisplayWord _displayWordForUnit(
  LyricLine line,
  PartitaSemanticUnit unit,
  bool timingIsValid,
) {
  final graphemes = <PartitaGraphemeSlice>[];
  final rawTokenText = unit.rawTokens.map((token) => token.text).join();
  final canUseTokenGraphemes =
      unit.sourceTokenIndexes.isNotEmpty && rawTokenText == unit.text;
  var textOffset = 0;
  if (canUseTokenGraphemes) {
    for (final sourceTokenIndex in unit.sourceTokenIndexes) {
      final token = line.tokens[sourceTokenIndex];
      final tokenGraphemes = token.text.characters.toList(growable: false);
      for (var index = 0; index < tokenGraphemes.length; index++) {
        final grapheme = tokenGraphemes[index];
        final startOffset = textOffset;
        textOffset += grapheme.length;
        Duration? start;
        Duration? end;
        if (timingIsValid) {
          final durationMicros = token.duration.inMicroseconds;
          start =
              line.start +
              token.startOffset +
              Duration(
                microseconds: durationMicros * index ~/ tokenGraphemes.length,
              );
          end =
              line.start +
              token.startOffset +
              Duration(
                microseconds: index == tokenGraphemes.length - 1
                    ? durationMicros
                    : durationMicros * (index + 1) ~/ tokenGraphemes.length,
              );
        }
        graphemes.add(
          PartitaGraphemeSlice(
            grapheme: grapheme,
            index: graphemes.length,
            textStartOffset: startOffset,
            textEndOffset: textOffset,
            sourceTokenIndex: sourceTokenIndex,
            start: start,
            end: end,
          ),
        );
      }
    }
  } else {
    for (final grapheme in unit.text.characters) {
      final startOffset = textOffset;
      textOffset += grapheme.length;
      graphemes.add(
        PartitaGraphemeSlice(
          grapheme: grapheme,
          index: graphemes.length,
          textStartOffset: startOffset,
          textEndOffset: textOffset,
          sourceTokenIndex: null,
          start: null,
          end: null,
        ),
      );
    }
  }

  return PartitaDisplayWord(
    id:
        '${line.start.inMicroseconds}:unit-${unit.index}:'
        '${unit.sourceTokenIndexes.join(',')}',
    text: unit.text,
    sourceTokenIndexes: unit.sourceTokenIndexes,
    rawTokens: unit.rawTokens,
    start: timingIsValid ? unit.start : null,
    end: timingIsValid ? unit.end : null,
    graphemes: List<PartitaGraphemeSlice>.unmodifiable(graphemes),
  );
}

List<List<PartitaSemanticUnit>> _splitUnits(
  List<PartitaSemanticUnit> units, {
  required double stageHeight,
  required double seed,
}) {
  if (units.isEmpty) return const <List<PartitaSemanticUnit>>[];
  final availableHeight = math.max(stageHeight, 0) * 0.65;
  final targetRowCount = math.max(1, (availableHeight / 100).floor());
  final actualRowCount = math.min(units.length, targetRowCount);
  final random = _SeededSineRandom(seed);
  final chunks = <List<PartitaSemanticUnit>>[];
  var remainingUnits = units.length;
  var remainingChunks = actualRowCount;
  var unitIndex = 0;

  for (var chunkIndex = 0; chunkIndex < actualRowCount; chunkIndex++) {
    final isLast = chunkIndex == actualRowCount - 1;
    final average = remainingUnits / remainingChunks;
    var chunkLength = 1;
    if (isLast) {
      chunkLength = remainingUnits;
    } else {
      final maximum = (average * 1.5).ceil();
      chunkLength = (average + (random.next() - 0.5) * average).round().clamp(
        1,
        maximum,
      );
    }
    chunkLength = chunkLength.clamp(1, remainingUnits - (remainingChunks - 1));
    chunks.add(
      List<PartitaSemanticUnit>.unmodifiable(
        units.sublist(unitIndex, unitIndex + chunkLength),
      ),
    );
    unitIndex += chunkLength;
    remainingUnits -= chunkLength;
    remainingChunks--;
  }
  return chunks;
}

class _SeededSineRandom {
  _SeededSineRandom(this._seed);

  double _seed;

  double next() {
    final value = math.sin(_seed++) * 10000;
    return value - value.floor();
  }
}

class _DraftWord {
  _DraftWord({
    required this.word,
    required this.transform,
    required this.textSize,
    required this.localCenter,
    required this.graphemeRects,
  });

  final PartitaDisplayWord word;
  final PartitaWordTransform transform;
  final Size textSize;
  final Offset localCenter;
  final List<Rect> graphemeRects;
}

class _DraftChunk {
  _DraftChunk({
    required this.rowIndex,
    required this.units,
    required this.words,
    required this.transform,
    required this.localBounds,
  });

  final int rowIndex;
  final List<PartitaSemanticUnit> units;
  final List<_DraftWord> words;
  final PartitaChunkTransform transform;
  final Rect localBounds;

  Offset sourceCenter = Offset.zero;
  Rect sourceTextBounds = Rect.zero;
  Rect sourceVisualBounds = Rect.zero;
  late List<PartitaGuideSegment> sourceGuideSegments;

  void resolveSourceGeometry(PartitaLyricLayoutOptions options) {
    final wordBounds = <Rect>[];
    final activeWordBounds = <Rect>[];
    for (final word in words) {
      final localDelta = word.localCenter - localBounds.center;
      final sourceWordCenter =
          sourceCenter +
          _rotateOffset(localDelta * transform.scale, transform.rotation);
      wordBounds.add(
        _rectAroundCenter(
          center: sourceWordCenter,
          size: word.textSize,
          scale: transform.scale,
          rotation: transform.rotation + word.transform.rotation,
        ),
      );
      activeWordBounds.add(
        _rectAroundCenter(
          center: sourceWordCenter,
          size: word.textSize,
          scale: transform.scale * partitaActiveWordScale,
          rotation: transform.rotation + word.transform.rotation,
        ),
      );
    }
    sourceTextBounds = _unionRects(wordBounds);
    final side = rowIndex.isEven
        ? PartitaGuideSide.left
        : PartitaGuideSide.right;
    final overhang = math.max(options.guideOverhang, 0);
    final guideLength = math.max(options.guideLength, 0);
    final guideX = side == PartitaGuideSide.left
        ? sourceTextBounds.left - 8
        : sourceTextBounds.right + 8;
    final guideY = sourceTextBounds.bottom + 8;
    final horizontalStart = side == PartitaGuideSide.left
        ? Offset(sourceTextBounds.left - overhang, guideY)
        : Offset(sourceTextBounds.right + overhang, guideY);
    final horizontalEnd = side == PartitaGuideSide.left
        ? Offset(sourceTextBounds.right + overhang, guideY)
        : Offset(sourceTextBounds.left - overhang, guideY);
    sourceGuideSegments = <PartitaGuideSegment>[
      PartitaGuideSegment(
        start: Offset(guideX, guideY - guideLength / 2),
        end: Offset(guideX, guideY + guideLength / 2),
      ),
      PartitaGuideSegment(start: horizontalStart, end: horizontalEnd),
    ];
    final guideBounds = _guideBounds(sourceGuideSegments, strokeWidth: 1);
    sourceVisualBounds = _unionRects(
      activeWordBounds,
    ).expandToInclude(guideBounds);
  }

  PartitaChunkLayout toLayout({
    required double fitScale,
    required Offset Function(Offset) mapPoint,
    required Rect stageBounds,
    required double hitSlop,
  }) {
    final wordLayouts = <PartitaWordLayout>[];
    final activeWordBounds = <Rect>[];
    for (final word in words) {
      final localDelta = word.localCenter - localBounds.center;
      final sourceWordCenter =
          sourceCenter +
          _rotateOffset(localDelta * transform.scale, transform.rotation);
      final finalCenter = mapPoint(sourceWordCenter);
      final finalScale = transform.scale * fitScale;
      final finalRotation = transform.rotation + word.transform.rotation;
      final graphemeGeometry = <PartitaGraphemeGeometry>[];
      for (var index = 0; index < word.word.graphemes.length; index++) {
        final localRect = word.graphemeRects[index];
        graphemeGeometry.add(
          PartitaGraphemeGeometry(
            slice: word.word.graphemes[index],
            localBounds: localRect,
            bounds: _transformTextRect(
              rect: localRect,
              textSize: word.textSize,
              center: finalCenter,
              scale: finalScale,
              rotation: finalRotation,
            ),
          ),
        );
      }
      final bounds = _rectAroundCenter(
        center: finalCenter,
        size: word.textSize,
        scale: finalScale,
        rotation: finalRotation,
      );
      activeWordBounds.add(
        _rectAroundCenter(
          center: finalCenter,
          size: word.textSize,
          scale: finalScale * partitaActiveWordScale,
          rotation: finalRotation,
        ),
      );
      wordLayouts.add(
        PartitaWordLayout(
          word: word.word,
          transform: word.transform,
          geometry: PartitaMeasuredWordGeometry(
            center: finalCenter,
            textSize: word.textSize,
            paintScale: finalScale,
            paintRotation: finalRotation,
            bounds: bounds,
            graphemes: List<PartitaGraphemeGeometry>.unmodifiable(
              graphemeGeometry,
            ),
          ),
        ),
      );
    }

    final textBounds = _boundedRect(
      _unionRects(wordLayouts.map((word) => word.geometry.bounds)),
      stageBounds,
    );
    final guideSegments = sourceGuideSegments
        .map(
          (segment) => PartitaGuideSegment(
            start: mapPoint(segment.start),
            end: mapPoint(segment.end),
          ),
        )
        .toList(growable: false);
    final guideBounds = _boundedRect(
      _guideBounds(guideSegments, strokeWidth: fitScale),
      stageBounds,
    );
    final visualBounds = _boundedRect(
      _unionRects(activeWordBounds).expandToInclude(guideBounds),
      stageBounds,
    );
    final sourceTokenIndexes = units
        .expand((unit) => unit.sourceTokenIndexes)
        .toList(growable: false);
    final rawTokens = units
        .expand((unit) => unit.rawTokens)
        .toList(growable: false);
    final timedWords = wordLayouts
        .map((word) => word.word)
        .toList(growable: false);
    final allTimed =
        timedWords.isNotEmpty && timedWords.every((word) => word.isTimed);

    return PartitaChunkLayout(
      rowIndex: rowIndex,
      units: List<PartitaSemanticUnit>.unmodifiable(units),
      sourceTokenIndexes: List<int>.unmodifiable(sourceTokenIndexes),
      rawTokens: List<LyricToken>.unmodifiable(rawTokens),
      words: List<PartitaWordLayout>.unmodifiable(wordLayouts),
      start: allTimed ? timedWords.first.start : null,
      end: allTimed ? timedWords.last.end : null,
      transform: PartitaChunkTransform(
        offset: transform.offset * fitScale,
        scale: transform.scale * fitScale,
        rotation: transform.rotation,
        passedRotation: transform.passedRotation,
        marginBottom: transform.marginBottom * fitScale,
      ),
      guide: PartitaGuideLayout(
        side: rowIndex.isEven ? PartitaGuideSide.left : PartitaGuideSide.right,
        segments: List<PartitaGuideSegment>.unmodifiable(guideSegments),
        bounds: guideBounds,
      ),
      textBounds: textBounds,
      visualBounds: visualBounds,
      hitRect: _boundedRect(
        visualBounds.inflate(math.max(hitSlop, 0)),
        stageBounds,
      ),
    );
  }
}

_DraftChunk _measureDraftChunk({
  required LyricLine line,
  required int rowIndex,
  required List<PartitaSemanticUnit> units,
  required List<PartitaDisplayWord> words,
  required PartitaChunkTransform transform,
  required TextStyle style,
  required PartitaLyricLayoutOptions options,
}) {
  final measured = <({PartitaDisplayWord word, Size size, List<Rect> boxes})>[];
  for (final word in words) {
    final painter = TextPainter(
      text: TextSpan(text: word.text, style: style),
      textDirection: options.textDirection,
      locale: options.locale,
      textScaler: TextScaler.linear(options.textScaleFactor),
      maxLines: 1,
    )..layout();
    final graphemeRects = word.graphemes
        .map((slice) {
          final boxes = painter.getBoxesForSelection(
            TextSelection(
              baseOffset: slice.textStartOffset,
              extentOffset: slice.textEndOffset,
            ),
          );
          if (boxes.isNotEmpty) {
            return boxes
                .map((box) => box.toRect())
                .reduce((first, second) => first.expandToInclude(second));
          }
          final width = word.graphemes.isEmpty
              ? painter.width
              : painter.width / word.graphemes.length;
          return Rect.fromLTWH(width * slice.index, 0, width, painter.height);
        })
        .toList(growable: false);
    measured.add((word: word, size: painter.size, boxes: graphemeRects));
  }

  var cursor = 0.0;
  var rowTop = 0.0;
  var rowHeight = 0.0;
  final draftWords = <_DraftWord>[];
  final localBounds = <Rect>[];
  const activeWordAdvanceScale = partitaActiveWordScale;
  final availableWidth = math.max(
    options.stageSize.width -
        (options.horizontalInset + options.guideOverhang) * 2,
    1.0,
  );
  final maxLocalWidth = availableWidth / math.max(transform.scale, 0.1);
  final wordGap = math.max(options.wordGap, 0);
  final chunkWordSeed =
      (words.first.start ?? line.start).inMicroseconds /
      Duration.microsecondsPerSecond;
  for (var index = 0; index < measured.length; index++) {
    final value = measured[index];
    final reservedWidth = value.size.width * activeWordAdvanceScale;
    final reservedHeight = value.size.height * activeWordAdvanceScale;
    if (cursor > 0 && cursor + reservedWidth > maxLocalWidth) {
      cursor = 0;
      rowTop += rowHeight + wordGap * 0.55;
      rowHeight = 0;
    }
    final seed = chunkWordSeed + index * 7.13;
    double random(double offset) {
      final result = math.sin(seed + offset) * 10000;
      return result - result.floor();
    }

    final wordTransform = PartitaWordTransform(
      offset: Offset((random(1) - 0.5) * 12, (random(2) - 0.5) * 12),
      rotation: _degreesToRadians((random(3) - 0.5) * 6),
      passedRotation: _degreesToRadians((random(8) - 0.5) * 20),
    );
    final center = Offset(
      cursor + reservedWidth / 2 + wordTransform.offset.dx,
      rowTop + reservedHeight / 2 + wordTransform.offset.dy,
    );
    final bounds = _rectAroundCenter(
      center: center,
      size: value.size,
      scale: 1,
      rotation: wordTransform.rotation,
    );
    draftWords.add(
      _DraftWord(
        word: value.word,
        transform: wordTransform,
        textSize: value.size,
        localCenter: center,
        graphemeRects: value.boxes,
      ),
    );
    localBounds.add(bounds);
    cursor += reservedWidth;
    rowHeight = math.max(rowHeight, reservedHeight);
    if (index + 1 < measured.length) cursor += wordGap;
  }
  if (options.textDirection == TextDirection.rtl && draftWords.length > 1) {
    final bounds = _unionRects(localBounds);
    final mirroredWords = draftWords
        .map(
          (word) => _DraftWord(
            word: word.word,
            transform: word.transform,
            textSize: word.textSize,
            localCenter: Offset(
              bounds.left + bounds.right - word.localCenter.dx,
              word.localCenter.dy,
            ),
            graphemeRects: word.graphemeRects,
          ),
        )
        .toList(growable: false);
    draftWords
      ..clear()
      ..addAll(mirroredWords);
    localBounds
      ..clear()
      ..addAll(
        draftWords.map(
          (word) => _rectAroundCenter(
            center: word.localCenter,
            size: word.textSize,
            scale: 1,
            rotation: word.transform.rotation,
          ),
        ),
      );
  }

  return _DraftChunk(
    rowIndex: rowIndex,
    units: units,
    words: draftWords,
    transform: transform,
    localBounds: _unionRects(localBounds),
  );
}

int _lastStartedLineIndex(List<LyricLine> lines, Duration position) {
  var low = 0;
  var high = lines.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (lines[middle].start <= position) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low - 1;
}

Rect _safeStageBounds(Rect stageBounds, PartitaLyricLayoutOptions options) {
  final horizontalInset = math.max(options.horizontalInset, 0);
  final verticalInset = math.max(options.verticalInset, 0);
  if (horizontalInset * 2 >= stageBounds.width ||
      verticalInset * 2 >= stageBounds.height) {
    return stageBounds;
  }
  return Rect.fromLTRB(
    stageBounds.left + horizontalInset,
    stageBounds.top + verticalInset,
    stageBounds.right - horizontalInset,
    stageBounds.bottom - verticalInset,
  );
}

Rect _rectAroundCenter({
  required Offset center,
  required Size size,
  required double scale,
  required double rotation,
}) {
  final halfWidth = size.width * scale / 2;
  final halfHeight = size.height * scale / 2;
  final cosine = math.cos(rotation).abs();
  final sine = math.sin(rotation).abs();
  final extentX = halfWidth * cosine + halfHeight * sine;
  final extentY = halfWidth * sine + halfHeight * cosine;
  return Rect.fromLTRB(
    center.dx - extentX,
    center.dy - extentY,
    center.dx + extentX,
    center.dy + extentY,
  );
}

Rect _transformTextRect({
  required Rect rect,
  required Size textSize,
  required Offset center,
  required double scale,
  required double rotation,
}) {
  final textCenter = Offset(textSize.width / 2, textSize.height / 2);
  final corners =
      <Offset>[
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ].map((point) {
        return center + _rotateOffset((point - textCenter) * scale, rotation);
      });
  return Rect.fromPoints(
    Offset(
      corners.map((point) => point.dx).reduce(math.min),
      corners.map((point) => point.dy).reduce(math.min),
    ),
    Offset(
      corners.map((point) => point.dx).reduce(math.max),
      corners.map((point) => point.dy).reduce(math.max),
    ),
  );
}

Offset _rotateOffset(Offset offset, double rotation) {
  final cosine = math.cos(rotation);
  final sine = math.sin(rotation);
  return Offset(
    offset.dx * cosine - offset.dy * sine,
    offset.dx * sine + offset.dy * cosine,
  );
}

Rect _guideBounds(
  Iterable<PartitaGuideSegment> segments, {
  required double strokeWidth,
}) {
  final rects = segments.map((segment) => segment.bounds);
  if (rects.isEmpty) return Rect.zero;
  return _unionRects(rects).inflate(math.max(strokeWidth, 0) / 2);
}

Rect _unionRects(Iterable<Rect> rects) {
  final iterator = rects.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var result = iterator.current;
  while (iterator.moveNext()) {
    result = result.expandToInclude(iterator.current);
  }
  return result;
}

Rect _boundedRect(Rect rect, Rect bounds) {
  if (rect.isEmpty || bounds.isEmpty) return Rect.zero;
  final left = math.max(rect.left, bounds.left);
  final top = math.max(rect.top, bounds.top);
  final right = math.min(rect.right, bounds.right);
  final bottom = math.min(rect.bottom, bounds.bottom);
  if (right <= left || bottom <= top) return Rect.zero;
  return Rect.fromLTRB(left, top, right, bottom);
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

bool _containsCjk(String text) =>
    RegExp(r'[\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]').hasMatch(text);

const _stickyPunctuation = ',.;:!?，。！？、：；）】》」』〉〕］)}]"\'’”';

bool _isStickyPunctuation(String text) {
  final trimmed = text.trim();
  return trimmed.isNotEmpty &&
      trimmed.characters.every(_stickyPunctuation.contains);
}

bool _isApostropheOnly(String text) {
  final trimmed = text.trim();
  return trimmed == "'" || trimmed == '’';
}

bool _isContractionSuffix(String text) => RegExp(
  r'^(s|t|m|d|ll|re|ve|em)$',
  caseSensitive: false,
).hasMatch(text.trim());

bool _isDirectContraction(String text) => RegExp(
  r"^['’](s|t|m|d|ll|re|ve|em)$",
  caseSensitive: false,
).hasMatch(text.trim());

bool _endsWithApostrophe(String text) {
  final trimmed = text.trimRight();
  return trimmed.endsWith("'") || trimmed.endsWith('’');
}

bool _canAttachToPrevious(String text) {
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return false;
  final last = trimmed.characters.last;
  return !_isStickyPunctuation(last) && !_isApostropheOnly(last);
}

String _buildDocumentSignature(LyricDocument document) {
  return <String>[
    'offset=${document.offset}',
    for (var index = 0; index < document.lines.length; index++)
      '$index:${_lineSignature(document.lines[index])}',
  ].join('|');
}

String _lineSignature(LyricLine line) {
  final tokens = line.tokens
      .map(
        (token) =>
            '${_encode(token.text)}@'
            '${token.startOffset.inMicroseconds}+'
            '${token.duration.inMicroseconds}',
      )
      .join(';');
  return '${line.start.inMicroseconds}:${line.end?.inMicroseconds ?? -1}:'
      '${_encode(line.text)}:${_encode(line.translation)}:'
      '${_encode(line.romanization)}:$tokens';
}

String _textStyleMetricsKey(TextStyle style) => <Object?>[
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
].join('|');

String _encode(String value) => '${value.length}:$value';
