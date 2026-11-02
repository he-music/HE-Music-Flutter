import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_ui_theme.dart';
import '../../app/theme/skin/app_skin_theme.dart';

/// Settings and action rows share data while retaining each design's layout.
class AppListTile extends StatefulWidget {
  const AppListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.additionalInfo,
    this.onTap,
    this.enabled = true,
    this.showChevron = false,
    this.contentPadding,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? additionalInfo;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<AppListTile> createState() => _AppListTileState();
}

class _AppListTileState extends State<AppListTile> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled ? widget.onTap : null;
    final theme = Theme.of(context);
    if (!AppUiTheme.usesCupertino(context)) {
      return ListTile(
        enabled: widget.enabled,
        title: widget.title,
        subtitle: widget.subtitle,
        leading: widget.leading,
        contentPadding: widget.contentPadding,
        onTap: onTap,
        trailing:
            widget.trailing ??
            (widget.additionalInfo == null && !widget.showChevron
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.additionalInfo != null) widget.additionalInfo!,
                      if (widget.showChevron) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ],
                  )),
      );
    }

    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final foreground = widget.enabled
        ? theme.colorScheme.onSurface
        : theme.disabledColor;
    final secondary = widget.enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.disabledColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Native additionalInfo is unconstrained. Move values below the title
        // when a small window or accessibility text would crowd the row.
        final stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(17) > 20;
        final tile = CupertinoListTile(
          padding:
              widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: widget.leading == null
              ? null
              : IconTheme(
                  data: IconThemeData(
                    size: 22,
                    color: widget.enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  child: widget.leading!,
                ),
          title: DefaultTextStyle(
            style: textStyle.copyWith(color: foreground),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.title,
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: textStyle.copyWith(fontSize: 13, color: secondary),
                    child: widget.subtitle!,
                  ),
                ],
                if (stacked && widget.additionalInfo != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: textStyle.copyWith(fontSize: 15, color: secondary),
                    child: widget.additionalInfo!,
                  ),
                ],
              ],
            ),
          ),
          additionalInfo: stacked || widget.additionalInfo == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.4,
                    ),
                    child: DefaultTextStyle(
                      style: textStyle.copyWith(fontSize: 15, color: secondary),
                      child: widget.additionalInfo!,
                    ),
                  ),
                ),
          trailing:
              widget.trailing ??
              (widget.showChevron ? const CupertinoListTileChevron() : null),
          backgroundColorActivated: theme.colorScheme.onSurface.withValues(
            alpha: 0.08,
          ),
          onTap: onTap,
        );
        return Semantics(
          button: onTap != null,
          enabled: widget.enabled,
          child: FocusableActionDetector(
            enabled: onTap != null,
            onShowFocusHighlight: (value) => setState(() => _showFocus = value),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  onTap?.call();
                  return null;
                },
              ),
            },
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: _showFocus && onTap != null
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: tile,
            ),
          ),
        );
      },
    );
  }
}

class AppListSection extends StatelessWidget {
  const AppListSection({
    required this.children,
    this.header,
    this.hasLeading = true,
    super.key,
  });

  final List<Widget> children;
  final Widget? header;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (AppUiTheme.usesCupertino(context)) {
      final skin = theme.extension<AppSkinTheme>();
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        hasLeading: hasLeading,
        header: header,
        decoration: BoxDecoration(
          color:
              skin?.contentBackgroundColor ??
              CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
                context,
              ),
          borderRadius: BorderRadius.circular(10),
        ),
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          DefaultTextStyle(
            style: theme.textTheme.titleSmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: header!,
          ),
          const SizedBox(height: 8),
        ],
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
