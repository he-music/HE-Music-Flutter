import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';
import '../constants/layout_tokens.dart';

import 'app_list_tile.dart';

/// Shared controls follow the explicit design choice on every platform.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.style,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
        style: style,
      );
    }
    Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(LayoutTokens.controlMinExtent),
      onPressed: onPressed,
      child: IconTheme(
        data: IconThemeData(
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        child: icon,
      ),
    );
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: Semantics(label: tooltip, child: button),
      );
    }
    return button;
  }
}

class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavigationBar({
    required this.title,
    this.leading,
    this.actions = const [],
    super.key,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return AppBar(title: title, leading: leading, actions: actions);
    }
    final theme = Theme.of(context);
    final transparentPage =
        (Scaffold.maybeOf(context)?.widget.backgroundColor ??
                theme.scaffoldBackgroundColor)
            .a ==
        0;
    return CupertinoNavigationBar(
      middle: title,
      leading: leading,
      trailing: actions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: actions.map(_cupertinoAction).toList(growable: false),
            ),
      backgroundColor: transparentPage
          ? Colors.transparent
          : CupertinoTheme.of(context).barBackgroundColor.withValues(alpha: 1),
      brightness: theme.brightness,
      border: transparentPage
          ? null
          : Border(
              bottom: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0,
              ),
            ),
      enableBackgroundFilterBlur: false,
      transitionBetweenRoutes: false,
    );
  }

  Widget _cupertinoAction(Widget action) {
    if (action is IconButton) {
      return AppIconButton(
        key: action.key,
        icon: action.icon,
        onPressed: action.onPressed,
        tooltip: action.tooltip,
        color: action.color,
      );
    }
    if (action is ButtonStyleButton) {
      return CupertinoButton(
        key: action.key,
        onPressed: action.onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: action.child ?? const SizedBox.shrink(),
      );
    }
    return action;
  }
}

class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
      );
    }
    return MergeSemantics(
      child: AppListTile(
        enabled: onChanged != null,
        leading: secondary,
        title: title ?? const SizedBox.shrink(),
        subtitle: subtitle,
        contentPadding: contentPadding,
        trailing: CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
