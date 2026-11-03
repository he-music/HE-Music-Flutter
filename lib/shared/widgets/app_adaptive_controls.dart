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
    this.iconSize,
    this.isSelected,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final ButtonStyle? style;
  final double? iconSize;
  final bool? isSelected;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(LayoutTokens.controlMinExtent),
        ).merge(style),
        iconSize: iconSize,
        isSelected: isSelected,
      );
    }
    final states = <WidgetState>{
      if (onPressed == null) WidgetState.disabled,
      if (isSelected ?? false) WidgetState.selected,
    };
    final minimumSize =
        style?.minimumSize?.resolve(states) ?? const Size(44, 44);
    final foreground =
        color ??
        style?.foregroundColor?.resolve(states) ??
        (onPressed == null
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.primary);
    Widget button = Semantics(
      button: true,
      enabled: onPressed != null,
      selected: isSelected,
      label: tooltip,
      child: CupertinoButton(
        padding: style?.padding?.resolve(states) ?? EdgeInsets.zero,
        minimumSize: Size(
          minimumSize.width < 44 ? 44 : minimumSize.width,
          minimumSize.height < 44 ? 44 : minimumSize.height,
        ),
        color: style?.backgroundColor?.resolve(states),
        disabledColor:
            style?.backgroundColor?.resolve(states) ??
            CupertinoColors.quaternarySystemFill,
        borderRadius: style?.shape?.resolve(states) is CircleBorder
            ? BorderRadius.circular(999)
            : BorderRadius.circular(8),
        onPressed: onPressed,
        child: IconTheme(
          data: IconThemeData(color: foreground, size: iconSize),
          child: icon,
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Keeps content and keyboard focus mounted while press feedback changes style.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    required this.onTap,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cupertino = AppUiTheme.usesCupertino(context);
    return InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      splashFactory: cupertino ? NoSplash.splashFactory : null,
      highlightColor: cupertino ? Colors.transparent : null,
      enableFeedback: !cupertino,
      onHighlightChanged: (pressed) {
        if (_pressed != pressed) {
          setState(() => _pressed = pressed);
        }
      },
      child: Opacity(
        opacity: cupertino && _pressed ? 0.6 : 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: widget.child,
        ),
      ),
    );
  }
}

class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavigationBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.previousPageTitle,
    super.key,
  });

  final Widget title;
  final Widget? leading;
  final String? previousPageTitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => AppBar().preferredSize;

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
      padding: const EdgeInsetsDirectional.only(start: 0, end: 8),
      middle: title,
      previousPageTitle: previousPageTitle,
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
      return Semantics(
        button: true,
        enabled: action.onPressed != null,
        child: CupertinoButton(
          key: action.key,
          onPressed: action.onPressed,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: action.child ?? const SizedBox.shrink(),
        ),
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
