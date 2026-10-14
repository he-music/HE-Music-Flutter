import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_material.dart';
import '../../app/theme/glass/app_glass_scope.dart';

/// 音乐分类和播放操作栏的统一磨砂材质。
/// 固定栏默认使用较强底色；可折叠页面根据进度逐渐增强遮挡。
class MusicControlSurface extends StatelessWidget {
  const MusicControlSurface({
    required this.child,
    this.collapseProgress = 1,
    this.borderRadius = 0,
    this.scrollController,
    this.collapseExtent,
    this.joinsCover = false,
    this.glassBuilder,
    super.key,
  }) : assert(
         scrollController == null ||
             (collapseExtent != null && collapseExtent > 0),
       );

  final Widget child;
  final double collapseProgress;
  final double borderRadius;
  final ScrollController? scrollController;
  final double? collapseExtent;
  final bool joinsCover;
  final Widget Function(LiquidGlassSettings settings, GlassQuality quality)?
  glassBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = AppGlassMaterial.controlSurfaceColor(context);
    if (theme.scaffoldBackgroundColor.a == 1 ||
        !AppGlassScope.controlsEnabled(context) ||
        MediaQuery.highContrastOf(context)) {
      return Material(
        color: surface.withValues(alpha: 1),
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.hardEdge,
        child: child,
      );
    }
    final quality = AppGlassScope.qualityOf(context);
    final content = Material(type: MaterialType.transparency, child: child);
    final controller = scrollController;
    if (controller == null) {
      return _buildGlass(surface, quality, collapseProgress, content);
    }
    // 保留控件为 child，滚动只更新这一层材质。
    return AnimatedBuilder(
      animation: controller,
      child: content,
      builder: (context, child) => _buildGlass(
        surface,
        quality,
        (controller.hasClients ? controller.offset : 0) / collapseExtent!,
        child!,
      ),
    );
  }

  Widget _buildGlass(
    Color surface,
    GlassQuality quality,
    double progress,
    Widget content,
  ) {
    final collapse = progress.clamp(0.0, 1.0);
    final settings = AppGlassMaterial.musicControls(
      surface: surface,
      collapseProgress: collapse,
    );
    final glass =
        glassBuilder?.call(settings, quality) ??
        GlassContainer(
          quality: quality,
          useOwnLayer: true,
          shape: LiquidRoundedRectangle(borderRadius: borderRadius),
          clipBehavior: Clip.hardEdge,
          settings: settings,
          child: content,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // 展开时接住封面底部的渐变，折叠后固定栏使用同一底色。
        gradient: joinsCover
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  surface.withValues(alpha: 0.22 * (1 - collapse)),
                  surface.withValues(alpha: 0),
                ],
              )
            : null,
      ),
      child: glass,
    );
  }
}
