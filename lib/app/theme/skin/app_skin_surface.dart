import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_skin_theme.dart';

enum AppSkinSurfaceRole {
  search,
  miniPlayer,
  navigation,
  scrollingContent,
  bottomSheet,
}

class AppSkinSurface extends StatelessWidget {
  const AppSkinSurface({
    required this.role,
    required this.child,
    this.borderRadius,
    super.key,
  });

  final AppSkinSurfaceRole role;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    if (skinTheme == null) {
      return child;
    }
    final config = skinTheme.config;
    final geometry = config.geometry;
    final radius =
        borderRadius ?? BorderRadius.circular(geometry.controlRadius);
    final baseColor = switch (role) {
      AppSkinSurfaceRole.search ||
      AppSkinSurfaceRole.miniPlayer ||
      AppSkinSurfaceRole.navigation => config.colors.fixedControlSurface,
      AppSkinSurfaceRole.scrollingContent =>
        config.colors.scrollingContentSurface,
      AppSkinSurfaceRole.bottomSheet => config.colors.bottomSheetBackground,
    };
    final opacity = switch (role) {
      AppSkinSurfaceRole.search => config.surfaces.searchOpacity,
      AppSkinSurfaceRole.miniPlayer => config.surfaces.miniPlayerOpacity,
      AppSkinSurfaceRole.navigation => config.surfaces.navigationOpacity,
      AppSkinSurfaceRole.scrollingContent =>
        config.surfaces.scrollingContentOpacity,
      AppSkinSurfaceRole.bottomSheet => config.surfaces.bottomSheetOpacity,
    };
    final blurSigma = switch (role) {
      AppSkinSurfaceRole.search ||
      AppSkinSurfaceRole.miniPlayer ||
      AppSkinSurfaceRole.navigation => geometry.blurSigma,
      AppSkinSurfaceRole.scrollingContent ||
      AppSkinSurfaceRole.bottomSheet => 0.0,
    };
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: baseColor.a * opacity),
        borderRadius: radius,
        border: geometry.borderWidth == 0
            ? null
            : Border.all(
                color: config.colors.border,
                width: geometry.borderWidth,
              ),
        boxShadow: geometry.shadowOpacity == 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: config.colors.shadow.withValues(
                    alpha: geometry.shadowOpacity,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
    if (blurSigma == 0) {
      return ClipRRect(borderRadius: radius, child: content);
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}

/// 仅在透明页面露出全局壁纸时，为滚动内容提供稳定的可读性表面。
class AppSkinContentSurface extends StatelessWidget {
  const AppSkinContentSurface({
    required this.child,
    this.borderRadius,
    this.padding,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    if (skinTheme == null ||
        skinTheme.config.colors.scaffoldBackground.a != 0) {
      return child;
    }
    return AppSkinSurface(
      role: AppSkinSurfaceRole.scrollingContent,
      borderRadius: borderRadius,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}
