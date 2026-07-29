import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

import '../../../../shared/constants/layout_tokens.dart';

enum PlayerLayoutMode { mobilePortrait, mobileLandscape, desktop }

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
    required this.primaryPaneFlex,
    required this.lyricsPaneFlex,
  });

  final PlayerLayoutMode mode;
  final double pageGutter;
  final double verticalGap;
  final double artistSlotWidth;
  final int primaryPaneFlex;
  final int lyricsPaneFlex;

  bool get isDesktop => mode == PlayerLayoutMode.desktop;

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
        : width >= LayoutTokens.desktopBreakpoint
        ? PlayerLayoutMode.desktop
        : PlayerLayoutMode.mobilePortrait;
    return PlayerLayoutSpec(
      mode: mode,
      pageGutter: mode == PlayerLayoutMode.desktop
          ? 24
          : mode == PlayerLayoutMode.mobileLandscape
          ? 4
          : 12,
      verticalGap: isShort ? 4 : 8,
      artistSlotWidth: mode == PlayerLayoutMode.desktop
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
      primaryPaneFlex: 11,
      lyricsPaneFlex: 10,
    );
  }
}
