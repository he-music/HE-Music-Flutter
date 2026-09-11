import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/entities/lyric_line.dart';
import 'monet_lyric_layout.dart';

// Measured glyphs orbit a slender tilted ellipse; geometry has no frame resources.
class CladdaghOrbitGeometry {
  CladdaghOrbitGeometry(this.size)
    : radius = math.max(1, math.min(size.width * 0.55, size.height * 0.70)),
      center = Offset(size.width / 2, size.height * 0.43);
  final Size size;
  final double radius;
  final Offset center;
  static const tilt = -math.pi / 4;

  Offset point(double angle) {
    final depth = (math.cos(angle) + 1) / 2;
    final x = math.sin(angle) * radius * (0.35 + 0.65 * math.pow(depth, 1.2));
    final y = math.cos(angle) * radius * 0.09;
    return center +
        Offset(
          x * math.cos(tilt) - y * math.sin(tilt),
          x * math.sin(tilt) + y * math.cos(tilt),
        );
  }

  double tangent(double angle) {
    var result = math.atan2(-math.sin(angle) * 0.09, math.cos(angle)) + tilt;
    while (result > math.pi / 2) {
      result -= math.pi;
    }
    while (result < -math.pi / 2) {
      result += math.pi;
    }
    return result;
  }
}

double claddaghTransition(double progress) => progress >= 1
    ? 1
    : progress <= 0
    ? 0
    : 1 - math.exp(-7 * progress) * math.cos(5 * progress);

/// Preserve source token boundaries, distributing each timed word over graphemes.
List<MonetDisplayToken> buildCladdaghGlyphs(LyricLine line) {
  final result = <MonetDisplayToken>[];
  for (final token in buildMonetDisplayTokens(line)) {
    final chars = token.text.characters.toList();
    var offset = token.startOffset;
    for (var i = 0; i < chars.length; i++) {
      final start = token.start;
      final end = token.end;
      final duration = start != null && end != null
          ? (end - start).inMicroseconds
          : null;
      result.add(
        MonetDisplayToken(
          text: chars[i],
          startOffset: offset,
          endOffset: offset + chars[i].length,
          start: duration == null
              ? null
              : start! +
                    Duration(
                      microseconds: (duration * i / chars.length).round(),
                    ),
          end: duration == null
              ? null
              : start! +
                    Duration(
                      microseconds: (duration * (i + 1) / chars.length).round(),
                    ),
          key: '${token.key}:$i',
        ),
      );
      offset += chars[i].length;
    }
  }
  return result;
}
