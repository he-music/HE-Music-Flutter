import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/kinetic_lyric_layout.dart';

class KineticNotePose {
  const KineticNotePose(
    this.point,
    this.rotation,
    this.opacity, {
    this.glow = 1,
  });
  final Offset point;
  final double rotation;
  final double opacity;
  final double glow;
}

class _CameraStop {
  const _CameraStop(this.time, this.moveStart, this.y, this.lineIndex);
  final Duration time;
  final Duration moveStart;
  final double y;
  final int lineIndex;
}

class _NoteTarget {
  const _NoteTarget(this.row, this.start, this.end, [this.glyph]);
  final KineticPaintLine row;
  final Duration start;
  final Duration? end;
  final KineticPaintGlyph? glyph;

  Offset point(Size size) {
    if (glyph != null) {
      return glyph!.center + Offset(0, row.y - glyph!.painter.height * .7);
    }
    final side = row.fallback.textDirection == TextDirection.rtl ? 1 : -1;
    final x = size.width / 2 + side * (row.fallback.width / 2 + 28);
    return Offset(x.clamp(8.0, math.max(8.0, size.width - 8)), row.y);
  }
}

class KineticLyricPainter extends CustomPainter {
  KineticLyricPainter({
    required this.rows,
    required this.anchor,
    required this.position,
    required this.followPlayback,
    required this.documentOffset,
    required this.wordHighlight,
    required this.reducedMotion,
    required this.color,
    required this.trailStart,
    this.debugOnPaint,
  }) : super(repaint: position) {
    for (final row in rows) {
      if (row.entry.isInterlude || row.entry.line.text.trim().isEmpty) continue;
      if (animated(row)) {
        for (final glyph in row.glyphs) {
          if (glyph.source.start != null &&
              glyph.source.text.trim().isNotEmpty) {
            _targets.add(
              _NoteTarget(row, glyph.source.start!, glyph.source.end, glyph),
            );
          }
        }
      } else {
        _targets.add(
          _NoteTarget(row, row.entry.line.start, row.entry.line.end),
        );
      }
    }
    Duration? previousOnset;
    void addStop(Duration time, double y, int lineIndex) {
      final earliest = time - const Duration(milliseconds: 650);
      _cameraStops.add(
        _CameraStop(
          time,
          previousOnset != null && previousOnset > earliest
              ? previousOnset
              : earliest,
          y,
          lineIndex,
        ),
      );
    }

    for (final row in rows) {
      if (!animated(row)) {
        addStop(row.entry.line.start, row.y, row.entry.index);
        previousOnset = row.entry.line.start;
        continue;
      }
      double? baseline;
      for (final glyph in row.glyphs) {
        final start = glyph.source.start;
        if (start == null || glyph.source.text.trim().isEmpty) continue;
        if (glyph.rowY != baseline) {
          addStop(start, row.y + glyph.rowY, row.entry.index);
          baseline = glyph.rowY;
        }
        previousOnset = start;
      }
    }
  }

  final List<KineticPaintLine> rows;
  final int anchor;
  final ValueListenable<Duration> position;
  final bool followPlayback;
  final int documentOffset;
  final bool wordHighlight;
  final bool reducedMotion;
  final Color color;
  final Duration trailStart;
  final VoidCallback? debugOnPaint;
  final List<_NoteTarget> _targets = [];
  final List<_CameraStop> _cameraStops = [];

  Duration get timeline =>
      position.value + Duration(milliseconds: documentOffset);

  bool animated(KineticPaintLine row) =>
      wordHighlight && !reducedMotion && row.hasTiming;

  double get focusY => -cameraShift;
  double get cameraShift => cameraShiftAt(timeline);

  /// Move while the note is in flight and arrive before its landing. Re-basing
  /// the visible window at a line boundary does not change screen coordinates.
  double cameraShiftAt(Duration time) {
    if (!followPlayback || reducedMotion || _cameraStops.isEmpty) return 0;
    final (index, progress) = _cameraProgressAt(time);
    final current = _cameraStops[index];
    if (index + 1 >= _cameraStops.length) return -current.y;
    final next = _cameraStops[index + 1];
    return -current.y - (next.y - current.y) * progress;
  }

