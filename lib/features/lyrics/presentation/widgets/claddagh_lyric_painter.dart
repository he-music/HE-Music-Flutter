import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../helpers/claddagh_lyric_layout.dart';
import '../helpers/lyric_painter_owner.dart';
import '../helpers/monet_lyric_layout.dart';

// Glyph resources are measured only when the bounded visible window changes.
class CladdaghPaintRow implements LyricPaintResources {
  CladdaghPaintRow({
    required this.entry,
    required this.subtitle,
    required this.tokens,
    required this.glyphs,
    required this.highlights,
    required this.angles,
    required this.glyphScale,
  });
  final MonetVisibleLyricLine entry;
  final TextPainter? subtitle;
  final List<MonetDisplayToken> tokens;
  final List<TextPainter> glyphs;
  final List<TextPainter> highlights;
  final List<double> angles;
  final double glyphScale;
  @override
  Iterable<TextPainter> get textPainters => [
    ?subtitle,
    ...glyphs,
    ...highlights,
  ];

  double wordOffset(Duration timeline) {
    if (angles.isEmpty) return 0;
    if (!tokens.any((token) => token.hasTiming)) {
      final start = entry.line.start;
      final end = entry.line.end;
      if (end == null || end <= start) return 0;
      final progress =
          ((timeline - start).inMicroseconds / (end - start).inMicroseconds)
              .clamp(0.0, 1.0);
      return angles.first + (angles.last - angles.first) * progress;
    }
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!token.hasTiming) continue;
      if (timeline < token.start!) return angles[i];
      var nextIndex = i + 1;
      while (nextIndex < tokens.length && !tokens[nextIndex].hasTiming) {
        nextIndex++;
      }
      // Motion spans untimed separators continuously; highlight timing remains
      // the original token interval. Holding gaps uses the same next anchor.
      final end = nextIndex < tokens.length
          ? tokens[nextIndex].start!
          : token.end!;
      final next = nextIndex < angles.length
          ? angles[nextIndex]
          : angles.last + 0.10;
      if (timeline < end) {
        final duration = (end - token.start!).inMicroseconds;
        final progress = duration <= 0
            ? 1.0
            : ((timeline - token.start!).inMicroseconds / duration).clamp(
                0.0,
                1.0,
              );
        return angles[i] + (next - angles[i]) * progress;
      }
    }
    return angles.last + 0.10;
  }
}

class CladdaghLyricPainter extends CustomPainter {
  CladdaghLyricPainter({
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
  final List<CladdaghPaintRow> rows;
  final int anchor;
  final int? activeIndex;
  final CladdaghOrbitGeometry geometry;
  final List<double> angles;
  final ValueListenable<Duration> positionListenable;
  final Animation<double> motion;
  final double fromAngle;
  final int documentOffset;
  final bool wordHighlight;
  final Color color;
  final VoidCallback? debugOnPaint;
  final Paint _visibility = Paint();
  final Paint _axis = Paint()..strokeWidth = 1.5;
  double get angleOffset => fromAngle * (1 - claddaghTransition(motion.value));
  Duration get _timeline =>
      positionListenable.value + Duration(milliseconds: documentOffset);

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _axis.color = color.withValues(alpha: 0.25);
    final axis =
        Offset(math.cos(math.pi / 4), math.sin(math.pi / 4)) *
        math.min(size.shortestSide * 0.22, 80);
    canvas.drawLine(geometry.center - axis, geometry.center + axis, _axis);
    // Two passes keep receding glyphs behind the enlarged front of the orbit.
    for (final front in [false, true]) {
      for (final row in rows) {
        final offset = row.wordOffset(_timeline);
        final lineAngle = (row.entry.index - anchor) * math.pi + angleOffset;
        final distance = (lineAngle / math.pi).abs();
        final lineVisibility = (2 - distance).clamp(0.0, 1.0);
        if (lineVisibility == 0) continue;
        // Composite only fading rows, sharing opacity across base/highlight
        // glyphs without measuring text or allocating painters on frames.
        if (lineVisibility < 1) {
          _visibility.color = Colors.white.withValues(alpha: lineVisibility);
          canvas.saveLayer(Offset.zero & size, _visibility);
        }
        for (var i = 0; i < row.glyphs.length; i++) {
          final psi = lineAngle + row.angles[i] - offset;
          final depth = (math.cos(psi) + 1) / 2;
          if ((depth >= 0.5) != front) continue;
          final focus =
              math.pow(depth, 3) * math.pow((1 - distance).clamp(0.0, 1.0), 2);
          final scale = (0.35 + focus * 1.20) * row.glyphScale;
          canvas.save();
          final point = geometry.point(psi);
          canvas.translate(point.dx, point.dy);
          canvas.rotate(geometry.tangent(psi));
          canvas.scale(scale);
          final glyph = row.glyphs[i];
          final origin = Offset(-glyph.width / 2, -glyph.height / 2);
          glyph.paint(canvas, origin);
          if (row.entry.index == activeIndex && wordHighlight) {
            final p = resolveMonetTokenProgress(
              timelinePosition: _timeline,
              token: row.tokens[i],
            );
            if (p > 0) {
              canvas.save();
              canvas.clipRect(
                Rect.fromLTWH(
                  origin.dx,
                  origin.dy,
                  glyph.width * p,
                  glyph.height,
                ),
              );
              row.highlights[i].paint(canvas, origin);
              canvas.restore();
            }
          }
          canvas.restore();
        }
        if (lineVisibility < 1) canvas.restore();
      }
    }
    final selected = rows.where((row) => row.entry.index == anchor).firstOrNull;
    if (selected?.subtitle case final subtitle?) {
      subtitle.paint(
        canvas,
        Offset(
          (size.width - subtitle.width) / 2,
          size.height - subtitle.height - 18,
        ),
      );
    }
    canvas.restore();
  }

  CladdaghPaintRow? rowAt(Offset local) {
    CladdaghPaintRow? nearest;
    var distance = double.infinity;
    // Prefer the emphasized foreground line when both sides project nearby.
    for (final focused in [true, false]) {
      for (final row in rows) {
        if ((row.entry.index == anchor) != focused ||
            (row.entry.index - anchor).abs() > 1) {
          continue;
        }
        final wordOffset = row.wordOffset(_timeline);
        final lineAngle = (row.entry.index - anchor) * math.pi + angleOffset;
        for (var i = 0; i < row.glyphs.length; i++) {
          final psi = lineAngle + row.angles[i] - wordOffset;
          if (math.cos(psi) < 0) continue;
          final d = (geometry.point(psi) - local).distance;
          if (d < 28 && d < distance) {
            nearest = row;
            distance = d;
          }
        }
      }
      if (nearest != null) return nearest;
    }
    return nearest;
  }

  @override
  bool shouldRepaint(covariant CladdaghLyricPainter old) =>
      old.rows != rows ||
      old.anchor != anchor ||
      old.activeIndex != activeIndex ||
      old.geometry.size != geometry.size ||
      old.fromAngle != fromAngle ||
      old.documentOffset != documentOffset ||
      old.wordHighlight != wordHighlight ||
      old.color != color;
}
