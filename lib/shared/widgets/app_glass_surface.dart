import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_material.dart';
import '../../app/theme/glass/app_glass_scope.dart';
import '../../app/theme/skin/app_skin_models.dart';
import '../../app/theme/skin/app_skin_surface.dart';
import '../../app/theme/skin/app_skin_theme.dart';

/// Glass control surface using the official Apple Music pill material.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    required this.role,
    required this.child,
    this.borderRadius,
    this.enabled = true,
    super.key,
  });

  final AppSkinSurfaceRole role;
  final Widget child;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    final unsupportedRadius =
        borderRadius != null &&
        (borderRadius!.topLeft != borderRadius!.topRight ||
            borderRadius!.bottomLeft != borderRadius!.bottomRight ||
            borderRadius!.topLeft.x != borderRadius!.topLeft.y ||
            borderRadius!.bottomLeft.x != borderRadius!.bottomLeft.y);
    if (!enabled ||
        !AppGlassScope.isEnabled(context) ||
        (AppGlassScope.preferOpaqueSurfaces(context) &&
            role != AppSkinSurfaceRole.navigation &&
            role != AppSkinSurfaceRole.miniPlayer) ||
        skinTheme == null ||
        role == AppSkinSurfaceRole.scrollingContent ||
        unsupportedRadius) {
      return AppSkinSurface(
        role: role,
        borderRadius: borderRadius,
        child: child,
      );
    }
    final config = skinTheme.config;
    final radius = borderRadius ?? BorderRadius.circular(_radius(config));
    final baseColor = role == AppSkinSurfaceRole.bottomSheet
        ? config.colors.bottomSheetBackground
        : config.colors.fixedControlSurface;
    if (MediaQuery.highContrastOf(context)) {
      return ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: baseColor.withValues(alpha: 1), child: child),
      );
    }
    return GlassContainer(
      quality: AppGlassScope.qualityOf(context),
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      shape: LiquidVerticalRoundedRectangle(
        topRadius: radius.topLeft.x,
        bottomRadius: radius.bottomLeft.x,
      ),
      settings:
          AppGlassMaterial.settings(
            context,
            navigation: role == AppSkinSurfaceRole.navigation,
          ).copyWith(
            glassColor: baseColor.withAlpha(
              role == AppSkinSurfaceRole.navigation ? 0xAA : 0xCC,
            ),
          ),
      child: child,
    );
  }

  double _radius(AppSkinBrightnessConfig config) => switch (role) {
    // The official play pill uses height / 2. The existing mini-player is 52 high.
    AppSkinSurfaceRole.miniPlayer => 26,
    AppSkinSurfaceRole.search ||
    AppSkinSurfaceRole.navigation => config.geometry.controlRadius,
    AppSkinSurfaceRole.scrollingContent => config.geometry.cardRadius,
    AppSkinSurfaceRole.bottomSheet => config.geometry.bottomSheetRadius,
  };
}
