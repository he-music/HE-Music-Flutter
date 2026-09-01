import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';
import '../helpers/monet_lyric_layout.dart';

/// Partita reuses Monet's document projection and timing validation, while this
/// engine owns the cloud-step geometry and measured text bounds.
class PartitaLyricLayoutEngine {
  PartitaLyricLayoutEngine(this._delegate);

  factory PartitaLyricLayoutEngine.fromDocument(LyricDocument document) {
    return PartitaLyricLayoutEngine(MonetLyricLayoutEngine(document));
  }

  final MonetLyricLayoutEngine _delegate;

  String get documentSignature => _delegate.documentSignature;
  int get lineCount => _delegate.lineCount;

  MonetLyricPosition resolvePosition(Duration playbackPosition) {
    return _delegate.resolvePosition(playbackPosition);
  }

  List<MonetVisibleLyricLine> buildVisibleWindow({
    required MonetLyricPosition position,
    int before = 3,
    int after = 3,
    int? manualAnchorIndex,
  }) {
    return _delegate.buildVisibleWindow(
      position: position,
      before: before,
      after: after,
      manualAnchorIndex: manualAnchorIndex,
    );
  }
}

/// Partita treats any zero-duration source token as an invalid word-timing
/// sequence and falls back to a single line-level display token.
List<MonetDisplayToken> buildPartitaDisplayTokens(LyricLine line) {
  if (line.tokens.any((token) => token.duration <= Duration.zero)) {
    return <MonetDisplayToken>[
      MonetDisplayToken(
        text: line.text,
        startOffset: 0,
        endOffset: line.text.length,
        start: null,
        end: null,
        key: '${line.start.inMicroseconds}:partita-fallback',
      ),
    ];
  }
  return buildMonetDisplayTokens(line);
}

@immutable
class PartitaLyricLayoutOptions {
  const PartitaLyricLayoutOptions({
    required this.railSize,
    required this.activeTextStyle,
    required this.inactiveTextStyle,
    required this.auxiliaryTextStyle,
    this.textDirection = TextDirection.ltr,
    this.textScaleFactor = 1,
    this.horizontalPadding = 12,
    this.verticalPadding = 7,
    this.auxiliaryGap = 5,
    this.activeGap = 18,
    this.inactiveGap = 12,
    this.guideReserve = 28,
    this.anchorAlignment = 0.46,
    this.inactiveMaxLines = 2,
    this.translationOnlyForActiveLine = true,
  });

  final Size railSize;
  final TextStyle activeTextStyle;
  final TextStyle inactiveTextStyle;
  final TextStyle auxiliaryTextStyle;
  final TextDirection textDirection;
  final double textScaleFactor;
  final double horizontalPadding;
  final double verticalPadding;
  final double auxiliaryGap;
  final double activeGap;
  final double inactiveGap;
  final double guideReserve;
  final double anchorAlignment;
  final int inactiveMaxLines;
  final bool translationOnlyForActiveLine;
}

@immutable
class PartitaMeasuredLyricLine {
  const PartitaMeasuredLyricLine({
    required this.mainTextSize,
    required this.mainLineCount,
    required this.mainTextClipped,
    required this.auxiliaryText,
    required this.auxiliarySize,
    required this.auxiliaryLineCount,
    required this.layoutWidth,
    required this.visualSize,
    required this.mainTextOffset,
    required this.auxiliaryOffset,
  });

  final Size mainTextSize;
  final int mainLineCount;
  final bool mainTextClipped;
  final String? auxiliaryText;
  final Size auxiliarySize;
  final int auxiliaryLineCount;
  final double layoutWidth;
  final Size visualSize;
  final Offset mainTextOffset;
  final Offset? auxiliaryOffset;
}

@immutable
class PartitaPositionedLyricLine {
  const PartitaPositionedLyricLine({
    required this.entry,
    required this.measurement,
    required this.rect,
    required this.hitRect,
    required this.cloudOffset,
    required this.cacheKey,
  });

  final MonetVisibleLyricLine entry;
  final PartitaMeasuredLyricLine measurement;
  final Rect rect;
  final Rect hitRect;
  final double cloudOffset;
  final String cacheKey;
}

class PartitaLyricMeasurementCache {
  PartitaLyricMeasurementCache({this.maximumEntries = 240});

  final int maximumEntries;
  final Map<String, PartitaMeasuredLyricLine> _values =
      <String, PartitaMeasuredLyricLine>{};

