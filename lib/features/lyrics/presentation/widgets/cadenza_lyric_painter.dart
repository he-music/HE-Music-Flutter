import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/cadenza_lyric_layout.dart';

enum CadenzaTimingState { waiting, active, passed }

@immutable
class CadenzaFragmentPaintData {
  const CadenzaFragmentPaintData({
    required this.layout,
    required this.bodyPainter,
    required this.activePainter,
  });

  final CadenzaWordFragment layout;
  final TextPainter bodyPainter;
  final TextPainter activePainter;
}

@immutable
class CadenzaLyricRenderData {
  const CadenzaLyricRenderData({
    required this.size,
    required this.layout,
    required this.fragments,
    required this.auxiliaryPainter,
    required this.auxiliaryOffset,
    required this.timelineOffset,
    required this.palette,
    required this.fineTimingEnabled,
    required this.forceLineActive,
  });

  final Size size;
  final CadenzaLineLayout? layout;
  final List<CadenzaFragmentPaintData> fragments;
  final TextPainter? auxiliaryPainter;
  final Offset? auxiliaryOffset;
  final Duration timelineOffset;
  final PlayerScenePalette palette;
  final bool fineTimingEnabled;
  final bool forceLineActive;
}

CadenzaLyricRenderData buildCadenzaLyricRenderData({
  required Size size,
  required CadenzaLineLayout? layout,
  required CadenzaLyricLayoutOptions options,
  required TextStyle auxiliaryTextStyle,
  required PlayerScenePalette palette,
  required bool enableWordByWordLyric,
  required bool forceLineActive,
  required Duration timelineOffset,
  VoidCallback? debugOnTextLayout,
}) {
  if (layout == null) {
    return CadenzaLyricRenderData(
      size: size,
      layout: null,
      fragments: const <CadenzaFragmentPaintData>[],
      auxiliaryPainter: null,
      auxiliaryOffset: null,
      timelineOffset: timelineOffset,
      palette: palette,
      fineTimingEnabled: false,
      forceLineActive: forceLineActive,
    );
  }

  TextPainter layoutPainter(String text, TextStyle style) {
    debugOnTextLayout?.call();
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: options.textDirection,
      locale: options.locale,
      textScaler: TextScaler.linear(options.textScaleFactor),
      maxLines: 1,
    )..layout();
  }

  final baseStyle = layout.effectiveTextStyle;
  final fragments = layout.fragments
      .map((fragment) {
        final body = layoutPainter(
          fragment.text,
          baseStyle.copyWith(
            color: palette.foreground,
            shadows: const <Shadow>[],
          ),
        );
        final active = layoutPainter(
          fragment.text,
          baseStyle.copyWith(color: palette.accent, shadows: const <Shadow>[]),
        );
        return CadenzaFragmentPaintData(
          layout: fragment,
          bodyPainter: body,
          activePainter: active,
        );
      })
      .toList(growable: false);

  TextPainter? auxiliaryPainter;
  Offset? auxiliaryOffset;
  final auxiliaryText = layout.auxiliaryText;
  if (auxiliaryText != null) {
    debugOnTextLayout?.call();
    auxiliaryPainter = TextPainter(
      text: TextSpan(
        text: auxiliaryText,
        style: auxiliaryTextStyle.copyWith(
          color: palette.secondaryForeground.withValues(alpha: 0.76),
          letterSpacing: 0,
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
      math.max(size.height - auxiliaryPainter.height - 18, 0),
    );
  }

  return CadenzaLyricRenderData(
    size: size,
    layout: layout,
    fragments: List<CadenzaFragmentPaintData>.unmodifiable(fragments),
    auxiliaryPainter: auxiliaryPainter,
    auxiliaryOffset: auxiliaryOffset,
    timelineOffset: timelineOffset,
    palette: palette,
    fineTimingEnabled: enableWordByWordLyric && layout.hasFineTiming,
    forceLineActive: forceLineActive,
  );
}

@visibleForTesting
CadenzaTimingState resolveCadenzaTimingState({
  required Duration timelinePosition,
  required Duration? start,
  required Duration? end,
  required Duration lookahead,
  bool forceActive = false,
}) {
  if (forceActive || start == null || end == null || end <= start) {
    return CadenzaTimingState.active;
  }
  if (timelinePosition < start - lookahead) {
    return CadenzaTimingState.waiting;
  }
  if (timelinePosition <= end) return CadenzaTimingState.active;
  return CadenzaTimingState.passed;
}

@visibleForTesting
double resolveCadenzaEntryProgress({
  required Duration timelinePosition,
  required Duration? start,
  required Duration lookahead,
  bool forceActive = false,
}) {
  if (forceActive || start == null || lookahead <= Duration.zero) return 1;
  final entryStart = start - lookahead;
  if (timelinePosition <= entryStart) return 0;
  if (timelinePosition >= start) return 1;
  return ((timelinePosition - entryStart).inMicroseconds /
          lookahead.inMicroseconds)
      .clamp(0.0, 1.0);
}

@visibleForTesting
double resolveCadenzaPassedProgress({
  required Duration timelinePosition,
  required Duration? end,
  Duration settleDuration = const Duration(seconds: 5),
}) {
  if (end == null || timelinePosition <= end) return 0;
  if (settleDuration <= Duration.zero) return 1;
  return ((timelinePosition - end).inMicroseconds /
          settleDuration.inMicroseconds)
      .clamp(0.0, 1.0);
}

@visibleForTesting
double resolveCadenzaLineOpacity({
  required CadenzaLineLayout layout,
  required Duration timelinePosition,
  bool forceActive = false,
}) {
  if (forceActive) return 1;
  final line = layout.sourceLine;
  final lookahead = resolveCadenzaLookahead(layout.timingClass);
  final entry = resolveCadenzaEntryProgress(
    timelinePosition: timelinePosition,
    start: line.start,
    lookahead: lookahead,
  );
  final renderEnd = resolveCadenzaLineRenderEnd(line);
  if (renderEnd == null || timelinePosition <= (line.end ?? renderEnd)) {
    return Curves.easeOutCubic.transform(entry);
  }
  final exitStart = line.end ?? renderEnd;
  final exitMicros = math.max(
    renderEnd.inMicroseconds - exitStart.inMicroseconds,
    1,
  );
  final exit = ((timelinePosition - exitStart).inMicroseconds / exitMicros)
      .clamp(0.0, 1.0);
  return 1 - Curves.easeInCubic.transform(exit);
}

@visibleForTesting
double resolveCadenzaActiveMix({
  required Duration timelinePosition,
  required Duration? start,
  required Duration? end,
  required CadenzaRevealProfile revealProfile,
  required Duration? lineRenderEnd,
  bool forceActive = false,
}) {
  if (forceActive) return 1;
  if (start == null ||
      end == null ||
      end <= start ||
      timelinePosition < start) {
    return 0;
  }
  if (revealProfile == CadenzaRevealProfile.instant) {
    final renderEnd = lineRenderEnd ?? end;
    return timelinePosition <= renderEnd ? 1 : 0;
  }
  if (timelinePosition <= end) {
    return ((timelinePosition - start).inMicroseconds /
            (end - start).inMicroseconds)
        .clamp(0.0, 1.0);
  }
  final fadeDuration = revealProfile == CadenzaRevealProfile.fast
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 800);
  return (1 -
          (timelinePosition - end).inMicroseconds / fadeDuration.inMicroseconds)
      .clamp(0.0, 1.0);
}

