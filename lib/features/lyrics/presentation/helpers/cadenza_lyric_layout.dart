import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';

const double cadenzaActiveWordScale = 1.3;
const double cadenzaDefaultFontScale = 1.12;
const double cadenzaDefaultWidthRatio = 0.72;

const String _cadenzaInterludeText = '......';
const Duration _cadenzaInterludeGap = Duration(seconds: 3);
const Duration _cadenzaLeadingInset = Duration(milliseconds: 500);
const Duration _cadenzaGapInset = Duration(milliseconds: 50);

enum CadenzaTimingClass { normal, short, micro }

enum CadenzaRevealProfile { normal, fast, instant }

CadenzaTimingClass resolveCadenzaTimingClass(LyricLine line) {
  final end = line.end;
  if (end == null) return CadenzaTimingClass.normal;
  final duration = end > line.start ? end - line.start : Duration.zero;
  if (duration < const Duration(milliseconds: 100)) {
    return CadenzaTimingClass.micro;
  }
  if (duration < const Duration(milliseconds: 180)) {
    return CadenzaTimingClass.short;
  }
  return CadenzaTimingClass.normal;
}

CadenzaRevealProfile resolveCadenzaRevealProfile(LyricLine line) {
  return switch (resolveCadenzaTimingClass(line)) {
    CadenzaTimingClass.normal => CadenzaRevealProfile.normal,
    CadenzaTimingClass.short => CadenzaRevealProfile.fast,
    CadenzaTimingClass.micro => CadenzaRevealProfile.instant,
  };
}

Duration resolveCadenzaLineTransitionDuration(LyricLine line) {
  return switch (resolveCadenzaTimingClass(line)) {
    CadenzaTimingClass.normal => const Duration(milliseconds: 300),
    CadenzaTimingClass.short => const Duration(milliseconds: 160),
    CadenzaTimingClass.micro => Duration.zero,
  };
}

Duration resolveCadenzaLookahead(CadenzaTimingClass timingClass) {
  return switch (timingClass) {
    CadenzaTimingClass.normal => const Duration(milliseconds: 180),
    CadenzaTimingClass.short => const Duration(milliseconds: 45),
    CadenzaTimingClass.micro => Duration.zero,
  };
}

Duration? resolveCadenzaLineRenderEnd(LyricLine line) {
  final end = line.end;
  if (end == null) return null;
  final rawDuration = end > line.start ? end - line.start : Duration.zero;
  final lastWordEnd = hasValidCadenzaTokenTiming(line)
      ? _lastValidTokenEnd(line) ?? end
      : end;
  switch (resolveCadenzaTimingClass(line)) {
    case CadenzaTimingClass.micro:
      return _maxDuration(end, line.start + const Duration(milliseconds: 67));
    case CadenzaTimingClass.short:
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
      final passStart =
          _maxDuration(lastWordEnd, line.start) +
          const Duration(milliseconds: 30);
      final exitStart = _maxDuration(
        line.start + enter + const Duration(milliseconds: 10),
        _maxDuration(passStart, end - exit),
      );
      return _maxDuration(end, exitStart + exit);
    case CadenzaTimingClass.normal:
      final exit = Duration(
        microseconds: (rawDuration.inMicroseconds * 0.18).round().clamp(
          180000,
          320000,
        ),
      );
      final passStart =
          _maxDuration(lastWordEnd, line.start) +
          const Duration(milliseconds: 60);
      final exitStart = _maxDuration(passStart, end - exit);
      return _maxDuration(end, exitStart + exit);
  }
}

Duration? resolveCadenzaWordActiveEnd({
  required LyricLine line,
  required Duration? start,
  required Duration? end,
}) {
  if (start == null || end == null) return end;
  final renderEnd = resolveCadenzaLineRenderEnd(line) ?? line.end;
  return switch (resolveCadenzaTimingClass(line)) {
    CadenzaTimingClass.normal => end,
    CadenzaTimingClass.short =>
      renderEnd == null
          ? _maxDuration(end, start + const Duration(milliseconds: 120))
          : _minDuration(
              renderEnd,
              _maxDuration(end, start + const Duration(milliseconds: 120)),
            ),
    CadenzaTimingClass.micro => renderEnd ?? end,
  };
}

