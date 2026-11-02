import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';

/// Shared actions use SDK buttons with the selected design's feedback and shape.
class AppButton extends StatelessWidget {
  const AppButton.text({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : _kind = _AppButtonKind.text,
       _icon = null,
       iconAlignment = IconAlignment.start;

  const AppButton.filled({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : _kind = _AppButtonKind.filled,
       _icon = null,
       iconAlignment = IconAlignment.start;

  const AppButton.outlined({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : _kind = _AppButtonKind.outlined,
       _icon = null,
       iconAlignment = IconAlignment.start;

  const AppButton.tonal({
    required this.onPressed,
    required this.child,
    this.style,
    super.key,
  }) : _kind = _AppButtonKind.tonal,
       _icon = null,
       iconAlignment = IconAlignment.start;

  const AppButton.textIcon({
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.iconAlignment = IconAlignment.start,
    super.key,
  }) : _kind = _AppButtonKind.text,
       _icon = icon,
       child = label;

  const AppButton.filledIcon({
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.iconAlignment = IconAlignment.start,
    super.key,
  }) : _kind = _AppButtonKind.filled,
       _icon = icon,
       child = label;

  const AppButton.outlinedIcon({
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.iconAlignment = IconAlignment.start,
    super.key,
  }) : _kind = _AppButtonKind.outlined,
       _icon = icon,
       child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final IconAlignment iconAlignment;
  final _AppButtonKind _kind;
  final Widget? _icon;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      if (_icon != null) {
        return switch (_kind) {
          _AppButtonKind.text => TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: _icon,
            iconAlignment: iconAlignment,
            label: child,
          ),
          _AppButtonKind.filled => FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: _icon,
            iconAlignment: iconAlignment,
            label: child,
          ),
          _AppButtonKind.outlined => OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: _icon,
            iconAlignment: iconAlignment,
            label: child,
          ),
          _AppButtonKind.tonal => FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: _icon,
            iconAlignment: iconAlignment,
            label: child,
          ),
        };
      }
      return switch (_kind) {
        _AppButtonKind.text => TextButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        _AppButtonKind.filled => FilledButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        _AppButtonKind.outlined => OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        _AppButtonKind.tonal => FilledButton.tonal(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
      };
    }
    final states = <WidgetState>{if (onPressed == null) WidgetState.disabled};
    final padding =
        style?.padding?.resolve(states) ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final minimumSize =
        style?.minimumSize?.resolve(states) ?? const Size(44, 44);
    final foreground = style?.foregroundColor?.resolve(states);
    final radius = BorderRadius.circular(10);
    final content = _icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconAlignment == IconAlignment.start) ...[
                _icon,
                const SizedBox(width: 8),
              ],
              Flexible(child: child),
              if (iconAlignment == IconAlignment.end) ...[
                const SizedBox(width: 8),
                _icon,
              ],
            ],
          );
    return switch (_kind) {
      _AppButtonKind.text || _AppButtonKind.outlined => CupertinoButton(
        onPressed: onPressed,
        padding: padding,
        minimumSize: minimumSize,
        foregroundColor: foreground,
        borderRadius: radius,
        child: content,
      ),
      _AppButtonKind.filled => CupertinoButton.filled(
        onPressed: onPressed,
        padding: padding,
        minimumSize: minimumSize,
        foregroundColor: foreground,
        borderRadius: radius,
        child: content,
      ),
      _AppButtonKind.tonal => CupertinoButton.tinted(
        onPressed: onPressed,
        padding: padding,
        minimumSize: minimumSize,
        foregroundColor: foreground,
        borderRadius: radius,
        child: content,
      ),
    };
  }
}

enum _AppButtonKind { text, filled, tonal, outlined }
