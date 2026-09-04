import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/tilt_lyric_layout.dart';

@immutable
class TiltGraphemePaintData {
  const TiltGraphemePaintData({
    required this.layout,
    required this.bodyPainter,
    required this.activePainter,
    required this.bodyColor,
    required this.activeColor,
  });

  final TiltGraphemePlacement layout;
  final TextPainter bodyPainter;
  final TextPainter? activePainter;
  final Color bodyColor;
  final Color? activeColor;
}

@immutable
class TiltSegmentPaintData {
  const TiltSegmentPaintData({required this.layout, required this.graphemes});

  final TiltLyricSegmentLayout layout;
  final List<TiltGraphemePaintData> graphemes;
}

@immutable
class TiltLyricRenderData {
  const TiltLyricRenderData({
    required this.layout,
    required this.segments,
    required this.scaleCenterY,
  });

  final TiltLyricLineLayout? layout;
  final List<TiltSegmentPaintData> segments;
  final double scaleCenterY;
}

TiltLyricRenderData buildTiltLyricRenderData({
  required TiltLyricLineLayout? layout,
  required TextStyle normalStyle,
  required TextStyle tiltStyle,
  required PlayerScenePalette palette,
  required Color? highlightColor,
  required TextDirection textDirection,
  required Locale? locale,
  required double textScaleFactor,
  VoidCallback? debugOnTextLayout,
}) {
  if (layout == null) {
    return TiltLyricRenderData(
      layout: null,
      segments: const <TiltSegmentPaintData>[],
      scaleCenterY: normalStyle.fontSize ?? 16,
    );
  }

  TextPainter layoutPainter(String text, TextStyle style) {
    debugOnTextLayout?.call();
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      locale: locale,
      textScaler: TextScaler.linear(textScaleFactor),
      maxLines: 1,
    )..layout();
  }

  final pulseLine =
      layout.sourceLine.text == tiltInterludeText &&
      layout.sourceLine.tokens.length == 6 &&
      layout.sourceLine.tokens.every((token) => token.text == '.');
  final segments = layout.segments
      .map((segment) {
        final style = segment.isTilt ? tiltStyle : normalStyle;
        final usesActiveColor = segment.isTilt || pulseLine;
        final bodyColor = usesActiveColor
            ? palette.foreground.withValues(alpha: 0.72)
            : palette.foreground;
        final graphemes = segment.graphemes
            .map(
              (grapheme) => TiltGraphemePaintData(
                layout: grapheme,
                bodyPainter: layoutPainter(
                  grapheme.text,
                  style.copyWith(color: bodyColor),
                ),
                activePainter: usesActiveColor
                    ? layoutPainter(
                        grapheme.text,
                        style.copyWith(color: highlightColor ?? palette.accent),
                      )
                    : null,
                bodyColor: bodyColor,
                activeColor: usesActiveColor
                    ? highlightColor ?? palette.accent
                    : null,
              ),
            )
            .toList(growable: false);
        return TiltSegmentPaintData(
          layout: segment,
          graphemes: List<TiltGraphemePaintData>.unmodifiable(graphemes),
        );
      })
      .toList(growable: false);
  return TiltLyricRenderData(
    layout: layout,
    segments: List<TiltSegmentPaintData>.unmodifiable(segments),
    scaleCenterY: normalStyle.fontSize ?? 16,
  );
}

@immutable
class TiltLyricPainter extends CustomPainter {
  const TiltLyricPainter({
    required this.data,
    required this.timelinePosition,
    this.revealAnimation = true,
    this.positionListenable,
    this.onPaint,
    Listenable? repaint,
  }) : super(repaint: repaint ?? positionListenable);