  double lineFocusAt(int lineIndex, Duration time) {
    if (!followPlayback || reducedMotion || _cameraStops.isEmpty) {
      return lineIndex == anchor ? 1 : 0;
    }
    final (index, progress) = _cameraProgressAt(time);
    final current = _cameraStops[index];
    final next = index + 1 < _cameraStops.length
        ? _cameraStops[index + 1]
        : null;
    if (next == null || current.lineIndex == next.lineIndex) {
      return lineIndex == current.lineIndex ? 1 : 0;
    }
    if (lineIndex == current.lineIndex) return 1 - progress;
    if (lineIndex == next.lineIndex) return progress;
    return 0;
  }

  (int, double) _cameraProgressAt(Duration time) {
    var low = 0;
    var high = _cameraStops.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_cameraStops[mid].time <= time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final index = (low - 1).clamp(0, _cameraStops.length - 1);
    if (index + 1 >= _cameraStops.length) return (index, 0);
    final next = _cameraStops[index + 1];
    if (time <= next.moveStart) return (index, 0);
    final span = (next.time - next.moveStart).inMicroseconds;
    final p = span <= 0
        ? 1.0
        : ((time - next.moveStart).inMicroseconds / span).clamp(0.0, 1.0);
    return (index, Curves.easeInOutCubic.transform(p));
  }

  KineticPaintLine? rowAt(Offset point, Size size) {
    final shift = size.height * .48 + cameraShift;
    for (final row in rows) {
      if (animated(row)) {
        for (final glyph in row.glyphs) {
          final bounds = Rect.fromCenter(
            center: glyph.center + Offset(0, shift + row.y),
            width: glyph.painter.width + 20,
            height: glyph.painter.height + 24,
          );
          if (bounds.contains(point)) return row;
        }
      } else {
        final bounds = Rect.fromCenter(
          center: Offset(size.width / 2, shift + row.y),
          width: row.fallback.width + 20,
          height: row.fallback.height + 24,
        );
        if (bounds.contains(point)) return row;
      }
    }
    return null;
  }

  KineticNotePose? noteAt(Duration time, Size size) {
    if (!followPlayback) return null;
    var low = 0;
    var high = _targets.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_targets[mid].start <= time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final index = low - 1;
    if (index < 0) return null;
    final current = _targets[index];
    final from = current.point(size);
    final next = index + 1 < _targets.length ? _targets[index + 1] : null;
    final end = current.end ?? next?.start;
    if (!reducedMotion &&
        next != null &&
        (end == null ||
            next.start - end <= const Duration(milliseconds: 900))) {
      final start =
          next.start -
          Duration(
            microseconds: math.min(
              650000,
              (next.start - current.start).inMicroseconds,
            ),
          );
      if (time < start) {
        return _sustainPose(
          from,
          time,
          current.start,
          end != null && end < start ? end : start,
        );
      }
      final span = (next.start - start).inMicroseconds;
      final p = span <= 0
          ? 1.0
          : ((time - start).inMicroseconds / span).clamp(0.0, 1.0);
      final to = next.point(size);
      // Line-only lyrics get a quiet transfer, not fabricated character beats.
      if (current.glyph == null && next.glyph == null) {
        return KineticNotePose(
          Offset.lerp(from, to, Curves.easeInOutCubic.transform(p))!,
          0,
          1,
        );
      }
      return KineticNotePose(
        kineticArc(from, to, p, size.height * .20),
        math.sin(p * math.pi) * .22 * (to.dx >= from.dx ? 1 : -1),
        1,
      );
    }
    final fade = end == null
        ? 1.0
        : 1 - ((time - end).inMilliseconds / 650).clamp(0.0, 1.0);
    if (fade <= 0) return null;
    return reducedMotion
        ? KineticNotePose(from, 0, fade)
        : _sustainPose(from, time, current.start, end, opacity: fade);
  }

