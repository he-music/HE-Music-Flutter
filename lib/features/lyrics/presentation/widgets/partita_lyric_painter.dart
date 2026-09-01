import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/partita_lyric_layout.dart';

enum PartitaTimingState { waiting, active, passed }

@immutable
class PartitaWordPaintData {
  const PartitaWordPaintData({
    required this.layout,
    required this.bodyPainter,
    required this.activePainter,
    required this.glowPainter,
  });

  final PartitaWordLayout layout;
  final TextPainter bodyPainter;
  final TextPainter activePainter;
  final TextPainter glowPainter;
}

@immutable
class PartitaChunkPaintData {
  const PartitaChunkPaintData({required this.layout, required this.words});

  final PartitaChunkLayout layout;
  final List<PartitaWordPaintData> words;
}

@immutable
class PartitaLyricRenderData {
  const PartitaLyricRenderData({
    required this.size,
    required this.layout,
    required this.chunks,
    required this.auxiliaryPainter,
    required this.auxiliaryOffset,
    required this.timelineOffset,
    required this.textDirection,
    required this.palette,
    required this.fineTimingEnabled,
    required this.forceLineActive,
  });

  final Size size;
  final PartitaLineLayout? layout;
  final List<PartitaChunkPaintData> chunks;
  final TextPainter? auxiliaryPainter;
  final Offset? auxiliaryOffset;
  final Duration timelineOffset;
  final TextDirection textDirection;
  final PlayerScenePalette palette;
  final bool fineTimingEnabled;
  final bool forceLineActive;
}

PartitaLyricRenderData buildPartitaLyricRenderData({
  required Size size,
  required PartitaLineLayout? layout,
  required PartitaLyricLayoutOptions options,
  required TextStyle auxiliaryTextStyle,
  required PlayerScenePalette palette,
  required bool enableWordByWordLyric,
  required bool forceLineActive,
  required Duration timelineOffset,
  VoidCallback? debugOnTextLayout,
}) {
  if (layout == null) {
    return PartitaLyricRenderData(
      size: size,
      layout: null,
      chunks: const <PartitaChunkPaintData>[],
      auxiliaryPainter: null,
      auxiliaryOffset: null,
      timelineOffset: timelineOffset,
      textDirection: options.textDirection,
      palette: palette,
      fineTimingEnabled: false,
      forceLineActive: forceLineActive,
    );
  }

  final densityScale = layout.totalGraphemes > 40 ? 0.8 : 1.0;
  final textStyle = options.textStyle.copyWith(
    fontSize: (options.textStyle.fontSize ?? 48) * densityScale,
  );
  TextPainter layoutPainter(String text, TextStyle style) {
    debugOnTextLayout?.call();
    return TextPainter(
      text: TextSpan(text: text, style: style),
      locale: options.locale,
      textDirection: options.textDirection,
      textScaler: TextScaler.linear(options.textScaleFactor),
      maxLines: 1,
    )..layout();
  }

  final chunks = layout.chunks
      .map((chunk) {
        final words = chunk.words
            .map((word) {
              final bodyPainter = layoutPainter(
                word.word.text,
                textStyle.copyWith(
                  color: palette.foreground.withValues(alpha: 0.82),
                  shadows: const <Shadow>[],
                ),
              );
              final activePainter = layoutPainter(
                word.word.text,
                textStyle.copyWith(
                  color: palette.accent,
                  shadows: const <Shadow>[],
                ),
              );
              final glowPainter = layoutPainter(
                word.word.text,
                textStyle.copyWith(
                  color: Color.lerp(
                    palette.accent,
                    palette.edge,
                    0.38,
                  )!.withValues(alpha: 0.56),
                  shadows: const <Shadow>[],
                ),
              );
              return PartitaWordPaintData(
                layout: word,
                bodyPainter: bodyPainter,
                activePainter: activePainter,
                glowPainter: glowPainter,
              );
            })
            .toList(growable: false);
        return PartitaChunkPaintData(
          layout: chunk,
          words: List<PartitaWordPaintData>.unmodifiable(words),
        );
      })
      .toList(growable: false);

  final auxiliaryText = layout.auxiliaryText;
  TextPainter? auxiliaryPainter;
  Offset? auxiliaryOffset;
  if (auxiliaryText != null) {
    debugOnTextLayout?.call();
    auxiliaryPainter = TextPainter(
      text: TextSpan(
        text: auxiliaryText,
        style: auxiliaryTextStyle.copyWith(
          color: palette.secondaryForeground.withValues(alpha: 0.72),
        ),
      ),
      textDirection: options.textDirection,
      locale: options.locale,
      textAlign: TextAlign.center,
      textScaler: TextScaler.linear(options.textScaleFactor),
      maxLines: 2,
      ellipsis: '\u2026',
    )..layout(maxWidth: math.max(size.width * 0.76, 1));
    auxiliaryOffset = Offset(
      (size.width - auxiliaryPainter.width) / 2,
      math.max(size.height - auxiliaryPainter.height - 20, 0),
    );
  }

  return PartitaLyricRenderData(
    size: size,
    layout: layout,
    chunks: List<PartitaChunkPaintData>.unmodifiable(chunks),
    auxiliaryPainter: auxiliaryPainter,
    auxiliaryOffset: auxiliaryOffset,
    timelineOffset: timelineOffset,
    textDirection: options.textDirection,
    palette: palette,
    fineTimingEnabled: enableWordByWordLyric && layout.hasFineTiming,
    forceLineActive: forceLineActive,
  );
}