@immutable
class CadenzaLyricPosition {
  const CadenzaLyricPosition({
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

class CadenzaLyricLayoutEngine {
  CadenzaLyricLayoutEngine(this.document)
    : documentSignature = _buildDocumentSignature(document),
      _renderLines = _buildCadenzaRenderableLines(document.lines);

  factory CadenzaLyricLayoutEngine.fromDocument(LyricDocument document) {
    return CadenzaLyricLayoutEngine(document);
  }

  final LyricDocument document;
  final String documentSignature;
  final List<_CadenzaRenderableLine> _renderLines;

  int get lineCount => _renderLines.length;

  LyricLine? lineAt(int index) {
    if (index < 0 || index >= _renderLines.length) return null;
    return _renderLines[index].line;
  }

  bool isInterludeAt(int index) {
    if (index < 0 || index >= _renderLines.length) return false;
    return _renderLines[index].isInterlude;
  }

  CadenzaLyricPosition resolvePosition(Duration playbackPosition) {
    final timelinePosition =
        playbackPosition + Duration(milliseconds: document.offset);
    if (_renderLines.isEmpty) {
      return CadenzaLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: null,
      );
    }

    final lastStartedIndex = _lastStartedLineIndex(
      _renderLines,
      timelinePosition,
    );
    if (lastStartedIndex < 0) {
      return CadenzaLyricPosition(
        playbackPosition: playbackPosition,
        timelinePosition: timelinePosition,
        activeIndex: null,
        recentIndex: null,
        upcomingIndex: 0,
      );
    }

    int? activeIndex;
    for (var index = lastStartedIndex; index >= 0; index--) {
      final renderEnd = resolveCadenzaLineRenderEnd(_renderLines[index].line);
      if (renderEnd == null || timelinePosition <= renderEnd) {
        activeIndex = index;
        break;
      }
    }
    final upcomingIndex = lastStartedIndex + 1 < _renderLines.length
        ? lastStartedIndex + 1
        : null;
    final recentIndex = activeIndex == null
        ? lastStartedIndex
        : lastStartedIndex == activeIndex
        ? (activeIndex > 0 ? activeIndex - 1 : null)
        : lastStartedIndex;
    return CadenzaLyricPosition(
      playbackPosition: playbackPosition,
      timelinePosition: timelinePosition,
      activeIndex: activeIndex,
      recentIndex: recentIndex,
      upcomingIndex: upcomingIndex,
    );
  }

  CadenzaLineLayout? layoutLine({
    required int renderLineIndex,
    required CadenzaLyricLayoutOptions options,
    CadenzaLyricLayoutCache? cache,
  }) {
    if (renderLineIndex < 0 || renderLineIndex >= _renderLines.length) {
      return null;
    }
    final renderLine = _renderLines[renderLineIndex];
    final cacheKey = buildCadenzaLineLayoutCacheKey(
      documentSignature: documentSignature,
      renderLineIndex: renderLineIndex,
      line: renderLine.line,
      options: options,
    );
    CadenzaLineLayout build() => layoutCadenzaLine(
      line: renderLine.line,
      sourceLineIndex: renderLine.sourceIndex ?? -1,
      isInterlude: renderLine.isInterlude,
      options: options,
      cacheKey: cacheKey,
    );

    return cache?.resolve(cacheKey, build) ?? build();
  }
}

class _CadenzaRenderableLine {
  const _CadenzaRenderableLine({
    required this.line,
    required this.sourceIndex,
    required this.isInterlude,
  });

  final LyricLine line;
  final int? sourceIndex;
  final bool isInterlude;
}

@immutable
class CadenzaGraphemeSlice {
  const CadenzaGraphemeSlice({
    required this.grapheme,
    required this.indexInWord,
    required this.textStartOffset,
    required this.textEndOffset,
    required this.sourceTokenIndex,
    required this.start,
    required this.end,
  });

  final String grapheme;
  final int indexInWord;
  final int textStartOffset;
  final int textEndOffset;
  final int? sourceTokenIndex;
  final Duration? start;
  final Duration? end;

  bool get isTimed => start != null && end != null && end! > start!;
}

@immutable
class CadenzaDisplayWord {
  const CadenzaDisplayWord({
    required this.id,
    required this.text,
    required this.textStartOffset,
    required this.textEndOffset,
    required this.sourceTokenIndexes,
    required this.start,
    required this.end,
    required this.graphemes,
  });

  final String id;
  final String text;
  final int textStartOffset;
  final int textEndOffset;
  final List<int> sourceTokenIndexes;
  final Duration? start;
  final Duration? end;
  final List<CadenzaGraphemeSlice> graphemes;

  bool get isTimed => start != null && end != null && end! > start!;
}

@immutable
class CadenzaGraphemeGeometry {
  const CadenzaGraphemeGeometry({
    required this.slice,
    required this.localBounds,
    required this.bounds,
  });

  final CadenzaGraphemeSlice slice;
  final Rect localBounds;
  final Rect bounds;
}

@immutable
class CadenzaWordFragment {
  const CadenzaWordFragment({
    required this.id,
    required this.word,
    required this.wordIndex,
    required this.text,
    required this.lineIndex,
    required this.fragmentIndexInWord,
    required this.fragmentCountInWord,
    required this.fragmentStartInWord,
    required this.fragmentEndInWord,
    required this.isPrimaryFragment,
    required this.isSplitAcrossLines,
    required this.center,
    required this.textSize,
    required this.paintScale,
    required this.rotation,
    required this.passedRotation,
    required this.passedDrift,
    required this.bounds,
    required this.visualBounds,
    required this.hitRect,
    required this.graphemes,
  });

  final String id;
  final CadenzaDisplayWord word;
  final int wordIndex;
  final String text;
  final int lineIndex;
  final int fragmentIndexInWord;
  final int fragmentCountInWord;
  final int fragmentStartInWord;
  final int fragmentEndInWord;
  final bool isPrimaryFragment;
  final bool isSplitAcrossLines;
  final Offset center;
  final Size textSize;
  final double paintScale;
  final double rotation;
  final double passedRotation;
  final Offset passedDrift;
  final Rect bounds;
  final Rect visualBounds;
  final Rect hitRect;
  final List<CadenzaGraphemeGeometry> graphemes;

  Duration? get start {
    for (final grapheme in graphemes) {
      if (grapheme.slice.start != null) return grapheme.slice.start;
    }
    return word.start;
  }

  Duration? get end {
    for (final grapheme in graphemes.reversed) {
      if (grapheme.slice.end != null) return grapheme.slice.end;
    }
    return word.end;
  }
}

@immutable
class CadenzaLineLayout {
  const CadenzaLineLayout({
    required this.sourceLine,
    required this.sourceLineIndex,
    required this.isInterlude,
    required this.hasFineTiming,
    required this.timingClass,
    required this.displayWords,
    required this.fragments,
    required this.heroWordIndex,
    required this.totalGraphemes,
    required this.effectiveTextStyle,
    required this.contentBounds,
    required this.visualBounds,
    required this.stageBounds,
    required this.fitScale,
    required this.auxiliaryText,
    required this.cacheKey,
  });

  final LyricLine sourceLine;
  final int sourceLineIndex;
  final bool isInterlude;
  final bool hasFineTiming;
  final CadenzaTimingClass timingClass;
  final List<CadenzaDisplayWord> displayWords;
  final List<CadenzaWordFragment> fragments;
  final int? heroWordIndex;
  final int totalGraphemes;
  final TextStyle effectiveTextStyle;
  final Rect contentBounds;
  final Rect visualBounds;
  final Rect stageBounds;
  final double fitScale;
  final String? auxiliaryText;
  final String cacheKey;
}

@immutable
class CadenzaLyricLayoutOptions {
  const CadenzaLyricLayoutOptions({
    required this.stageSize,
    required this.textStyle,
    this.textDirection = TextDirection.ltr,
    this.locale,
    this.textScaleFactor = 1,
    this.fontScale = cadenzaDefaultFontScale,
    this.widthRatio = cadenzaDefaultWidthRatio,
    this.horizontalInset = 24,
    this.verticalInset = 20,
    this.hitSlop = 10,
  });

  final Size stageSize;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final Locale? locale;
  final double textScaleFactor;
  final double fontScale;
  final double widthRatio;
  final double horizontalInset;
  final double verticalInset;
  final double hitSlop;
}

class CadenzaLyricLayoutCache {
  CadenzaLyricLayoutCache({this.maximumEntries = 48});

  final int maximumEntries;
  final Map<String, CadenzaLineLayout> _values = <String, CadenzaLineLayout>{};

  int get length => _values.length;

  CadenzaLineLayout resolve(String key, CadenzaLineLayout Function() build) {
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

bool hasValidCadenzaTokenTiming(LyricLine line) {
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

List<CadenzaDisplayWord> buildCadenzaDisplayWords(LyricLine line) {
  final timingIsValid = hasValidCadenzaTokenTiming(line);
  final tokenTextMatches =
      line.tokens.map((token) => token.text).join() == line.text;
  final builders = line.tokens.isNotEmpty && tokenTextMatches
      ? _buildTokenWordBuilders(line.tokens)
      : _buildTextWordBuilders(line.text);
  final merged = _applyStickyGrouping(builders);
  return List<CadenzaDisplayWord>.unmodifiable(
    merged.indexed.map((entry) {
      final index = entry.$1;
      final builder = entry.$2;
      final graphemes = <CadenzaGraphemeSlice>[];
      for (final piece in builder.pieces) {
        final pieceGraphemes = piece.text.characters.toList(growable: false);
        var offset = piece.textStartOffset;
        for (
          var graphemeIndex = 0;
          graphemeIndex < pieceGraphemes.length;
          graphemeIndex++
        ) {
          final grapheme = pieceGraphemes[graphemeIndex];
          final textStartOffset = offset;
          offset += grapheme.length;
          Duration? start;
          Duration? end;
          final tokenIndex = piece.sourceTokenIndex;
          if (timingIsValid && tokenIndex != null) {
            final token = line.tokens[tokenIndex];
            final durationMicros = token.duration.inMicroseconds;
            start =
                line.start +
                token.startOffset +
                Duration(
                  microseconds:
                      durationMicros * graphemeIndex ~/ pieceGraphemes.length,
                );
            end =
                line.start +
                token.startOffset +
                Duration(
                  microseconds: graphemeIndex == pieceGraphemes.length - 1
                      ? durationMicros
                      : durationMicros *
                            (graphemeIndex + 1) ~/
                            pieceGraphemes.length,
                );
          }
          graphemes.add(
            CadenzaGraphemeSlice(
              grapheme: grapheme,
              indexInWord: graphemes.length,
              textStartOffset: textStartOffset,
              textEndOffset: offset,
              sourceTokenIndex: tokenIndex,
              start: start,
              end: end,
            ),
          );
        }
      }
      final start = timingIsValid && builder.sourceTokenIndexes.isNotEmpty
          ? line.start +
                line.tokens[builder.sourceTokenIndexes.first].startOffset
          : null;
      final end = timingIsValid && builder.sourceTokenIndexes.isNotEmpty
          ? line.start + line.tokens[builder.sourceTokenIndexes.last].endOffset
          : null;
      return CadenzaDisplayWord(
        id:
            '${line.start.inMicroseconds}:word-$index:'
            '${builder.sourceTokenIndexes.join(',')}',
        text: builder.text,
        textStartOffset: builder.textStartOffset,
        textEndOffset: builder.textEndOffset,
        sourceTokenIndexes: List<int>.unmodifiable(builder.sourceTokenIndexes),
        start: start,
        end: end,
        graphemes: List<CadenzaGraphemeSlice>.unmodifiable(graphemes),
      );
    }),
  );
}

String buildCadenzaLineLayoutCacheKey({
  required String documentSignature,
  required int renderLineIndex,
  required LyricLine line,
  required CadenzaLyricLayoutOptions options,
}) {
  return <Object?>[
    'folia-cadenza-d5b8b24-v1',
    documentSignature,
    renderLineIndex,
    _lineSignature(line),
    options.stageSize.width,
    options.stageSize.height,
    _textStyleMetricsKey(options.textStyle),
    options.textDirection.name,
    options.locale?.toLanguageTag(),
    options.textScaleFactor,
    options.fontScale,
    options.widthRatio,
    options.horizontalInset,
    options.verticalInset,
    options.hitSlop,
  ].join('\u0001');
}

CadenzaLineLayout layoutCadenzaLine({
  required LyricLine line,
  required int sourceLineIndex,
  required bool isInterlude,
  required CadenzaLyricLayoutOptions options,
  String cacheKey = '',
}) {
  final stageBounds =
      Offset.zero &
      Size(
        math.max(options.stageSize.width, 0),
        math.max(options.stageSize.height, 0),
      );
  final displayWords = buildCadenzaDisplayWords(line);
  final totalGraphemes = line.text.characters.length;
  final auxiliaryText = line.translation.trim().isNotEmpty
      ? line.translation
      : (line.romanization.trim().isNotEmpty ? line.romanization : null);
  final timingClass = resolveCadenzaTimingClass(line);
  final effectiveTextStyle = _effectiveTextStyle(
    line: line,
    options: options,
    wordCount: displayWords.length,
    graphemeCount: totalGraphemes,
  );

  if (line.text.isEmpty || stageBounds.isEmpty || displayWords.isEmpty) {
    return CadenzaLineLayout(
      sourceLine: line,
      sourceLineIndex: sourceLineIndex,
      isInterlude: isInterlude,
      hasFineTiming: hasValidCadenzaTokenTiming(line),
      timingClass: timingClass,
      displayWords: displayWords,
      fragments: const <CadenzaWordFragment>[],
      heroWordIndex: null,
      totalGraphemes: totalGraphemes,
      effectiveTextStyle: effectiveTextStyle,
      contentBounds: Rect.zero,
      visualBounds: Rect.zero,
      stageBounds: stageBounds,
      fitScale: 1,
      auxiliaryText: auxiliaryText,
      cacheKey: cacheKey,
    );
  }

  final safeBounds = _safeStageBounds(stageBounds, options);
  final fontPx = effectiveTextStyle.fontSize ?? 48;
  final availableWidth = math.max(stageBounds.width - 48, 120.0);
  final minimumWidth = math.min(220.0, availableWidth);
  final wrapCompression = totalGraphemes > 12
      ? (0.92 - (totalGraphemes - 12) * 0.018).clamp(0.62, 0.92)
      : 0.92;
  final compactWidthRatio = options.widthRatio * wrapCompression;
  final maxWidth = math.min(
    availableWidth,
    math.max(
      minimumWidth,
      math.min(stageBounds.width * compactWidthRatio, 820.0),
    ),
  );
  final fullPainter = TextPainter(
    text: TextSpan(text: line.text, style: effectiveTextStyle),
    textDirection: options.textDirection,
    locale: options.locale,
    textScaler: TextScaler.linear(options.textScaleFactor),
  )..layout(maxWidth: math.max(maxWidth, 1));
  final lineMetrics = fullPainter.computeLineMetrics();
  final drafts = _buildFragmentDrafts(
    words: displayWords,
    fullPainter: fullPainter,
    lineMetrics: lineMetrics,
    style: effectiveTextStyle,
    options: options,
  );
  final heroWordIndex = _selectHeroWordIndex(drafts, isInterlude);
  final placed = _placeFragments(
    drafts: drafts,
    heroWordIndex: heroWordIndex,
    fontPx: fontPx,
    lineHeight: fontPx * (_containsCjk(line.text) ? 1.22 : 1.1),
    maxWidth: maxWidth,
    seed: line.start.inMicroseconds / Duration.microsecondsPerSecond.toDouble(),
    isInterlude: isInterlude,
  );

  final sourceVisualBounds = _unionRects(
    placed.map((fragment) => fragment.maximumVisualBounds),
  );
  final widthScale = sourceVisualBounds.width <= 0
      ? 1.0
      : safeBounds.width / sourceVisualBounds.width;
  final heightScale = sourceVisualBounds.height <= 0
      ? 1.0
      : safeBounds.height / sourceVisualBounds.height;
  final fitScale = math.min(1.0, math.min(widthScale, heightScale));
  final desiredFocus = Offset(
    safeBounds.center.dx,
    safeBounds.top + safeBounds.height * 0.42,
  );
  var translation = desiredFocus - sourceVisualBounds.center * fitScale;
  final minDx = safeBounds.right - sourceVisualBounds.right * fitScale;
  final maxDx = safeBounds.left - sourceVisualBounds.left * fitScale;
  final minDy = safeBounds.bottom - sourceVisualBounds.bottom * fitScale;
  final maxDy = safeBounds.top - sourceVisualBounds.top * fitScale;
  translation = Offset(
    _clampBetween(translation.dx, minDx, maxDx),
    _clampBetween(translation.dy, minDy, maxDy),
  );
  Offset mapPoint(Offset point) => point * fitScale + translation;

  final fragments = placed
      .map(
        (fragment) => fragment.toLayout(
          fitScale: fitScale,
          mapPoint: mapPoint,
          stageBounds: stageBounds,
          hitSlop: options.hitSlop,
        ),
      )
      .toList(growable: false);
  final contentBounds = _boundedRect(
    _unionRects(fragments.map((fragment) => fragment.bounds)),
    stageBounds,
  );
  final visualBounds = _boundedRect(
    _unionRects(fragments.map((fragment) => fragment.visualBounds)),
    stageBounds,
  );

  return CadenzaLineLayout(
    sourceLine: line,
    sourceLineIndex: sourceLineIndex,
    isInterlude: isInterlude,
    hasFineTiming: hasValidCadenzaTokenTiming(line),
    timingClass: timingClass,
    displayWords: displayWords,
    fragments: List<CadenzaWordFragment>.unmodifiable(fragments),
    heroWordIndex: heroWordIndex,
    totalGraphemes: totalGraphemes,
    effectiveTextStyle: effectiveTextStyle,
    contentBounds: contentBounds,
    visualBounds: visualBounds,
    stageBounds: stageBounds,
    fitScale: fitScale,
    auxiliaryText: auxiliaryText,
    cacheKey: cacheKey,
  );
}

TextStyle _effectiveTextStyle({
  required LyricLine line,
  required CadenzaLyricLayoutOptions options,
  required int wordCount,
  required int graphemeCount,
}) {
  final widthBase = (options.stageSize.width * 0.086).clamp(34.0, 94.0);
  final lengthPenalty = graphemeCount > 12
      ? math.min((graphemeCount - 12) * 1.8, 34.0)
      : 0.0;
  final densityPenalty = wordCount > 7
      ? math.min((wordCount - 7) * 1.5, 18.0)
      : 0.0;
  final sourceFont = (widthBase - lengthPenalty - densityPenalty).clamp(
    28.0,
    104.0,
  );
  final sharedFontScale = (options.textStyle.fontSize ?? 48) / 48;
  final fontPx = (sourceFont * options.fontScale * sharedFontScale).clamp(
    24.0,
    132.0,
  );
  return options.textStyle.copyWith(
    fontSize: fontPx,
    fontWeight: FontWeight.w700,
    height: _containsCjk(line.text) ? 1.22 : 1.1,
    letterSpacing: 0,
  );
}

class _FragmentDraft {
  _FragmentDraft({
    required this.word,
    required this.wordIndex,
    required this.text,
    required this.lineIndex,
    required this.fragmentStartInWord,
    required this.fragmentEndInWord,
    required this.paragraphBounds,
    required this.textSize,
    required this.localGraphemeBounds,
    required this.slices,
  });

  final CadenzaDisplayWord word;
  final int wordIndex;
  final String text;
  final int lineIndex;
  final int fragmentStartInWord;
  final int fragmentEndInWord;
  final Rect paragraphBounds;
  final Size textSize;
  final List<Rect> localGraphemeBounds;
  final List<CadenzaGraphemeSlice> slices;

  int fragmentIndexInWord = 0;
  int fragmentCountInWord = 1;

  bool get isPrimaryFragment => fragmentIndexInWord == 0;
  bool get isSplitAcrossLines => fragmentCountInWord > 1;
}

List<_FragmentDraft> _buildFragmentDrafts({
  required List<CadenzaDisplayWord> words,
  required TextPainter fullPainter,
  required List<LineMetrics> lineMetrics,
  required TextStyle style,
  required CadenzaLyricLayoutOptions options,
}) {
  final drafts = <_FragmentDraft>[];
  for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
    final word = words[wordIndex];
    final measured = word.graphemes
        .map(
          (slice) => (
            slice: slice,
            bounds: _selectionBounds(
              painter: fullPainter,
              start: slice.textStartOffset,
              end: slice.textEndOffset,
            ),
          ),
        )
        .toList(growable: false);
    final groups = <List<({CadenzaGraphemeSlice slice, Rect bounds})>>[];
    var currentRow = -1;
    for (final value in measured) {
      final row = _lineIndexForBounds(
        painter: fullPainter,
        lineMetrics: lineMetrics,
        bounds: value.bounds,
        textOffset: value.slice.textStartOffset,
      );
      if (groups.isEmpty || row != currentRow) {
        groups.add(<({CadenzaGraphemeSlice slice, Rect bounds})>[]);
        currentRow = row;
      }
      groups.last.add(value);
    }
    for (final group in groups) {
      if (group.isEmpty) continue;
      final text = group.map((value) => value.slice.grapheme).join();
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: options.textDirection,
        locale: options.locale,
        textScaler: TextScaler.linear(options.textScaleFactor),
        maxLines: 1,
      )..layout();
      var localOffset = 0;
      final localBounds = <Rect>[];
      for (final value in group) {
        final nextOffset = localOffset + value.slice.grapheme.length;
        localBounds.add(
          _selectionBounds(
            painter: painter,
            start: localOffset,
            end: nextOffset,
          ),
        );
        localOffset = nextOffset;
      }
      final paragraphBounds = _unionRects(group.map((value) => value.bounds));
      drafts.add(
        _FragmentDraft(
          word: word,
          wordIndex: wordIndex,
          text: text,
          lineIndex: _lineIndexForBounds(
            painter: fullPainter,
            lineMetrics: lineMetrics,
            bounds: paragraphBounds,
            textOffset: group.first.slice.textStartOffset,
          ),
          fragmentStartInWord: group.first.slice.indexInWord,
          fragmentEndInWord: group.last.slice.indexInWord + 1,
          paragraphBounds: paragraphBounds,
          textSize: Size(
            math.max(painter.width, paragraphBounds.width),
            math.max(painter.height, paragraphBounds.height),
          ),
          localGraphemeBounds: localBounds,
          slices: group.map((value) => value.slice).toList(growable: false),
        ),
      );
    }
  }
  final counts = <int, int>{};
  for (final draft in drafts) {
    counts[draft.wordIndex] = (counts[draft.wordIndex] ?? 0) + 1;
  }
  final seen = <int, int>{};
  for (final draft in drafts) {
    draft.fragmentIndexInWord = seen[draft.wordIndex] ?? 0;
    draft.fragmentCountInWord = counts[draft.wordIndex] ?? 1;
    seen[draft.wordIndex] = draft.fragmentIndexInWord + 1;
  }
  return drafts;
}

int? _selectHeroWordIndex(List<_FragmentDraft> drafts, bool isInterlude) {
  if (isInterlude) return null;
  final primary = drafts
      .where((draft) => draft.isPrimaryFragment)
      .toList(growable: false);
  int? result;
  var bestScore = double.negativeInfinity;
  for (final draft in primary) {
    if (draft.isSplitAcrossLines || draft.text.trim().isEmpty) continue;
    final graphemeCount = math.max(draft.word.graphemes.length, 1);
    final semanticWeight = _containsCjk(draft.word.text)
        ? 0.18
        : math.min(graphemeCount * 0.08, 0.36);
    final centerBias =
        1 -
        (draft.wordIndex - (primary.length - 1) / 2).abs() /
            math.max(primary.length, 1);
    final score = semanticWeight + centerBias * 0.18;
    if (score > bestScore) {
      bestScore = score;
      result = draft.wordIndex;
    }
  }
  return result;
}

class _PlacedFragment {
  _PlacedFragment({
    required this.draft,
    required this.center,
    required this.scale,
    required this.rotation,
    required this.passedRotation,
    required this.passedDrift,
    required this.maximumVisualBounds,
  });

  final _FragmentDraft draft;
  final Offset center;
  final double scale;
  final double rotation;
  final double passedRotation;
  final Offset passedDrift;
  final Rect maximumVisualBounds;

  CadenzaWordFragment toLayout({
    required double fitScale,
    required Offset Function(Offset) mapPoint,
    required Rect stageBounds,
    required double hitSlop,
  }) {
    final finalCenter = mapPoint(center);
    final finalScale = scale * fitScale;
    final bounds = _rectAroundCenter(
      center: finalCenter,
      size: draft.textSize,
      scale: finalScale,
      rotation: rotation,
    );
    final visualBounds = _boundedRect(
      _mapRect(maximumVisualBounds, fitScale, mapPoint),
      stageBounds,
    );
    final graphemes = <CadenzaGraphemeGeometry>[];
    for (var index = 0; index < draft.slices.length; index++) {
      final local = draft.localGraphemeBounds[index];
      graphemes.add(
        CadenzaGraphemeGeometry(
          slice: draft.slices[index],
          localBounds: local,
          bounds: _transformTextRect(
            rect: local,
            textSize: draft.textSize,
            center: finalCenter,
            scale: finalScale,
            rotation: rotation,
          ),
        ),
      );
    }
    return CadenzaWordFragment(
      id:
          '${draft.word.id}:${draft.lineIndex}:'
          '${draft.fragmentIndexInWord}',
      word: draft.word,
      wordIndex: draft.wordIndex,
      text: draft.text,
      lineIndex: draft.lineIndex,
      fragmentIndexInWord: draft.fragmentIndexInWord,
      fragmentCountInWord: draft.fragmentCountInWord,
      fragmentStartInWord: draft.fragmentStartInWord,
      fragmentEndInWord: draft.fragmentEndInWord,
      isPrimaryFragment: draft.isPrimaryFragment,
      isSplitAcrossLines: draft.isSplitAcrossLines,
      center: finalCenter,
      textSize: draft.textSize,
      paintScale: finalScale,
      rotation: rotation,
      passedRotation: passedRotation,
      passedDrift: passedDrift * fitScale,
      bounds: _boundedRect(bounds, stageBounds),
      visualBounds: visualBounds,
      hitRect: _boundedRect(
        visualBounds.inflate(math.max(hitSlop, 0)),
        stageBounds,
      ),
      graphemes: List<CadenzaGraphemeGeometry>.unmodifiable(graphemes),
    );
  }
}

class _CadenzaCollisionIndex {
  _CadenzaCollisionIndex(this.bandSize);

  final double bandSize;
  final List<Rect> _rects = <Rect>[];
  final Map<int, List<int>> _bands = <int, List<int>>{};
  final List<int> _marks = <int>[];
  int _queryStamp = 0;

  int _bandFor(double value) => (value / bandSize).floor();

  void add(Rect rect) {
    final index = _rects.length;
    _rects.add(rect);
    _marks.add(0);
    for (var band = _bandFor(rect.top); band <= _bandFor(rect.bottom); band++) {
      (_bands[band] ??= <int>[]).add(index);
    }
  }

  double overlapArea(Rect candidate) {
    if (_rects.isEmpty) return 0;
    final stamp = ++_queryStamp;
    var result = 0.0;
    for (
      var band = _bandFor(candidate.top);
      band <= _bandFor(candidate.bottom);
      band++
    ) {
      final bucket = _bands[band];
      if (bucket == null) continue;
      for (final index in bucket) {
        if (_marks[index] == stamp) continue;
        _marks[index] = stamp;
        final other = _rects[index];
        final overlapWidth = math.max(
          0.0,
          math.min(candidate.right, other.right) -
              math.max(candidate.left, other.left),
        );
        final overlapHeight = math.max(
          0.0,
          math.min(candidate.bottom, other.bottom) -
              math.max(candidate.top, other.top),
        );
        result += overlapWidth * overlapHeight;
      }
    }
    return result;
  }
}

List<_PlacedFragment> _placeFragments({
  required List<_FragmentDraft> drafts,
  required int? heroWordIndex,
  required double fontPx,
  required double lineHeight,
  required double maxWidth,
  required double seed,
  required bool isInterlude,
}) {
  final totalHeight =
      math.max(
        drafts.fold<int>(
          0,
          (value, draft) => math.max(value, draft.lineIndex + 1),
        ),
        1,
      ) *
      lineHeight;
  const baseScale = 1.01;
  final primaryCount = drafts.where((draft) => draft.isPrimaryFragment).length;
  final plans =
      drafts
          .map((draft) {
            var emphasis = 1.0;
            if (draft.wordIndex == heroWordIndex &&
                draft.isPrimaryFragment &&
                !draft.isSplitAcrossLines) {
              final graphemeCount = math.max(draft.word.graphemes.length, 1);
              final semanticWeight = _containsCjk(draft.word.text)
                  ? 0.18
                  : math.min(graphemeCount * 0.08, 0.36);
              final centerBias =
                  1 -
                  (draft.wordIndex - (primaryCount - 1) / 2).abs() /
                      math.max(primaryCount, 1);
              final score = semanticWeight + centerBias * 0.18;
              emphasis = 1.46 * (1 + (score - 0.48).clamp(0.0, 0.52));
            }
            final width = math.max(draft.textSize.width, fontPx * 0.18);
            final scale = baseScale * emphasis;
            final height = math.max(
              draft.textSize.height,
              fontPx * scale * 0.95,
            );
            final preferred = emphasis > 1
                ? Offset.zero
                : Offset(
                    draft.paragraphBounds.center.dx - maxWidth / 2,
                    draft.paragraphBounds.center.dy - totalHeight / 2,
                  );
            return _PlacementPlan(
              draft: draft,
              emphasis: emphasis,
              width: width,
              height: height,
              scale: scale,
              collisionSize: Size(
                width * scale * (emphasis > 1 ? 1.48 : 1.26),
                height * (emphasis > 1 ? 1.36 : 1.24),
              ),
              padding: 6 + (emphasis > 1 ? 10 : 2),
              preferredCenter: preferred,
            );
          })
          .toList(growable: false)
        ..sort((first, second) {
          final emphasis = second.emphasis.compareTo(first.emphasis);
          if (emphasis != 0) return emphasis;
          final row = first.draft.lineIndex.compareTo(second.draft.lineIndex);
          if (row != 0) return row;
          return first.draft.paragraphBounds.left.compareTo(
            second.draft.paragraphBounds.left,
          );
        });

  final heroPlan = plans
      .where((plan) => plan.draft.wordIndex == heroWordIndex)
      .firstOrNull;
  final collisionIndex = _CadenzaCollisionIndex(
    math.max(24, (lineHeight * 0.9).roundToDouble()),
  );
  final result = <_PlacedFragment>[];
  for (var planIndex = 0; planIndex < plans.length; planIndex++) {
    final plan = plans[planIndex];
    var preferred = plan.preferredCenter;
    if (!isInterlude && plan.emphasis <= 1 && heroPlan != null) {
      var delta = preferred - heroPlan.preferredCenter;
      var distance = delta.distance;
      if (distance < 1) {
        delta = Offset(
          preferred.dx >= 0 ? 1 : -1,
          plan.draft.lineIndex.isEven ? -0.65 : 0.65,
        );
        distance = delta.distance;
      }
      final minimumSeparation =
          heroPlan.width * heroPlan.scale * 0.34 +
          plan.width * 0.52 +
          plan.padding * 2;
      if (distance < minimumSeparation) {
        preferred +=
            delta /
            math.max(distance, 1) *
            (minimumSeparation - distance) *
            0.92;
      }
    }

    final step = math.max(10.0, (fontPx * 0.14).roundToDouble());
    final maxRadius = plan.emphasis > 1
        ? math.max(20.0, lineHeight * 0.5)
        : math.max(
            lineHeight * 2.2,
            math.max(plan.collisionSize.width * 0.75, 56),
          );
    final horizontalMin = -maxWidth / 2 - 72;
    final horizontalMax = maxWidth / 2 + 72;
    final verticalMin = -math.max(totalHeight * 0.9, lineHeight * 1.6);
    final verticalMax = math.max(totalHeight * 0.9, lineHeight * 1.45);
    var chosen = preferred;
    var best = preferred;
    var bestScore = double.infinity;
    var found = false;
    final baseAngle = heroPlan != null && plan.emphasis <= 1
        ? math.atan2(preferred.dy, preferred.dx)
        : 0.0;

    for (var radius = 0.0; radius <= maxRadius && !found; radius += step) {
      final sampleCount = radius == 0
          ? 1
          : plan.emphasis > 1
          ? 8
          : math.max(
              12,
              (math.pi * 2 * radius / math.max(step * 1.1, 10)).round(),
            );
      for (var sample = 0; sample < sampleCount; sample++) {
        final angle = baseAngle + sample / sampleCount * math.pi * 2;
        final delta = radius == 0
            ? Offset.zero
            : Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius * (plan.emphasis > 1 ? 0.8 : 0.92),
              );
        final candidate = preferred + delta;
        final rect = Rect.fromCenter(
          center: candidate,
          width: plan.collisionSize.width + plan.padding * 2,
          height: plan.collisionSize.height + plan.padding * 2,
        );
        if (rect.left < horizontalMin ||
            rect.right > horizontalMax ||
            rect.top < verticalMin ||
            rect.bottom > verticalMax) {
          continue;
        }
        final overlapArea = collisionIndex.overlapArea(rect);
        final score = overlapArea * 2.2 + delta.distance;
        if (score < bestScore) {
          bestScore = score;
          best = candidate;
        }
        if (overlapArea == 0) {
          chosen = candidate;
          collisionIndex.add(rect);
          found = true;
          break;
        }
      }
    }
    if (!found) {
      chosen = best;
      collisionIndex.add(
        Rect.fromCenter(
          center: chosen,
          width: plan.collisionSize.width + plan.padding * 2,
          height: plan.collisionSize.height + plan.padding * 2,
        ),
      );
    }

    double random(int offset) {
      final value =
          math.sin(
            seed +
                plan.draft.wordIndex * 17 +
                plan.draft.lineIndex * 31 +
                plan.draft.fragmentIndexInWord * 13 +
                offset,
          ) *
          10000;
      return value - value.floor();
    }

    final outwardLength = math.max(chosen.distance, 1.0);
    final outward = chosen / outwardLength;
    final driftAmount = isInterlude
        ? 3 + random(6) * 3
        : plan.emphasis > 1
        ? 4 + random(6) * 4
        : 5 + random(6) * 6;
    final passedDrift = Offset(
      outward.dx * driftAmount + (random(7) - 0.5) * 2.4,
      outward.dy * driftAmount * 0.72 + (random(8) - 0.5) * 2,
    );
    final passedRotation = _degreesToRadians((random(3) - 0.5) * 12);
    final baseBounds = _rectAroundCenter(
      center: chosen,
      size: plan.draft.textSize,
      scale: plan.scale,
      rotation: 0,
    );
    final activeBounds = _rectAroundCenter(
      center: chosen,
      size: plan.draft.textSize,
      scale: plan.scale * cadenzaActiveWordScale,
      rotation: 0,
    );
    final passedBounds = _rectAroundCenter(
      center: chosen + passedDrift,
      size: plan.draft.textSize,
      scale: plan.scale,
      rotation: passedRotation,
    );
    result.add(
      _PlacedFragment(
        draft: plan.draft,
        center: chosen,
        scale: plan.scale,
        rotation: 0,
        passedRotation: passedRotation,
        passedDrift: passedDrift,
        maximumVisualBounds: baseBounds
            .expandToInclude(activeBounds)
            .expandToInclude(passedBounds)
            .inflate(12),
      ),
    );
  }
  result.sort((first, second) {
    final word = first.draft.wordIndex.compareTo(second.draft.wordIndex);
    if (word != 0) return word;
    return first.draft.fragmentIndexInWord.compareTo(
      second.draft.fragmentIndexInWord,
    );
  });
  return result;
}

class _PlacementPlan {
  const _PlacementPlan({
    required this.draft,
    required this.emphasis,
    required this.width,
    required this.height,
    required this.scale,
    required this.collisionSize,
    required this.padding,
    required this.preferredCenter,
  });

  final _FragmentDraft draft;
  final double emphasis;
  final double width;
  final double height;
  final double scale;
  final Size collisionSize;
  final double padding;
  final Offset preferredCenter;
}

class _WordPiece {
  const _WordPiece({
    required this.text,
    required this.textStartOffset,
    required this.sourceTokenIndex,
  });

  final String text;
  final int textStartOffset;
  final int? sourceTokenIndex;
}

class _WordBuilder {
  final List<_WordPiece> pieces = <_WordPiece>[];
  final List<int> sourceTokenIndexes = <int>[];

  String get text => pieces.map((piece) => piece.text).join();
  int get textStartOffset => pieces.isEmpty ? 0 : pieces.first.textStartOffset;
  int get textEndOffset => pieces.isEmpty
      ? 0
      : pieces.last.textStartOffset + pieces.last.text.length;

  void appendPiece(_WordPiece piece) {
    pieces.add(piece);
    final tokenIndex = piece.sourceTokenIndex;
    if (tokenIndex != null) sourceTokenIndexes.add(tokenIndex);
  }

  void appendBuilder(_WordBuilder other) {
    pieces.addAll(other.pieces);
    sourceTokenIndexes.addAll(other.sourceTokenIndexes);
  }
}

List<_WordBuilder> _buildTokenWordBuilders(List<LyricToken> tokens) {
  final result = <_WordBuilder>[];
  final pendingLeading = <_WordPiece>[];
  var textOffset = 0;
  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    final piece = _WordPiece(
      text: token.text,
      textStartOffset: textOffset,
      sourceTokenIndex: index,
    );
    textOffset += token.text.length;
    if (token.text.trim().isEmpty) {
      if (result.isEmpty) {
        pendingLeading.add(piece);
      } else {
        result.last.appendPiece(piece);
      }
      continue;
    }
    final builder = _WordBuilder();
    for (final pending in pendingLeading) {
      builder.appendPiece(pending);
    }
    pendingLeading.clear();
    builder.appendPiece(piece);
    result.add(builder);
  }
  if (pendingLeading.isNotEmpty && result.isNotEmpty) {
    for (final pending in pendingLeading) {
      result.last.appendPiece(pending);
    }
  }
  return result;
}

List<_WordBuilder> _buildTextWordBuilders(String text) {
  final result = <_WordBuilder>[];
  final pendingWhitespace = <_WordPiece>[];
  var separatedByWhitespace = false;
  var textOffset = 0;
  for (final grapheme in text.characters) {
    final piece = _WordPiece(
      text: grapheme,
      textStartOffset: textOffset,
      sourceTokenIndex: null,
    );
    textOffset += grapheme.length;
    if (grapheme.trim().isEmpty) {
      if (result.isEmpty) {
        pendingWhitespace.add(piece);
      } else {
        result.last.appendPiece(piece);
      }
      separatedByWhitespace = true;
      continue;
    }
    final isCjk = _containsCjk(grapheme);
    final isPunctuation = _isStickyPunctuation(grapheme);
    final canJoinPrevious =
        result.isNotEmpty &&
        !separatedByWhitespace &&
        pendingWhitespace.isEmpty &&
        !isCjk &&
        !isPunctuation &&
        !_containsCjk(result.last.text) &&
        !_isStickyPunctuation(result.last.text.trim());
    if (canJoinPrevious) {
      result.last.appendPiece(piece);
    } else {
      final builder = _WordBuilder();
      for (final pending in pendingWhitespace) {
        builder.appendPiece(pending);
      }
      pendingWhitespace.clear();
      builder.appendPiece(piece);
      result.add(builder);
    }
    separatedByWhitespace = false;
  }
  if (pendingWhitespace.isNotEmpty && result.isNotEmpty) {
    for (final pending in pendingWhitespace) {
      result.last.appendPiece(pending);
    }
  }
  return result;
}

List<_WordBuilder> _applyStickyGrouping(List<_WordBuilder> source) {
  final result = <_WordBuilder>[];
  for (final current in source) {
    if (result.isNotEmpty &&
        _isStickyPunctuation(current.text.trim()) &&
        result.last.text.trim().isNotEmpty) {
      result.last.appendBuilder(current);
    } else {
      result.add(current);
    }
  }
  return result;
}

List<_CadenzaRenderableLine> _buildCadenzaRenderableLines(
  List<LyricLine> sourceLines,
) {
  if (sourceLines.isEmpty) return const <_CadenzaRenderableLine>[];
  final renderLines = <_CadenzaRenderableLine>[];
  final first = sourceLines.first;
  if (first.start > _cadenzaInterludeGap) {
    renderLines.add(
      _CadenzaRenderableLine(
        line: _createCadenzaInterlude(
          _cadenzaLeadingInset,
          first.start - _cadenzaLeadingInset,
        ),
        sourceIndex: null,
        isInterlude: true,
      ),
    );
  }
  for (var index = 0; index < sourceLines.length; index++) {
    final current = sourceLines[index];
    renderLines.add(
      _CadenzaRenderableLine(
        line: current,
        sourceIndex: index,
        isInterlude: false,
      ),
    );
    final next = index + 1 < sourceLines.length ? sourceLines[index + 1] : null;
    final currentEnd = current.end;
    if (next == null || currentEnd == null) continue;
    if (next.start - currentEnd <= _cadenzaInterludeGap) continue;
    renderLines.add(
      _CadenzaRenderableLine(
        line: _createCadenzaInterlude(
          currentEnd + _cadenzaGapInset,
          next.start - _cadenzaGapInset,
        ),
        sourceIndex: null,
        isInterlude: true,
      ),
    );
  }
  return List<_CadenzaRenderableLine>.unmodifiable(renderLines);
}

LyricLine _createCadenzaInterlude(Duration start, Duration end) {
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
    text: _cadenzaInterludeText,
    tokens: tokens,
  );
}

