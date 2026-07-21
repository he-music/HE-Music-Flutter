import 'package:flutter/material.dart';

import '../../../../shared/constants/layout_tokens.dart';

@immutable
class PlayerLayoutSpec {
  const PlayerLayoutSpec({
    required this.isDesktop,
    required this.pageGutter,
    required this.verticalGap,
    required this.artistSlotWidth,
    required this.primaryPaneFlex,
    required this.lyricsPaneFlex,
  });

  final bool isDesktop;
  final double pageGutter;
  final double verticalGap;
  final double artistSlotWidth;
  final int primaryPaneFlex;
  final int lyricsPaneFlex;

  factory PlayerLayoutSpec.resolve(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isDesktop = width >= LayoutTokens.desktopBreakpoint;
    final isShort = height < 640;
    return PlayerLayoutSpec(
      isDesktop: isDesktop,
      pageGutter: isDesktop ? 24 : 12,
      verticalGap: isShort ? 4 : 8,
      artistSlotWidth: isDesktop
          ? 220
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
