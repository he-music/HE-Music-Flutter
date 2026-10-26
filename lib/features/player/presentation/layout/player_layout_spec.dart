import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

import '../../../../shared/constants/layout_tokens.dart';

enum PlayerLayoutMode { mobilePortrait, mobileLandscape }

EdgeInsets resolvePlayerLandscapeSafeInsets({
  required Size size,
  required EdgeInsets systemGestureInsets,
  required List<DisplayFeature> displayFeatures,
}) {
  var left = systemGestureInsets.left;
  var top = systemGestureInsets.top;
  var right = systemGestureInsets.right;
  var bottom = systemGestureInsets.bottom;

  for (final feature in displayFeatures) {
    if (feature.type != DisplayFeatureType.cutout) continue;
    final bounds = feature.bounds;
    if (bounds.left <= 0) left = math.max(left, bounds.right);
    if (bounds.top <= 0) top = math.max(top, bounds.bottom);
    if (bounds.right >= size.width) {
      right = math.max(right, size.width - bounds.left);
    }
    if (bounds.bottom >= size.height) {
      bottom = math.max(bottom, size.height - bounds.top);
    }
  }

  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

EdgeInsets resolvePlayerLandscapeContentInsets(EdgeInsets safeInsets) {
  // 返回轨道、轨道间距和页面 gutter 已为主体预留 60px，可先吸收左侧挖孔深度。
  const leadingReservedWidth = 60.0;
  return safeInsets.copyWith(
    left: math.max(0.0, safeInsets.left - leadingReservedWidth),
  );
}

@immutable
class PlayerLayoutSpec {
  const PlayerLayoutSpec({
    required this.mode,
    required this.pageGutter,
    required this.verticalGap,
    required this.artistSlotWidth,
  });

  final PlayerLayoutMode mode;
  final double pageGutter;
  final double verticalGap;
  final double artistSlotWidth;

  bool get isMobileLandscape => mode == PlayerLayoutMode.mobileLandscape;

  factory PlayerLayoutSpec.resolve(
    BoxConstraints constraints, {
    bool allowMobileLandscape = true,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isShort = height < 640;
    final mode = allowMobileLandscape && width > height && isShort
        ? PlayerLayoutMode.mobileLandscape
        : PlayerLayoutMode.mobilePortrait;
    return PlayerLayoutSpec(
      mode: mode,
      pageGutter: width >= LayoutTokens.desktopBreakpoint && !isShort
          ? 24
          : mode == PlayerLayoutMode.mobileLandscape
          ? 4
          : width <= 340
          ? 12
          : 20,
      verticalGap: isShort ? 4 : 12,
      artistSlotWidth: width >= LayoutTokens.desktopBreakpoint && !isShort
          ? 220
          : mode == PlayerLayoutMode.mobileLandscape
          ? width <= 700
                ? 128
                : 168
          : width <= 340
          ? 112
          : width <= 390
          ? 144
          : 176,
    );
  }
}