Rect _selectionBounds({
  required TextPainter painter,
  required int start,
  required int end,
}) {
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  if (boxes.isNotEmpty) {
    return _unionRects(boxes.map((box) => box.toRect()));
  }
  final caret = painter.getOffsetForCaret(
    TextPosition(offset: start),
    Rect.zero,
  );
  final height = painter.preferredLineHeight;
  return Rect.fromLTWH(caret.dx, caret.dy, 0.01, height);
}

int _lineIndexForBounds({
  required TextPainter painter,
  required List<LineMetrics> lineMetrics,
  required Rect bounds,
  required int textOffset,
}) {
  if (lineMetrics.isEmpty) return 0;
  final y = bounds.isEmpty
      ? painter
            .getOffsetForCaret(TextPosition(offset: textOffset), Rect.zero)
            .dy
      : bounds.center.dy;
  var top = 0.0;
  for (var index = 0; index < lineMetrics.length; index++) {
    final bottom = top + lineMetrics[index].height;
    if (y <= bottom || index == lineMetrics.length - 1) return index;
    top = bottom;
  }
  return lineMetrics.length - 1;
}

int _lastStartedLineIndex(
  List<_CadenzaRenderableLine> lines,
  Duration position,
) {
  var low = 0;
  var high = lines.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (lines[middle].line.start <= position) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low - 1;
}

Duration? _lastValidTokenEnd(LyricLine line) {
  Duration? result;
  for (final token in line.tokens) {
    if (token.startOffset.isNegative || token.duration <= Duration.zero) {
      continue;
    }
    final end = line.start + token.startOffset + token.duration;
    result = result == null ? end : _maxDuration(result, end);
  }
  return result;
}

Rect _safeStageBounds(Rect stageBounds, CadenzaLyricLayoutOptions options) {
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
      ].map(
        (point) =>
            center + _rotateOffset((point - textCenter) * scale, rotation),
      );
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

Rect _mapRect(Rect rect, double scale, Offset Function(Offset) mapPoint) {
  return Rect.fromPoints(mapPoint(rect.topLeft), mapPoint(rect.bottomRight));
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

double _clampBetween(double value, double first, double second) {
  final minimum = math.min(first, second);
  final maximum = math.max(first, second);
  return value.clamp(minimum, maximum);
}

Duration _maxDuration(Duration first, Duration second) {
  return first >= second ? first : second;
}

Duration _minDuration(Duration first, Duration second) {
  return first <= second ? first : second;
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
