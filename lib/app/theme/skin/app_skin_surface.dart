import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_skin_theme.dart';

import '../app_ui_theme.dart';

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
    this.showDecoration = true,
    super.key,
  });

  final AppSkinSurfaceRole role;
  final Widget child;
  final BorderRadius? borderRadius;

  /// Disables decorative frames while retaining the surface tint.
  final bool showDecoration;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    if (skinTheme == null) {
      return child;
    }
    final config = skinTheme.config;
    final geometry = config.geometry;
    final configuredRadius = switch (role) {
      AppSkinSurfaceRole.search ||
      AppSkinSurfaceRole.miniPlayer ||
      AppSkinSurfaceRole.navigation => geometry.controlRadius,
      AppSkinSurfaceRole.scrollingContent => geometry.cardRadius,
      AppSkinSurfaceRole.bottomSheet => geometry.bottomSheetRadius,
    };
    final usesCupertino = AppUiTheme.usesCupertino(context);
    final cupertinoRadius = switch (role) {
      AppSkinSurfaceRole.search || AppSkinSurfaceRole.scrollingContent => 10.0,
      AppSkinSurfaceRole.miniPlayer || AppSkinSurfaceRole.bottomSheet => 16.0,
      AppSkinSurfaceRole.navigation => 0.0,
    };
    final radius =
        borderRadius ??
        BorderRadius.circular(
          usesCupertino ? cupertinoRadius : configuredRadius,
        );
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
        skinTheme.showContentBackground
            ? config.surfaces.scrollingContentOpacity
            : 0,
      AppSkinSurfaceRole.bottomSheet => config.surfaces.bottomSheetOpacity,
    };
    final isPlaybackSurface =
        role == AppSkinSurfaceRole.miniPlayer ||
        role == AppSkinSurfaceRole.navigation;
    final blurSigma =
        isPlaybackSurface && skinTheme.usesTranslucentPlaybackSurfaces
        ? geometry.blurSigma
        : 0.0;
    final hasWallpaper = config.background.wallpaper.descriptor != null;
    final layeredContent =
        role == AppSkinSurfaceRole.scrollingContent &&
        hasWallpaper &&
        opacity > 0;
    final isDark = config.colorScheme.brightness == Brightness.dark;
    final contentColor = switch (role) {
      AppSkinSurfaceRole.miniPlayer => skinTheme.miniPlayerBackgroundColor,
      AppSkinSurfaceRole.navigation => skinTheme.navigationBackgroundColor,
      AppSkinSurfaceRole.scrollingContent => skinTheme.contentBackgroundColor,
      _ => baseColor.withValues(alpha: 1),
    };
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: contentColor,
        borderRadius: radius,
        // BoxDecoration modulates its shader by color.a; keep stops opaque so
        // the skin's configured content opacity is applied exactly once.
        gradient: layeredContent
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(
                    contentColor,
                    Colors.white,
                    isDark ? 0.08 : 0.16,
                  )!.withValues(alpha: 1),
                  contentColor.withValues(alpha: 1),
                  Color.lerp(
                    contentColor,
                    Colors.black,
                    isDark ? 0.04 : 0.02,
                  )!.withValues(alpha: 1),
                ],
                stops: const <double>[0, 0.45, 1],
              )
            : null,
        border:
            !showDecoration ||
                usesCupertino ||
                opacity == 0 ||
                geometry.borderWidth == 0
            ? null
            : Border.all(
                color: layeredContent
                    ? Color.lerp(
                        config.colors.border,
                        Colors.white,
                        isDark ? 0.65 : 0.75,
                      )!.withValues(alpha: isDark ? 0.24 : 0.55)
                    : config.colors.border,
                width: geometry.borderWidth,
              ),
        boxShadow:
            !showDecoration ||
                usesCupertino ||
                geometry.shadowOpacity == 0 ||
                opacity == 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: config.colors.shadow.withValues(
                    alpha: layeredContent
                        ? geometry.shadowOpacity * 0.45
                        : geometry.shadowOpacity,
                  ),
                  blurRadius: geometry.shadowBlurRadius,
                  offset: geometry.shadowOffset,
                ),
              ],
      ),
      child: child,
    );
    if (!isPlaybackSurface) {
      return ClipRRect(borderRadius: radius, child: content);
    }
    // Keep the child mounted when switching between solid and wallpaper skins.
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        enabled: contentColor.a < 1 && blurSigma > 0,
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}

/// 为共享滚动内容应用当前皮肤定义的可选内容表面。
class AppSkinContentSurface extends StatelessWidget {
  const AppSkinContentSurface({required this.child, this.padding, super.key});

  /// Apply the skin preference to custom page content without changing controls.
  static Color backgroundColorOf(
    BuildContext context, {
    required Color materialColor,
  }) {
    if (AppUiTheme.usesCupertino(context)) {
      return Theme.of(
            context,
          ).extension<AppSkinTheme>()?.contentBackgroundColor ??
          materialColor;
    }
    return materialColor;
  }

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    if (skinTheme == null ||
        (!AppUiTheme.usesCupertino(context) &&
            !skinTheme.showContentBackground &&
            skinTheme.config.colors.scaffoldBackground.a != 0)) {
      return child;
    }
    return AppSkinSurface(
      role: AppSkinSurfaceRole.scrollingContent,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}
