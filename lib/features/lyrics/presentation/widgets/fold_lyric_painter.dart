import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../helpers/lyric_painter_owner.dart';
import '../helpers/monet_lyric_layout.dart';

/// Only cached text is painted; the surrounding player owns the background.
class FoldPaintRow implements LyricPaintResources {
  FoldPaintRow({
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

class FoldLyricPainter extends CustomPainter {
  FoldLyricPainter({
    required this.rows,
    required this.anchor,
    required this.activeIndex,
    required this.viewport,
    required this.position,
    required this.motion,
    required this.fromStep,
    required this.documentOffset,
    required this.wordHighlight,
    this.debugOnPaint,
  }) : super(repaint: Listenable.merge([position, motion]));

  final List<FoldPaintRow> rows;
  final int anchor;
  final int? activeIndex;
  final Size viewport;
  final ValueListenable<Duration> position;
  final ValueListenable<double> motion;
  final double fromStep;
  final int documentOffset;
  final bool wordHighlight;
  final VoidCallback? debugOnPaint;

  double get focus =>
      anchor - fromStep * (1 - Curves.easeOutBack.transform(motion.value));

  double _angle(FoldPaintRow row) {
    final distance = (row.entry.index - focus).abs().clamp(0.0, 1.0);
    final folded = Curves.easeInOut.transform(distance);
    return (row.entry.index.isEven ? 1 : -1) * 1.12 * folded;
  }

  double _height(FoldPaintRow row) {
    final angle = _angle(row);
    final depth = row.base.height * math.sin(angle) / 920;
    return row.base.height * math.cos(angle) / (1 - depth * depth);
  }

  /// Adjacent projected edges stay separated even with wrapped / scaled text.
  List<double> _centers() {
    if (rows.isEmpty) return const [];
    final centers = List<double>.filled(rows.length, 0);
    for (var i = 1; i < rows.length; i++) {
      centers[i] =
          centers[i - 1] + (_height(rows[i - 1]) + _height(rows[i])) / 2 + 24;
    }
    final localFocus = (focus - rows.first.entry.index).clamp(
      0.0,
      rows.length - 1.0,
    );
    final lower = localFocus.floor();
    final upper = math.min(lower + 1, rows.length - 1);
    final origin =
        centers[lower] +
        (centers[upper] - centers[lower]) * (localFocus - lower);
    return centers.map((y) => y - origin + viewport.height * 0.43).toList();
  }

  Matrix4 _transform(int i, List<double> centers) {
    final row = rows[i];
    final distance = (row.entry.index - focus).abs();
    final scale = 1 - 0.12 * distance.clamp(0.0, 2.0);
    return Matrix4.identity()
      ..translateByDouble(viewport.width / 2, centers[i], 0, 1)
      ..multiply(Matrix4.identity()..setEntry(3, 2, 1 / 460))
      ..rotateX(_angle(row))
      ..scaleByDouble(scale, 1, 1, 1)
      ..translateByDouble(-row.base.width / 2, -row.base.height / 2, 0, 1);
  }

  /// Hit testing uses the same perspective transform as painting.
  FoldPaintRow? rowAt(Offset point) {
    if (!(Offset.zero & viewport).contains(point) ||
        point.dy > viewport.height * 0.80) {
      return null;
    }
    final centers = _centers();
    for (var i = rows.length - 1; i >= 0; i--) {
      // Solve the planar homography; a 4D inverse at z=0 is not sufficient
      // for a tilted plane under perspective projection.
      final m = _transform(i, centers).storage;
      final a = m[0] - point.dx * m[3];
      final b = m[4] - point.dx * m[7];
      final c = point.dx * m[15] - m[12];
      final d = m[1] - point.dy * m[3];
      final e = m[5] - point.dy * m[7];
      final f = point.dy * m[15] - m[13];
      final determinant = a * e - b * d;
      if (determinant.abs() < 0.00001) continue;
      final local = Offset(
        (c * e - b * f) / determinant,
        (a * f - c * d) / determinant,
      );
      if ((Offset.zero & rows[i].base.size).inflate(8).contains(local)) {
        return rows[i];
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call();
    final centers = _centers();
    final timeline = position.value + Duration(milliseconds: documentOffset);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.80));
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final distance = (row.entry.index - focus).abs();
      final opacity = (1 - distance * 0.26).clamp(0.12, 1.0);
      canvas.save();
      canvas.transform(_transform(i, centers).storage);
      canvas.saveLayer(
        (Offset.zero & row.base.size).inflate(2),
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
      row.base.paint(canvas, Offset.zero);
      if (row.entry.index == activeIndex) {
        if (!wordHighlight || !row.tokens.any((token) => token.hasTiming)) {
          row.highlight.paint(canvas, Offset.zero);
        } else {
          final path = Path();
          for (var t = 0; t < row.tokens.length; t++) {
            final progress = resolveMonetTokenProgress(
              timelinePosition: timeline,
              token: row.tokens[t],
            );
            final boxes = row.boxes[t];
            var remaining =
                boxes.fold<double>(
                  0,
                  (sum, box) => sum + box.right - box.left,
                ) *
                progress;
            for (final box in boxes) {
              final width = math.min(remaining, box.right - box.left);
              if (width <= 0) break;
              remaining -= width;
              path.addRect(
                Rect.fromLTWH(
                  box.direction == TextDirection.rtl
                      ? box.right - width
                      : box.left,
                  box.top,
                  width,
                  box.bottom - box.top,
                ),
              );
            }
          }
          canvas.save();
          canvas.clipPath(path);
          row.highlight.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
    final subtitle = rows
        .where((row) => row.entry.index == anchor)
        .firstOrNull
        ?.subtitle;
    if (subtitle != null) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      subtitle.paint(
        canvas,
        Offset((size.width - subtitle.width) / 2, size.height * 0.84),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FoldLyricPainter oldDelegate) =>
      rows != oldDelegate.rows ||
      anchor != oldDelegate.anchor ||
      activeIndex != oldDelegate.activeIndex ||
      viewport != oldDelegate.viewport ||
      position != oldDelegate.position ||
      motion != oldDelegate.motion ||
      fromStep != oldDelegate.fromStep ||
      documentOffset != oldDelegate.documentOffset ||
      wordHighlight != oldDelegate.wordHighlight;
}