@visibleForTesting
PartitaTimingState resolvePartitaTimingState({
  required Duration timelinePosition,
  required Duration? start,
  required Duration? end,
  required Duration lookahead,
  bool forceActive = false,
}) {
  if (forceActive || start == null || end == null || end <= start) {
    return PartitaTimingState.active;
  }
  if (timelinePosition < start - lookahead) {
    return PartitaTimingState.waiting;
  }
  if (timelinePosition <= end) return PartitaTimingState.active;
  return PartitaTimingState.passed;
}

@visibleForTesting
Duration resolvePartitaLookahead(PartitaLineLayout? layout) {
  final line = layout?.sourceLine;
  final end = line?.end;
  if (line == null || end == null || end <= line.start) {
    return const Duration(milliseconds: 150);
  }
  final duration = end - line.start;
  if (duration < const Duration(milliseconds: 100)) {
    return const Duration(milliseconds: 30);
  }
  if (duration < const Duration(milliseconds: 180)) {
    return const Duration(milliseconds: 80);
  }
  return const Duration(milliseconds: 150);
}

@visibleForTesting
double resolvePartitaEntryProgress({
  required Duration timelinePosition,
  required Duration? start,
  required Duration lookahead,
}) {
  if (start == null || lookahead <= Duration.zero) return 1;
  final entryStart = start - lookahead;
  if (timelinePosition <= entryStart) return 0;
  if (timelinePosition >= start) return 1;
  return ((timelinePosition - entryStart).inMicroseconds /
          lookahead.inMicroseconds)
      .clamp(0.0, 1.0);
}

@visibleForTesting
double resolvePartitaPaintEntry({
  required bool forceActive,
  required PartitaTimingState state,
  required Duration timelinePosition,
  required Duration? start,
  required Duration lookahead,
}) {
  if (forceActive) return 1;
  if (state == PartitaTimingState.waiting) return 0;
  return resolvePartitaEntryProgress(
    timelinePosition: timelinePosition,
    start: start,
    lookahead: lookahead,
  );
}

@visibleForTesting
double resolvePartitaPassedProgress({
  required Duration timelinePosition,
  required Duration? end,
  Duration settleDuration = const Duration(milliseconds: 500),
}) {
  if (end == null || timelinePosition <= end) return 0;
  if (settleDuration <= Duration.zero) return 1;
  return ((timelinePosition - end).inMicroseconds /
          settleDuration.inMicroseconds)
      .clamp(0.0, 1.0);
}