  KineticNotePose _sustainPose(
    Offset from,
    Duration time,
    Duration start,
    Duration? end, {
    double opacity = 1,
  }) {
    if (end != null && (end - start).inMilliseconds < 700) {
      return KineticNotePose(from, 0, opacity);
    }
    // Breathing has no positional lift after impact. Playback time also freezes
    // the glow on pause and reproduces the same phase after a seek.
    final elapsed = (time - start).inMicroseconds / 1000;
    final remaining = end == null ? 280.0 : (end - time).inMicroseconds / 1000;
    final envelope =
        Curves.easeInOutCubic.transform((elapsed / 280).clamp(0.0, 1.0)) *
        Curves.easeInOutCubic.transform((remaining / 280).clamp(0.0, 1.0));
    final phase = elapsed / 1600 * math.pi * 2;
    return KineticNotePose(
      from,
      0,
      opacity,
      glow: 1 + (.5 - .5 * math.cos(phase)) * .25 * envelope,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // A transparent local pool of light keeps the selected player backdrop visible.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .055), Colors.transparent],
          radius: .8,
        ).createShader(Offset.zero & size),
    );
    final shift = cameraShift;
    canvas.translate(0, size.height * .48 + shift);
    final viewport = Rect.fromLTWH(
      0,
      -size.height * .48 - shift,
      size.width,
      size.height,
    );
    final time = timeline;
    for (final row in rows) {
      final isTimed = animated(row);
      final mainTop =
          row.y + (isTimed ? row.glyphTop : -row.fallback.height / 2);
      final mainBottom =
          row.y + (isTimed ? row.glyphBottom : row.fallback.height / 2);
      // Fade at the viewport edge without a full-screen shader layer.
      final edgeOpacity = math
          .min(
            (mainBottom - viewport.top) / 32,
            (viewport.bottom - mainTop) / 32,
          )
          .clamp(0.0, 1.0);
      if (edgeOpacity <= 0) continue;
      final focus = lineFocusAt(row.entry.index, time);
      final active = focus > 0;
      final neighborOpacity = row.y + shift < 0 ? .16 : .28;
      final rowOpacity =
          (neighborOpacity + (1 - neighborOpacity) * focus) * edgeOpacity;
      final bounds = row.bounds(isTimed);
      final layerBounds = Rect.fromLTWH(
        0,
        row.y + bounds.top - 12,
        size.width,
        bounds.bottom - bounds.top + 24,
      ).intersect(viewport);
      final layered = rowOpacity < 1;
      if (layered) {
        canvas.saveLayer(
          layerBounds,
          Paint()..color = Colors.white.withValues(alpha: rowOpacity),
        );
      }
      if (!isTimed) {
        row.fallback.paint(
          canvas,
          Offset(
            (size.width - row.fallback.width) / 2,
            row.y - row.fallback.height / 2,
          ),
        );
        if (active) {
          _subtitle(
            canvas,
            row,
            size,
            row.y + row.fallback.height / 2 + 20,
            opacity: focus,
          );
        }
        if (layered) canvas.restore();
        continue;
      }
      for (final glyph in row.glyphs) {
        final center = glyph.center + Offset(0, row.y);
        final screenY = center.dy + size.height * .48 + shift;
        if (screenY < -80 || screenY > size.height + 80) continue;
        final start = glyph.source.start;
        final age = start == null ? 1000 : (time - start).inMilliseconds;
        final upcoming = age < 0;
        final wordOpacity = upcoming
            ? .28 + .34 * (1 + age / 500).clamp(0.0, 1.0)
            : 1.0;
        final opacity = 1 + (wordOpacity - 1) * focus;
        final pulse = active && age >= 0 && age < 560
            ? Curves.easeOutCubic.transform((age / 70).clamp(0.0, 1.0)) *
                  math.exp(-age / 180) *
                  focus
            : 0.0;
        canvas.save();
        canvas.translate(center.dx, center.dy - pulse * 12);
        canvas.rotate(glyph.rotation);
        canvas.scale(1 + pulse * .35);
        if (pulse > .01) {
          canvas.drawCircle(
            Offset.zero,
            45,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  color.withValues(alpha: pulse * .24),
                  color.withValues(alpha: 0),
                ],
              ).createShader(const Rect.fromLTWH(-45, -45, 90, 90)),
          );
        }
        final bounds = Rect.fromCenter(
          center: Offset.zero,
          width: glyph.painter.width + 20,
          height: glyph.painter.height + 20,
        );
        if (opacity < 1) {
          canvas.saveLayer(
            bounds,
            Paint()..color = Colors.white.withValues(alpha: opacity),
          );
        }
        glyph.painter.paint(
          canvas,
          Offset(-glyph.painter.width / 2, -glyph.painter.height / 2),
        );
        if (opacity < 1) canvas.restore();
        canvas.restore();
        if (active && age >= 0 && age < 640) {
          final p = age / 640;
          canvas.drawCircle(
            center - Offset(0, glyph.painter.height * .7),
            9 + p * 37,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4 * (1 - p) + .2
              ..color = color.withValues(alpha: (1 - p) * .48 * focus),
          );
        }
      }
      if (active) {
        _subtitle(canvas, row, size, row.y + row.subtitleY, opacity: focus);
      }
      if (layered) canvas.restore();
    }
    final pose = noteAt(timeline, size);
    if (pose != null) {
      KineticNotePose? previous;
      for (var i = reducedMotion ? -1 : 16; i >= 0; i--) {
        final t = time - Duration(milliseconds: i * 18);
        if (t < trailStart) continue;
        final current = noteAt(t, size);
        if (previous != null &&
            current != null &&
            (previous.point - current.point).distanceSquared > .01) {
          canvas.drawLine(
            previous.point,
            current.point,
            Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 1 + (1 - i / 17) * 2
              ..color = color.withValues(
                alpha: (1 - i / 17) * .55 * pose.opacity,
              ),
          );
        }
        previous = current;
      }
      _note(canvas, pose, viewport);
    }
    canvas.restore();
  }

  void _subtitle(
    Canvas canvas,
    KineticPaintLine row,
    Size size,
    double y, {
    double opacity = 1,
  }) {
    final subtitle = row.subtitle;
    if (subtitle == null || opacity <= 0) return;
    final offset = Offset((size.width - subtitle.width) / 2, y);
    if (opacity < 1) {
      canvas.saveLayer(
        offset & subtitle.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    subtitle.paint(canvas, offset);
    if (opacity < 1) canvas.restore();
  }

  // Vector note avoids dependence on platform musical-symbol fonts.
  void _note(Canvas canvas, KineticNotePose pose, Rect viewport) {
    final scale = (rows.first.fallback.preferredLineHeight / 38).clamp(
      .75,
      1.9,
    );
    final glowRadius = 34 * (1 + (pose.glow - 1) * .5) * scale;
    // A note near the gutter can be closer to the clip than its halo radius.
    // Fit only the light falloff to the available space; keep the note and text
    // in place. Paint the halo before rotating the symbol so it cannot cross
    // the viewport again when the note leans during a hop.
    final radiusX = math.min(
      glowRadius,
      math.min(pose.point.dx - viewport.left, viewport.right - pose.point.dx) -
          1,
    );
    final radiusY = math.min(
      glowRadius,
      math.min(pose.point.dy - viewport.top, viewport.bottom - pose.point.dy) -
          1,
    );
    canvas.save();
    canvas.translate(pose.point.dx, pose.point.dy);
    if (radiusX > 0 && radiusY > 0) {
      canvas.save();
      canvas.scale(radiusX / glowRadius, radiusY / glowRadius);
      canvas.drawCircle(
        Offset.zero,
        glowRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  color.withValues(alpha: .34 * pose.opacity * pose.glow),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset.zero, radius: glowRadius),
              ),
      );
      canvas.restore();
    }
    canvas.rotate(pose.rotation);
    canvas.scale(scale);
    final paint = Paint()..color = color.withValues(alpha: pose.opacity);
    canvas.save();
    canvas.rotate(-.4);
    canvas.drawOval(const Rect.fromLTWH(-8, -4, 13, 9), paint);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(4, 0)
        ..lineTo(4, -27)
        ..cubicTo(8, -22, 18, -22, 11, -12),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KineticLyricPainter oldDelegate) => true;
}
