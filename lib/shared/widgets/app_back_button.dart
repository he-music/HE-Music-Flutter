import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
import 'song_actions_sheet.dart';

extension AppBackNavigation on BuildContext {
  void appPopOrGo([String fallbackLocation = AppRoutes.home]) {
    if (SongActionsSheetController.dismissOpenSheet()) {
      return;
    }
    if (canPop()) {
      pop();
      return;
    }
    go(fallbackLocation);
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    this.onPressed,
    this.fallbackLocation = AppRoutes.home,
    this.icon,
    this.iconRole = AppSkinIconRole.back,
    this.iconColor,
    this.backgroundColor,
    this.iconSize,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.constraints,
    this.padding,
    super.key,
  });

  final VoidCallback? onPressed;
  final String fallbackLocation;
  final IconData? icon;
  final AppSkinIconRole iconRole;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? iconSize;
  final String? tooltip;
  final ButtonStyle? style;
  final VisualDensity? visualDensity;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = iconColor;
    final buttonStyle =
        style?.merge(_styleForColors(foregroundColor)) ??
        _styleForColors(foregroundColor);

    return IconButton(
      onPressed: onPressed ?? () => context.appPopOrGo(fallbackLocation),
      tooltip: tooltip ?? _resolveBackTooltip(context),
      icon: icon == null
          ? AppSkinIcon(role: iconRole, size: iconSize, color: foregroundColor)
          : Icon(icon, size: iconSize),
      style: buttonStyle,
      visualDensity: visualDensity,
      constraints: constraints,
      padding: padding,
    );
  }

  String _resolveBackTooltip(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return AppI18n.t(container.read(appConfigProvider), 'common.back');
    } on StateError {
      final localeCode = Localizations.localeOf(context).languageCode;
      return AppI18n.tByLocaleCode(localeCode, 'common.back');
    }
  }

  ButtonStyle? _styleForColors(Color? foregroundColor) {
    if (foregroundColor == null && backgroundColor == null) {
      return null;
    }
    return IconButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }
}