class PartitaLyricPainter extends CustomPainter {
  PartitaLyricPainter({
    required this.data,
    required this.previousData,
    required this.position,
    required this.transition,
    required this.breathing,
    this.onPaint,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           position,
           transition,
           breathing,
         ]),
       );

  final PartitaLyricRenderData data;
  final PartitaLyricRenderData? previousData;
  final ValueListenable<Duration> position;
  final Animation<double> transition;
  final Animation<double> breathing;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final transitionValue = Curves.easeOutCubic.transform(transition.value);
    final previous = previousData;
    if (previous != null && transitionValue < 1) {
      _paintRenderData(
        canvas,
        previous,
        opacity: 1 - transitionValue,
        lineScale: 1 + transitionValue * 0.08,
        ambientEnabled: false,
      );
    }
    _paintRenderData(
      canvas,
      data,
      opacity: transitionValue,
      lineScale: 0.9 + transitionValue * 0.1,
      ambientEnabled: true,
    );
    canvas.restore();
  }

  void _paintRenderData(
    Canvas canvas,
    PartitaLyricRenderData renderData, {
    required double opacity,
    required double lineScale,
    required bool ambientEnabled,
  }) {
    final layout = renderData.layout;
    if (layout == null || opacity <= 0) return;
    final timelinePosition = position.value + renderData.timelineOffset;
    final lookahead = resolvePartitaLookahead(layout);
    final ambientPhase = ambientEnabled
        ? math.sin(breathing.value * math.pi * 2)
        : 0.0;
    final ambientShift = Offset(0, ambientPhase * 5.5);
    final ambientScale = 1 + ambientPhase * 0.005;
    final center = Offset(
      renderData.size.width / 2,
      renderData.size.height / 2,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(lineScale * ambientScale);
    canvas.translate(
      -center.dx + ambientShift.dx,
      -center.dy + ambientShift.dy,
    );
    if (opacity < 0.999) {
      canvas.saveLayer(
        Offset.zero & renderData.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    for (final chunk in renderData.chunks) {
      _paintChunk(canvas, renderData, chunk, timelinePosition, lookahead);
    }

    final auxiliaryPainter = renderData.auxiliaryPainter;
    final auxiliaryOffset = renderData.auxiliaryOffset;
    if (auxiliaryPainter != null && auxiliaryOffset != null) {
      auxiliaryPainter.paint(canvas, auxiliaryOffset + ambientShift * 0.35);
    }
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintChunk(
    Canvas canvas,
    PartitaLyricRenderData renderData,
    PartitaChunkPaintData chunk,
    Duration timelinePosition,
    Duration lookahead,
  ) {
    final layout = chunk.layout;
    final forceActive =
        renderData.forceLineActive || !renderData.fineTimingEnabled;
    final lastWord = chunk.words.isEmpty ? null : chunk.words.last.layout.word;
    final activeEnd = lastWord == null
        ? layout.end
        : resolvePartitaWordActiveEnd(
            line: renderData.layout!.sourceLine,
            start: lastWord.start,
            end: lastWord.end,
          );
    final state = resolvePartitaTimingState(
      timelinePosition: timelinePosition,
      start: layout.start,
      end: activeEnd,
      lookahead: lookahead,
      forceActive: forceActive,
    );
    final entry = resolvePartitaPaintEntry(
      forceActive: forceActive,
      state: state,
      timelinePosition: timelinePosition,
      start: layout.start,
      lookahead: lookahead,
    );
    final passed = forceActive
        ? 0.0
        : resolvePartitaPassedProgress(
            timelinePosition: timelinePosition,
            end: activeEnd,
          );
    final guideDirection = layout.guide.side == PartitaGuideSide.left
        ? -1.0
        : 1.0;
    final waitingShift = Offset(guideDirection * 40 * (1 - entry), 0);
    final stateScale = ui.lerpDouble(0.85, 1, entry)!;
    final stateRotation = layout.transform.passedRotation * passed;
    final center = layout.visualBounds.center;

    canvas.save();
    canvas.translate(center.dx + waitingShift.dx, center.dy + waitingShift.dy);
    canvas.rotate(stateRotation);
    canvas.scale(stateScale);
    canvas.translate(-center.dx, -center.dy);
    _paintGuide(canvas, renderData, layout, state, entry);
    for (final word in chunk.words) {
      _paintWord(
        canvas,
        renderData,
        word,
        timelinePosition,
        lookahead,
        forceActive,
      );
    }
    canvas.restore();
  }

  void _paintGuide(
    Canvas canvas,
    PartitaLyricRenderData renderData,
    PartitaChunkLayout chunk,
    PartitaTimingState state,
    double entry,
  ) {
    if (entry <= 0) return;
    final color = switch (state) {
      PartitaTimingState.waiting => Colors.white.withValues(
        alpha: 0.14 * entry,
      ),
      PartitaTimingState.active => renderData.palette.accent.withValues(
        alpha: 0.72 * entry,
      ),
      PartitaTimingState.passed => Colors.white.withValues(alpha: 0.22),
    };
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (state == PartitaTimingState.active) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    }
    for (final segment in chunk.guide.segments) {
      canvas.drawLine(segment.start, segment.end, paint);
    }
  }

  void _paintWord(
    Canvas canvas,
    PartitaLyricRenderData renderData,
    PartitaWordPaintData word,
    Duration timelinePosition,
    Duration lookahead,
    bool forceActive,
  ) {
    final displayWord = word.layout.word;
    final activeEnd = resolvePartitaWordActiveEnd(
      line: renderData.layout!.sourceLine,
      start: displayWord.start,
      end: displayWord.end,
    );
    final state = resolvePartitaTimingState(
      timelinePosition: timelinePosition,
      start: displayWord.start,
      end: activeEnd,
      lookahead: lookahead,
      forceActive: forceActive,
    );
    final entry = resolvePartitaPaintEntry(
      forceActive: forceActive,
      state: state,
      timelinePosition: timelinePosition,
      start: displayWord.start,
      lookahead: lookahead,
    );
    if (entry <= 0) return;
    final passed = forceActive
        ? 0.0
        : resolvePartitaPassedProgress(
            timelinePosition: timelinePosition,
            end: activeEnd,
          );
    final relativeScale = forceActive
        ? 1.05
        : switch (state) {
            PartitaTimingState.waiting => ui.lerpDouble(
              0.5,
              partitaActiveWordScale,
              entry,
            )!,
            PartitaTimingState.active => partitaActiveWordScale,
            PartitaTimingState.passed => ui.lerpDouble(
              partitaActiveWordScale,
              1,
              passed,
            )!,
          };
    final entryOffset = forceActive
        ? Offset.zero
        : Offset(
                math.sin(word.layout.transform.offset.dy) * 100,
                math.cos(word.layout.transform.offset.dx) * 50,
              ) *
              (1 - entry);
    final entryRotation = forceActive
        ? 0.0
        : (20 * math.pi / 180) * (1 - entry);
    final relativeRotation =
        entryRotation +
        (state == PartitaTimingState.passed
            ? word.layout.transform.passedRotation * passed
            : 0);
    final painter = forceActive
        ? word.activePainter
        : state == PartitaTimingState.active
        ? word.activePainter
        : word.bodyPainter;
    final wordOpacity = state == PartitaTimingState.passed ? 0.82 : entry;
    final bounds = word.layout.geometry.bounds.shift(entryOffset).inflate(18);

    if (wordOpacity < 0.999) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: wordOpacity),
      );
    }
    _paintTextPainter(
      canvas,
      painter,
      word.layout,
      relativeOffset: entryOffset,
      relativeScale: relativeScale,
      relativeRotation: relativeRotation,
    );
    if (!forceActive && state == PartitaTimingState.active) {
      _paintCurrentGrapheme(
        canvas,
        word,
        timelinePosition,
        relativeScale,
        entryOffset,
        relativeRotation,
      );
    }
    if (wordOpacity < 0.999) canvas.restore();
  }

  void _paintCurrentGrapheme(
    Canvas canvas,
    PartitaWordPaintData word,
    Duration timelinePosition,
    double relativeScale,
    Offset relativeOffset,
    double relativeRotation,
  ) {
    PartitaGraphemeGeometry? current;
    for (final grapheme in word.layout.geometry.graphemes) {
      final start = grapheme.slice.start;
      final end = grapheme.slice.end;
      if (start != null &&
          end != null &&
          timelinePosition >= start &&
          timelinePosition <= end) {
        current = grapheme;
        break;
      }
    }
    if (current == null) return;

    final geometry = word.layout.geometry;
    final textOrigin = Offset(
      -geometry.textSize.width / 2,
      -geometry.textSize.height / 2,
    );
    final localClip = current.localBounds
        .shift(textOrigin)
        .inflate(1.5 / (geometry.paintScale * relativeScale));
    canvas.save();
    canvas.translate(
      geometry.center.dx + relativeOffset.dx,
      geometry.center.dy + relativeOffset.dy,
    );
    canvas.rotate(geometry.paintRotation + relativeRotation);
    canvas.scale(geometry.paintScale * relativeScale);
    canvas.saveLayer(
      localClip.inflate(10),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.6, sigmaY: 2.6),
    );
    canvas.clipRect(localClip);
    word.glowPainter.paint(canvas, textOrigin);
    canvas.restore();
    canvas.restore();
  }

  void _paintTextPainter(
    Canvas canvas,
    TextPainter painter,
    PartitaWordLayout word, {
    required Offset relativeOffset,
    required double relativeScale,
    double relativeRotation = 0,
  }) {
    final geometry = word.geometry;
    canvas.save();
    canvas.translate(
      geometry.center.dx + relativeOffset.dx,
      geometry.center.dy + relativeOffset.dy,
    );
    canvas.rotate(geometry.paintRotation + relativeRotation);
    canvas.scale(geometry.paintScale * relativeScale);
    painter.paint(
      canvas,
      Offset(-geometry.textSize.width / 2, -geometry.textSize.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PartitaLyricPainter oldDelegate) {
    return !identical(data, oldDelegate.data) ||
        !identical(previousData, oldDelegate.previousData) ||
        !identical(position, oldDelegate.position) ||
        !identical(transition, oldDelegate.transition) ||
        !identical(breathing, oldDelegate.breathing);
  }
}