  int get length => _values.length;

  PartitaMeasuredLyricLine resolve(
    String key,
    PartitaMeasuredLyricLine Function() measure,
  ) {
    final cached = _values[key];
    if (cached != null) return cached;
    if (maximumEntries > 0 && _values.length >= maximumEntries) {
      _values.remove(_values.keys.first);
    }
    final value = measure();
    if (maximumEntries > 0) _values[key] = value;
    return value;
  }

  void clear() => _values.clear();
}

List<PartitaPositionedLyricLine> layoutPartitaLyricWindow({
  required PartitaLyricLayoutEngine engine,
  required List<MonetVisibleLyricLine> entries,
  required PartitaLyricLayoutOptions options,
  PartitaLyricMeasurementCache? cache,
}) {
  if (entries.isEmpty || options.railSize.isEmpty) {
    return const <PartitaPositionedLyricLine>[];
  }

  final measured = entries
      .map((entry) {
        final key = _layoutCacheKey(engine.documentSignature, entry, options);
        final measurement =
            cache?.resolve(key, () => _measureLine(entry, options)) ??
            _measureLine(entry, options);
        return (entry: entry, measurement: measurement, cacheKey: key);
      })
      .toList(growable: false);

  final anchorIndex = math.max(
    0,
    measured.indexWhere((value) => value.entry.offset == 0),
  );
  final tops = List<double>.filled(measured.length, 0);
  final railHeight = math.max(options.railSize.height, 0);
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

  final railBounds = Offset.zero & options.railSize;
  final contentLeft = math.max(
    options.horizontalPadding + options.guideReserve,
    0.0,
  );
  final contentRight = math.max(
    contentLeft,
    options.railSize.width - options.horizontalPadding - options.guideReserve,
  );
  final contentWidth = contentRight - contentLeft;

  return List<PartitaPositionedLyricLine>.generate(measured.length, (index) {
    final value = measured[index];
    final visualWidth = math.min(
      value.measurement.visualSize.width,
      contentWidth,
    );
    final centeredLeft = contentLeft + (contentWidth - visualWidth) / 2;
    final maxShift = math.max((contentWidth - visualWidth) / 2, 0.0);
    final desiredShift = resolvePartitaCloudStepOffset(
      sourceIndex: value.entry.sourceIndex,
      relativeOffset: value.entry.offset,
      availableWidth: contentWidth,
    );
    final shift = desiredShift.clamp(-maxShift, maxShift).toDouble();
    final rect = Rect.fromLTWH(
      centeredLeft + shift,
      tops[index],
      visualWidth,
      value.measurement.visualSize.height,
    );
    return PartitaPositionedLyricLine(
      entry: value.entry,
      measurement: value.measurement,
      rect: rect,
      hitRect: _boundedIntersection(rect.inflate(8), railBounds),
      cloudOffset: shift,
      cacheKey: value.cacheKey,
    );
  }, growable: false);
}

@visibleForTesting
double resolvePartitaCloudStepOffset({
  required int sourceIndex,
  required int relativeOffset,
  required double availableWidth,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) return 0;
  final stableIndex = sourceIndex < 0 ? 0 : sourceIndex;
  final direction = stableIndex.isEven ? -1.0 : 1.0;
  final distance = relativeOffset.abs().clamp(0, 4);
  final magnitude = math.min(availableWidth * 0.16, 14.0 + distance * 5.0);
  return direction * magnitude;
}

