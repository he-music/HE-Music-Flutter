import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../helpers/lyric_painter_owner.dart';
import '../helpers/monet_lyric_layout.dart';

class StarTunnelPaintRow implements LyricPaintResources {
  StarTunnelPaintRow({
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

  @override
  Iterable<TextPainter> get textPainters => [base, highlight, ?subtitle];
}

/// Perspective is shared by painting and hit testing. The focus plane is stable
/// between line changes; only the short transition moves through depth.
class StarTunnelLyricPainter extends CustomPainter {
  StarTunnelLyricPainter({
    required this.rows,
    required this.anchor,
    required this.activeIndex,
    required this.positionListenable,
    required this.motion,
    required this.fromDepth,
    required this.documentOffset,
    required this.wordHighlight,
    required this.color,
    this.debugOnPaint,
  }) : super(repaint: Listenable.merge([positionListenable, motion]));

  final List<StarTunnelPaintRow> rows;
  final int anchor;
  final int? activeIndex;
  final ValueListenable<Duration> positionListenable;
  final ValueListenable<double> motion;
  final double fromDepth;
  final int documentOffset;
  final bool wordHighlight;
  final Color color;
  final VoidCallback? debugOnPaint;

  double get depthOffset => fromDepth * math.pow(1 - motion.value, 3);
  double depthOf(StarTunnelPaintRow row) =>
      row.entry.index - anchor + depthOffset;
  double scaleAt(double depth) =>
      math.pow(0.60, depth.clamp(-1.0, 5)).toDouble();
  Offset centerAt(Size size, double depth) =>
      Offset(size.width / 2, size.height * (0.16 + 0.42 * scaleAt(depth)));
  double opacityAt(double depth) => depth < 0
      ? (1 + depth).clamp(0.0, 1.0)
      : (1 / (1 + depth * 1.35)) * ((4 - depth).clamp(0.0, 1.0));

  Rect boundsFor(StarTunnelPaintRow row, Size size) {
    final depth = depthOf(row);
    final scale = scaleAt(depth);
    return Rect.fromCenter(
      center: centerAt(size, depth),
      width: row.base.width * scale,
      height: row.base.height * scale,
    );
  }

  Iterable<StarTunnelPaintRow> visibleRows(Size size) sync* {
    double? nearTop;
    for (final row in rows) {
      if (opacityAt(depthOf(row)) <= 0) continue;
      final bounds = boundsFor(row, size);
      // Large accessibility text can exhaust a short viewport. Preserve the
      // nearest line instead of layering distant text over it.
      if (nearTop != null && bounds.bottom + 6 > nearTop) continue;
      yield row;
      nearTop = bounds.top;
    }
  }

  StarTunnelPaintRow? rowAt(Offset point, Size size) {
    // Nearest text is painted last, and owns overlapping hit regions.
    for (final row in visibleRows(size)) {
      final depth = depthOf(row);
      if (opacityAt(depth) > 0.15 && boundsFor(row, size).contains(point)) {
        return row;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final vanishing = Offset(size.width / 2, size.height * 0.16);
    // Deterministic stars: no timers, random allocations, or ambient ticker.
    for (var i = 0; i < 32; i++) {
      final angle = i * 2.399963;
      final radius = 0.12 + (i % 9) * 0.10;
      final travel = 1 + 0.12 * math.sin(motion.value * math.pi);
      final ray = Offset(
        math.cos(angle) * size.width * 0.55,
        math.sin(angle) * size.height * 0.7,
      );
      final point = vanishing + ray * radius * travel;
      final ink = Paint()
        ..color = color.withValues(alpha: 0.10 + (i % 3) * 0.055);
      canvas.drawCircle(point, i % 4 == 0 ? 1.4 : 0.8, ink);
      if (depthOffset > 0 && depthOffset < 1) {
        ink.strokeWidth = 0.8;
        canvas.drawLine(
          point,
          point - ray * (0.025 * math.sin(motion.value * math.pi)),
          ink,
        );
      }
    }
    final timeline =
        positionListenable.value + Duration(milliseconds: documentOffset);
    for (final row in visibleRows(size).toList().reversed) {
      final depth = depthOf(row);
      final opacity = opacityAt(depth);
      if (opacity <= 0) continue;
      final center = centerAt(size, depth);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scaleAt(depth));
      canvas.translate(-row.base.width / 2, -row.base.height / 2);
      canvas.saveLayer(
        Offset.zero & row.base.size,
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
      row.base.paint(canvas, Offset.zero);
      if (row.entry.index == activeIndex) {
        if (!wordHighlight || !row.tokens.any((token) => token.hasTiming)) {
          row.highlight.paint(canvas, Offset.zero);
        } else {
          for (var i = 0; i < row.tokens.length; i++) {
            final progress = resolveMonetTokenProgress(
              timelinePosition: timeline,
              token: row.tokens[i],
            );
            var remaining =
                row.boxes[i].fold<double>(
                  0,
                  (sum, box) => sum + box.right - box.left,
                ) *
                progress;
            for (final box in row.boxes[i]) {
              final width = math.min(remaining, box.right - box.left);
              if (width <= 0) break;
              remaining -= width;
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
      canvas.restore();
      canvas.restore();
    }
    // Auxiliary text never enters the perspective transform.
    final selected = rows.where((row) => row.entry.index == anchor).firstOrNull;
    final subtitle = selected?.subtitle;
    if (subtitle != null && selected != null) {
      final y = size.height * 0.58 + selected.base.height / 2 + 18;
      if (y + subtitle.height <= size.height - 8) {
        subtitle.paint(canvas, Offset((size.width - subtitle.width) / 2, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarTunnelLyricPainter oldDelegate) =>
      !identical(rows, oldDelegate.rows) ||
      anchor != oldDelegate.anchor ||
      activeIndex != oldDelegate.activeIndex ||
      fromDepth != oldDelegate.fromDepth ||
      documentOffset != oldDelegate.documentOffset ||
      wordHighlight != oldDelegate.wordHighlight ||
      color != oldDelegate.color ||
      positionListenable != oldDelegate.positionListenable ||
      motion != oldDelegate.motion;
}