  final TiltLyricRenderData data;
  final Duration timelinePosition;
  final bool revealAnimation;
  final ValueListenable<Duration>? positionListenable;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    final layout = data.layout;
    final currentPosition = positionListenable?.value ?? timelinePosition;
    if (layout == null) return;
    final lineActive =
        currentPosition >= layout.sourceLine.start &&
        (layout.sourceLine.end == null ||
            currentPosition <= layout.sourceLine.end!);
    for (final segment in data.segments) {
      final entryProgress = revealAnimation
          ? _entryProgress(currentPosition, segment.layout.revealAt)
          : 1.0;
      if (entryProgress <= 0) continue;
      canvas.save();
      canvas.translate(segment.layout.origin.dx, segment.layout.origin.dy);
      final fitScale = segment.layout.paintScale;
      canvas.scale(fitScale);
      final localSize = Size(
        segment.layout.size.width / fitScale,
        segment.layout.size.height / fitScale,
      );
      if (entryProgress < 1) {
        canvas.scale(entryProgress, entryProgress);
        canvas.translate(
          localSize.width * (1 - entryProgress) / (2 * entryProgress),
          localSize.height * (1 - entryProgress) / (2 * entryProgress),
        );
      }
      _paintSegment(canvas, segment, currentPosition, lineActive);
      canvas.restore();
    }
  }

  void _paintSegment(
    Canvas canvas,
    TiltSegmentPaintData segment,
    Duration currentPosition,
    bool lineActive,
  ) {
    for (final grapheme in segment.graphemes) {
      final placement = grapheme.layout;
      final progress = placement.isTimed
          ? _graphemeProgress(currentPosition, placement.start!, placement.end!)
          : 0.0;
      final activeScale = placement.isTimed
          ? resolveTiltGraphemeScale(
              currentPosition,
              placement.start!,
              placement.end!,
            )
          : lineActive
          ? 1.12
          : 1.0;
      _paintGrapheme(canvas, grapheme, progress, activeScale);
    }
  }

  void _paintGrapheme(
    Canvas canvas,
    TiltGraphemePaintData grapheme,
    double activeProgress,
    double scale,
  ) {
    final placement = grapheme.layout;
    final width = math.max(placement.localBounds.width, 1);
    final center = Offset(
      placement.localBounds.left + width / 2,
      data.scaleCenterY,
    );
    final offset = Offset(
      placement.localBounds.left,
      placement.staggerSign * 3,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    final activePainter = grapheme.activePainter;
    if (activePainter == null || activeProgress <= 0) {
      grapheme.bodyPainter.paint(canvas, offset);
    } else if (activeProgress >= 1) {
      activePainter.paint(canvas, offset);
    } else {
      final color = Color.lerp(
        grapheme.bodyColor,
        grapheme.activeColor,
        activeProgress,
      )!;
      final padding = math.max(activePainter.height * 0.25, 2);
      final bounds = Rect.fromLTWH(
        offset.dx - padding,
        offset.dy - padding,
        activePainter.width + padding * 2,
        activePainter.height + padding * 2,
      );
      canvas.saveLayer(bounds, Paint());
      activePainter.paint(canvas, offset);
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TiltLyricPainter oldDelegate) {
    return !identical(oldDelegate.data, data) ||
        oldDelegate.timelinePosition != timelinePosition ||
        oldDelegate.revealAnimation != revealAnimation;
  }
}

@visibleForTesting
double resolveTiltEntryProgress(Duration position, Duration revealAt) {
  const duration = Duration(milliseconds: 250);
  if (position <= revealAt) return 0;
  if (position >= revealAt + duration) return 1;
  return ((position - revealAt).inMicroseconds / duration.inMicroseconds).clamp(
    0.0,
    1.0,
  );
}

@visibleForTesting
double resolveTiltGraphemeProgress(
  Duration position,
  Duration start,
  Duration end,
) {
  if (end <= start || position <= start) return 0;
  if (position >= end) return 1;
  return ((position - start).inMicroseconds / (end - start).inMicroseconds)
      .clamp(0.0, 1.0);
}

@visibleForTesting
double resolveTiltGraphemeScale(
  Duration position,
  Duration start,
  Duration end,
) {
  final progress = resolveTiltGraphemeProgress(position, start, end);
  return 1 + 0.3 * math.sin(math.pi * progress);
}

double _entryProgress(Duration position, Duration revealAt) =>
    Curves.easeOutCubic.transform(resolveTiltEntryProgress(position, revealAt));

double _graphemeProgress(Duration position, Duration start, Duration end) =>
    Curves.easeOutCubic.transform(
      resolveTiltGraphemeProgress(position, start, end),
    );
