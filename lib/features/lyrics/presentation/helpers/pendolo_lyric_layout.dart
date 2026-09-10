import 'dart:math' as math;

import 'package:flutter/painting.dart';

// Geometry for Folia's Pendolo escapement wheel, adapted to narrow viewports.
class PendoloWheelGeometry {
  PendoloWheelGeometry(Size size)
    : center = Offset(-size.width * 0.38, size.height / 2),
      radius = size.width * 0.38 + 28,
      textWidth = math.max(1, size.width - 56);

  final Offset center;
  final double radius;
  final double textWidth;

  Offset point(double angle) =>
      center + Offset(math.cos(angle), math.sin(angle)) * radius;

  /// Wrapped line heights increase angular spacing to keep adjacent rows apart.
  double step(double firstHeight, double secondHeight) =>
      math.max(0.19, (firstHeight + secondHeight + 28) / (2 * radius));
}

/// Damped escapement overshoot with an exact settled endpoint.
double pendoloEscapement(double progress) {
  if (progress >= 1) return 1;
  if (progress <= 0) return 0;
  return 1 - math.exp(-8 * progress) * math.cos(11 * progress);
}
