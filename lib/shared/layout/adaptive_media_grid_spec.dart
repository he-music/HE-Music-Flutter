import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class AdaptiveMediaGridSpec {
  const AdaptiveMediaGridSpec({
    required this.crossAxisCount,
    required this.itemWidth,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double itemWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  SliverGridDelegate get sliverDelegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      );
}

AdaptiveMediaGridSpec resolveAdaptiveMediaGridSpec({
  required double maxWidth,
  double minItemWidth = 160,
  double crossAxisSpacing = 8,
  double mainAxisSpacing = 8,
  double childAspectRatio = 0.84,
  int minCrossAxisCount = 2,
}) {
  final safeWidth = math.max(maxWidth, 0).toDouble();
  final estimatedCount =
      ((safeWidth + crossAxisSpacing) / (minItemWidth + crossAxisSpacing))
          .floor();
  final crossAxisCount = math.max(minCrossAxisCount, estimatedCount);
  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
  final itemWidth = crossAxisCount <= 0
      ? safeWidth
      : (safeWidth - totalSpacing) / crossAxisCount;

  return AdaptiveMediaGridSpec(
    crossAxisCount: crossAxisCount,
    itemWidth: itemWidth,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
    childAspectRatio: childAspectRatio,
  );
}