PartitaMeasuredLyricLine _measureLine(
  MonetVisibleLyricLine entry,
  PartitaLyricLayoutOptions options,
) {
  final isActive = entry.status == MonetLyricLineStatus.active;
  final innerWidth = math.max(
    options.railSize.width -
        (options.horizontalPadding + options.guideReserve) * 2,
    0.0,
  );
  final widthFactor = isActive ? 0.92 : 0.76;
  final layoutWidth = math.max(
    math.min(innerWidth * widthFactor, innerWidth),
    1.0,
  );
  final mainPainter = TextPainter(
    text: TextSpan(
      text: entry.line.text,
      style: isActive ? options.activeTextStyle : options.inactiveTextStyle,
    ),
    textDirection: options.textDirection,
    textAlign: TextAlign.left,
    textScaler: TextScaler.linear(options.textScaleFactor),
    maxLines: isActive ? null : math.max(options.inactiveMaxLines, 1),
    ellipsis: isActive ? null : '\u2026',
  )..layout(maxWidth: layoutWidth);
  final mainMetrics = mainPainter.computeLineMetrics();
  final mainWidth = _paintedWidth(mainMetrics, mainPainter.width);

  final auxiliaryText = _resolveAuxiliaryText(entry, options);
  TextPainter? auxiliaryPainter;
  if (auxiliaryText != null) {
    auxiliaryPainter = TextPainter(
      text: TextSpan(text: auxiliaryText, style: options.auxiliaryTextStyle),
      textDirection: options.textDirection,
      textAlign: TextAlign.left,
      textScaler: TextScaler.linear(options.textScaleFactor),
    )..layout(maxWidth: layoutWidth);
  }
  final auxiliaryMetrics = auxiliaryPainter?.computeLineMetrics();
  final auxiliaryWidth = auxiliaryPainter == null
      ? 0.0
      : _paintedWidth(auxiliaryMetrics!, auxiliaryPainter.width);
  final visualWidth = math
      .max(mainWidth, auxiliaryWidth)
      .clamp(1.0, layoutWidth)
      .toDouble();
  final auxiliaryOffset = auxiliaryPainter == null
      ? null
      : Offset(
          0,
          options.verticalPadding + mainPainter.height + options.auxiliaryGap,
        );
  final visualHeight =
      options.verticalPadding * 2 +
      mainPainter.height +
      (auxiliaryPainter == null
          ? 0.0
          : options.auxiliaryGap + auxiliaryPainter.height);

  return PartitaMeasuredLyricLine(
    mainTextSize: Size(mainWidth, mainPainter.height),
    mainLineCount: mainMetrics.length,
    mainTextClipped: mainPainter.didExceedMaxLines,
    auxiliaryText: auxiliaryText,
    auxiliarySize: auxiliaryPainter == null
        ? Size.zero
        : Size(auxiliaryWidth, auxiliaryPainter.height),
    auxiliaryLineCount: auxiliaryMetrics?.length ?? 0,
    layoutWidth: layoutWidth,
    visualSize: Size(visualWidth, visualHeight),
    mainTextOffset: Offset(0, options.verticalPadding),
    auxiliaryOffset: auxiliaryOffset,
  );
}

String? _resolveAuxiliaryText(
  MonetVisibleLyricLine entry,
  PartitaLyricLayoutOptions options,
) {
  if (options.translationOnlyForActiveLine &&
      entry.status != MonetLyricLineStatus.active) {
    return null;
  }
  if (entry.line.translation.trim().isNotEmpty) {
    return entry.line.translation;
  }
  if (entry.line.romanization.trim().isNotEmpty) {
    return entry.line.romanization;
  }
  return null;
}

double _paintedWidth(List<LineMetrics> metrics, double fallback) {
  if (metrics.isEmpty) return fallback;
  return metrics.fold<double>(0, (width, line) => math.max(width, line.width));
}

double _lineGap(
  MonetVisibleLyricLine first,
  MonetVisibleLyricLine second,
  PartitaLyricLayoutOptions options,
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
      left.clamp(bounds.left, bounds.right).toDouble(),
      top.clamp(bounds.top, bounds.bottom).toDouble(),
      0,
      0,
    );
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

String _layoutCacheKey(
  String documentSignature,
  MonetVisibleLyricLine entry,
  PartitaLyricLayoutOptions options,
) {
  return <Object?>[
    documentSignature,
    entry.key,
    entry.status.name,
    options.railSize.width,
    options.railSize.height,
    _styleMetricsKey(
      entry.status == MonetLyricLineStatus.active
          ? options.activeTextStyle
          : options.inactiveTextStyle,
    ),
    _styleMetricsKey(options.auxiliaryTextStyle),
    options.textDirection.name,
    options.textScaleFactor,
    options.horizontalPadding,
    options.verticalPadding,
    options.auxiliaryGap,
    options.guideReserve,
    options.inactiveMaxLines,
    options.translationOnlyForActiveLine,
  ].join('|');
}

String _styleMetricsKey(TextStyle style) => <Object?>[
  style.fontFamily,
  style.fontFamilyFallback?.join(','),
  style.fontSize,
  style.fontWeight?.value,
  style.fontStyle?.name,
  style.letterSpacing,
  style.wordSpacing,
  style.height,
  style.locale,
].join(':');
