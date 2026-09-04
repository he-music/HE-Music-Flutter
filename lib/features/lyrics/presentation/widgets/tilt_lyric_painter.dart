import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/tilt_lyric_layout.dart';

@immutable
class TiltLyricPainter extends CustomPainter {
  const TiltLyricPainter({
    required this.layout,
    required this.timelinePosition,
    required this.normalStyle,
    required this.tiltStyle,
    required this.palette,
    this.highlightColor,
    this.textDirection = TextDirection.ltr,
    this.textScaleFactor = 1,
    this.revealAnimation = true,
    this.positionListenable,
    Listenable? repaint,
  }) : super(repaint: repaint ?? positionListenable);

  final TiltLyricLineLayout? layout;
  final Duration timelinePosition;
  final TextStyle normalStyle;
  final TextStyle tiltStyle;
  final PlayerScenePalette palette;
  final Color? highlightColor;
  final bool revealAnimation;
  final TextDirection textDirection;
  final double textScaleFactor;
  final ValueListenable<Duration>? positionListenable;

  @override
  void paint(Canvas canvas, Size size) {
    final value = layout;
    final currentPosition = positionListenable?.value ?? timelinePosition;
    if (value == null) return;
    for (final segment in value.segments) {
      final entryProgress = revealAnimation
          ? _entryProgress(currentPosition, segment.revealAt)
          : 1.0;
      if (entryProgress <= 0) continue;
      canvas.save();
      canvas.translate(segment.origin.dx, segment.origin.dy);
      if (entryProgress < 1) {
        canvas.scale(entryProgress, entryProgress);
        canvas.translate(
          segment.size.width * (1 - entryProgress) / (2 * entryProgress),
          segment.size.height * (1 - entryProgress) / (2 * entryProgress),
        );
      }
      _paintSegment(canvas, segment, currentPosition);
      canvas.restore();
    }
  }

  void _paintSegment(
    Canvas canvas,
    TiltLyricSegmentLayout segment,
    Duration currentPosition,
  ) {
    final style = segment.isTilt ? tiltStyle : normalStyle;
    if (!segment.isTilt) {
      _paintText(
        canvas,
        segment.text,
        Offset.zero,
        style.copyWith(color: palette.foreground),
        textDirection: textDirection,
      );
      return;
    }
    for (final grapheme in segment.graphemes) {
      final progress = grapheme.isTimed
          ? _graphemeProgress(currentPosition, grapheme.start!, grapheme.end!)
          : 0.25;
      final color = Color.lerp(
        palette.foreground.withValues(alpha: 0.72),
        highlightColor ?? palette.accent,
        progress,
      )!;
      final offset = Offset(
        grapheme.localBounds.left,
        grapheme.staggerSign * 3,
      );
      _paintText(
        canvas,
        grapheme.text,
        offset,
        style.copyWith(color: color),
        textDirection: textDirection,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: TextScaler.linear(textScaleFactor),
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TiltLyricPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.timelinePosition != timelinePosition ||
        oldDelegate.normalStyle != normalStyle ||
        oldDelegate.tiltStyle != tiltStyle ||
        oldDelegate.palette != palette ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.textScaleFactor != textScaleFactor ||
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

double _entryProgress(Duration position, Duration revealAt) =>
    Curves.easeOutCubic.transform(resolveTiltEntryProgress(position, revealAt));

double _graphemeProgress(Duration position, Duration start, Duration end) =>
    Curves.easeOutCubic.transform(
      resolveTiltGraphemeProgress(position, start, end),
    );