double resolveCadenzaGraphemeActiveMix({
  required Duration timelinePosition,
  required CadenzaGraphemeSlice grapheme,
  required CadenzaRevealProfile revealProfile,
  required Duration? lineRenderEnd,
  bool forceActive = false,
}) {
  return resolveCadenzaActiveMix(
    timelinePosition: timelinePosition,
    start: grapheme.start,
    end: grapheme.end,
    revealProfile: revealProfile,
    lineRenderEnd: lineRenderEnd,
    forceActive: forceActive,
  );
}

Offset resolveCadenzaFragmentOffset({
  required double entryProgress,
  required double passedProgress,
  required Offset passedDrift,
}) {
  assert(entryProgress >= 0 && entryProgress <= 1);
  return passedDrift * passedProgress.clamp(0.0, 1.0);
}

class CadenzaLyricPainter extends CustomPainter {
  CadenzaLyricPainter({
    required this.data,
    required this.previousData,
    required this.position,
    required this.transition,
    this.onPaint,
  }) : super(repaint: Listenable.merge(<Listenable>[position, transition]));

  final CadenzaLyricRenderData data;
  final CadenzaLyricRenderData? previousData;
  final ValueListenable<Duration> position;
  final Animation<double> transition;
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
        transitionOpacity: 1 - transitionValue,
        transitionScale: 1 + transitionValue * 0.08,
      );
    }
    _paintRenderData(
      canvas,
      data,
      transitionOpacity: transitionValue,
      transitionScale: 0.9 + transitionValue * 0.1,
    );
    canvas.restore();
  }

  void _paintRenderData(
    Canvas canvas,
    CadenzaLyricRenderData renderData, {
    required double transitionOpacity,
    required double transitionScale,
  }) {
    final layout = renderData.layout;
    if (layout == null || transitionOpacity <= 0) return;
    final timelinePosition = position.value + renderData.timelineOffset;
    final lineOpacity = resolveCadenzaLineOpacity(
      layout: layout,
      timelinePosition: timelinePosition,
      forceActive: renderData.forceLineActive || !renderData.fineTimingEnabled,
    );
    final opacity = transitionOpacity * lineOpacity;
    if (opacity <= 0) return;
    final center = Offset(
      renderData.size.width / 2,
      renderData.size.height / 2,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(transitionScale);
    canvas.translate(-center.dx, -center.dy);
    if (opacity < 0.999) {
      canvas.saveLayer(
        Offset.zero & renderData.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    for (final fragment in renderData.fragments) {
      _paintFragment(canvas, renderData, fragment, timelinePosition);
    }
    final auxiliaryPainter = renderData.auxiliaryPainter;
    final auxiliaryOffset = renderData.auxiliaryOffset;
    if (auxiliaryPainter != null && auxiliaryOffset != null) {
      auxiliaryPainter.paint(canvas, auxiliaryOffset);
    }
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintFragment(
    Canvas canvas,
    CadenzaLyricRenderData renderData,
    CadenzaFragmentPaintData fragment,
    Duration timelinePosition,
  ) {
    final layout = fragment.layout;
    final forceActive =
        renderData.forceLineActive || !renderData.fineTimingEnabled;
    final lookahead = resolveCadenzaLookahead(renderData.layout!.timingClass);
    final activeEnd = resolveCadenzaWordActiveEnd(
      line: renderData.layout!.sourceLine,
      start: layout.start,
      end: layout.end,
    );
    final state = resolveCadenzaTimingState(
      timelinePosition: timelinePosition,
      start: layout.start,
      end: activeEnd,
      lookahead: lookahead,
      forceActive: forceActive,
    );
    final entry = resolveCadenzaEntryProgress(
      timelinePosition: timelinePosition,
      start: layout.start,
      lookahead: lookahead,
      forceActive: forceActive,
    );
    if (entry <= 0) return;
    final passed = forceActive
        ? 0.0
        : resolveCadenzaPassedProgress(
            timelinePosition: timelinePosition,
            end: activeEnd,
          );
    final easedEntry = Curves.easeOutCubic.transform(entry);
    final relativeScale = forceActive
        ? 1.04
        : passed > 0
        ? ui.lerpDouble(
            cadenzaActiveWordScale,
            1,
            Curves.easeOutCubic.transform(passed),
          )!
        : ui.lerpDouble(0.5, cadenzaActiveWordScale, easedEntry)!;
    final relativeOffset = resolveCadenzaFragmentOffset(
      entryProgress: entry,
      passedProgress: passed,
      passedDrift: layout.passedDrift,
    );
    final relativeRotation = forceActive
        ? 0.0
        : _degreesToRadians(20) * (1 - easedEntry) +
              layout.passedRotation * passed;
    final fragmentOpacity = state == CadenzaTimingState.passed ? 0.82 : entry;
    final revealProfile = resolveCadenzaRevealProfile(
      renderData.layout!.sourceLine,
    );
    final lineRenderEnd = resolveCadenzaLineRenderEnd(
      renderData.layout!.sourceLine,
    );

    canvas.save();
    if (fragmentOpacity < 0.999) {
      canvas.saveLayer(
        layout.visualBounds.inflate(14),
        Paint()..color = Colors.white.withValues(alpha: fragmentOpacity),
      );
    }
    _paintTextPainter(
      canvas,
      fragment.bodyPainter,
      layout,
      relativeOffset: relativeOffset,
      relativeScale: relativeScale,
      relativeRotation: relativeRotation,
    );
    if (forceActive) {
      _paintTextPainter(
        canvas,
        fragment.activePainter,
        layout,
        relativeOffset: relativeOffset,
        relativeScale: relativeScale,
        relativeRotation: relativeRotation,
      );
    } else {
      _paintTimedActiveGraphemes(
        canvas,
        painter: fragment.activePainter,
        fragment: layout,
        timelinePosition: timelinePosition,
        revealProfile: revealProfile,
        lineRenderEnd: lineRenderEnd,
        relativeOffset: relativeOffset,
        relativeScale: relativeScale,
        relativeRotation: relativeRotation,
      );
    }
    if (fragmentOpacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintTimedActiveGraphemes(
    Canvas canvas, {
    required TextPainter painter,
    required CadenzaWordFragment fragment,
    required Duration timelinePosition,
    required CadenzaRevealProfile revealProfile,
    required Duration? lineRenderEnd,
    required Offset relativeOffset,
    required double relativeScale,
    required double relativeRotation,
  }) {
    canvas.save();
    canvas.translate(
      fragment.center.dx + relativeOffset.dx,
      fragment.center.dy + relativeOffset.dy,
    );
    canvas.rotate(fragment.rotation + relativeRotation);
    canvas.scale(fragment.paintScale * relativeScale);
    final textOffset = Offset(
      -fragment.textSize.width / 2,
      -fragment.textSize.height / 2,
    );
    for (final grapheme in fragment.graphemes) {
      final activeMix = resolveCadenzaGraphemeActiveMix(
        timelinePosition: timelinePosition,
        grapheme: grapheme.slice,
        revealProfile: revealProfile,
        lineRenderEnd: lineRenderEnd,
      );
      if (activeMix <= 0 || grapheme.localBounds.isEmpty) continue;
      final clipBounds = grapheme.localBounds.shift(textOffset);
      canvas.save();
      canvas.clipRect(clipBounds);
      if (activeMix < 0.999) {
        canvas.saveLayer(
          clipBounds,
          Paint()..color = Colors.white.withValues(alpha: activeMix),
        );
      }
      painter.paint(canvas, textOffset);
      if (activeMix < 0.999) canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintTextPainter(
    Canvas canvas,
    TextPainter painter,
    CadenzaWordFragment fragment, {
    required Offset relativeOffset,
    required double relativeScale,
    required double relativeRotation,
  }) {
    canvas.save();
    canvas.translate(
      fragment.center.dx + relativeOffset.dx,
      fragment.center.dy + relativeOffset.dy,
    );
    canvas.rotate(fragment.rotation + relativeRotation);
    canvas.scale(fragment.paintScale * relativeScale);
    painter.paint(
      canvas,
      Offset(-fragment.textSize.width / 2, -fragment.textSize.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CadenzaLyricPainter oldDelegate) {
    return !identical(data, oldDelegate.data) ||
        !identical(previousData, oldDelegate.previousData) ||
        !identical(position, oldDelegate.position) ||
        !identical(transition, oldDelegate.transition);
  }
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
