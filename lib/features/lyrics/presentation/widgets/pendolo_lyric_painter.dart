import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../helpers/lyric_painter_owner.dart';
import '../helpers/monet_lyric_layout.dart';
import '../helpers/pendolo_lyric_layout.dart';

// Bounded, premeasured wheel rows; playback updates only paint cached paragraphs.
class PendoloPaintRow implements LyricPaintResources {
  PendoloPaintRow({
    required this.entry,
    required this.base,
    required this.highlight,
    required this.subtitle,
    required this.tokens,
    required this.boxes,
  });

  final MonetVisibleLyricLine entry;
  final TextPainter base;
  final TextPainter highlight;
  final TextPainter? subtitle;
  final List<MonetDisplayToken> tokens;
  final List<List<TextBox>> boxes;
  double get height =>
      base.height + (subtitle == null ? 0 : subtitle!.height + 6);

  @override
  Iterable<TextPainter> get textPainters => [base, highlight, ?subtitle];
}

class PendoloLyricPainter extends CustomPainter {
  PendoloLyricPainter({
    required this.rows,
    required this.anchor,
    required this.activeIndex,
    required this.geometry,
    required this.angles,
    required this.positionListenable,
    required this.motion,
    required this.fromAngle,
    required this.documentOffset,
    required this.wordHighlight,
    required this.color,
    this.debugOnPaint,
  }) : super(repaint: Listenable.merge([positionListenable, motion]));

  final List<PendoloPaintRow> rows;
  final int anchor;
  final int? activeIndex;
  final PendoloWheelGeometry geometry;
  final List<double> angles;
  final ValueListenable<Duration> positionListenable;
  final ValueListenable<double> motion;
  final double fromAngle;
  final int documentOffset;
  final bool wordHighlight;
  final Color color;
  final VoidCallback? debugOnPaint;

  double get angleOffset => fromAngle * (1 - pendoloEscapement(motion.value));

  /// Hit tests in the same rotated coordinate system used by the painter.
  PendoloPaintRow? rowAt(Offset point) {
    for (var i = rows.length - 1; i >= 0; i--) {
      final angle = angles[i] + angleOffset;
      if (angle.abs() >= math.pi / 2) continue;
      final delta = point - geometry.point(angle);
      final local = Offset(
        delta.dx * math.cos(angle) + delta.dy * math.sin(angle),
        -delta.dx * math.sin(angle) + delta.dy * math.cos(angle),
      );
      if (Rect.fromLTWH(
        0,
        -rows[i].height / 2,
        geometry.textWidth,
        rows[i].height,
      ).contains(local)) {
        return rows[i];
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final ink = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(geometry.center, geometry.radius - 12, ink);
    for (var tick = -12; tick <= 12; tick++) {
      final angle = tick * 0.12 + angleOffset;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        geometry.center + unit * (geometry.radius - 19),
        geometry.center + unit * (geometry.radius - (tick % 3 == 0 ? 28 : 23)),
        ink,
      );
    }
    final timeline =
        positionListenable.value + Duration(milliseconds: documentOffset);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final angle = angles[i] + angleOffset;
      if (angle.abs() >= math.pi / 2) continue;
      final active = row.entry.index == activeIndex;
      canvas.save();
      final origin = geometry.point(angle);
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle);
      canvas.translate(0, -row.height / 2);
      row.base.paint(canvas, Offset.zero);
      if (active) {
        if (!wordHighlight || !row.tokens.any((token) => token.hasTiming)) {
          row.highlight.paint(canvas, Offset.zero);
        } else {
          for (var t = 0; t < row.tokens.length; t++) {
            final progress = resolveMonetTokenProgress(
              timelinePosition: timeline,
              token: row.tokens[t],
            );
            if (progress <= 0) continue;
            final boxes = row.boxes[t];
            var remaining =
                boxes.fold<double>(
                  0,
                  (sum, box) => sum + box.right - box.left,
                ) *
                progress;
            for (final box in boxes) {
              final width = math.min(remaining, box.right - box.left);
              remaining -= width;
              if (width <= 0) break;
              canvas.save();
              canvas.clipRect(
                Rect.fromLTRB(
                  box.direction == TextDirection.rtl
                      ? box.right - width
                      : box.left,
                  box.top,
                  box.direction == TextDirection.rtl
                      ? box.right
                      : box.left + width,
                  box.bottom,
                ),
              );
              row.highlight.paint(canvas, Offset.zero);
              canvas.restore();
            }
          }
        }
      }
      row.subtitle?.paint(canvas, Offset(0, row.base.height + 6));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PendoloLyricPainter oldDelegate) =>
      !identical(rows, oldDelegate.rows) ||
      anchor != oldDelegate.anchor ||
      activeIndex != oldDelegate.activeIndex ||
      fromAngle != oldDelegate.fromAngle ||
      documentOffset != oldDelegate.documentOffset ||
      wordHighlight != oldDelegate.wordHighlight ||
      color != oldDelegate.color ||
      geometry.center != oldDelegate.geometry.center ||
      geometry.radius != oldDelegate.geometry.radius ||
      positionListenable != oldDelegate.positionListenable ||
      motion != oldDelegate.motion;
}
