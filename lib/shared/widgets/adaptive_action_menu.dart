import 'package:flutter/material.dart';

import '../utils/platform_utils.dart';

enum AdaptiveActionMenuMobileDensity { regular, compact }

class AdaptiveActionMenuAnchor {
  AdaptiveActionMenuAnchor._();

  static BuildContext? _context;
  static Offset? _globalPosition;

  static void capture(BuildContext context, {Offset? globalPosition}) {
    _context = context;
    _globalPosition = globalPosition;
  }

  static _AdaptiveActionMenuAnchorSnapshot _consume() {
    final snapshot = _AdaptiveActionMenuAnchorSnapshot(
      context: _context,
      globalPosition: _globalPosition,
    );
    _context = null;
    _globalPosition = null;
    return snapshot;
  }
}

class _AdaptiveActionMenuAnchorSnapshot {
  const _AdaptiveActionMenuAnchorSnapshot({
    required this.context,
    required this.globalPosition,
  });

  final BuildContext? context;
  final Offset? globalPosition;
}

class AdaptiveActionMenuItem<T> {
  const AdaptiveActionMenuItem({
    required this.value,
    required this.label,
    this.key,
    this.icon,
    this.enabled = true,
    this.destructive = false,
    this.startsNewSection = false,
  });

  final T value;
  final String label;
  final Key? key;
  final IconData? icon;
  final bool enabled;
  final bool destructive;
  final bool startsNewSection;
}

class AdaptiveActionMenu<T> extends StatefulWidget {
  const AdaptiveActionMenu({
    required this.menuKey,
    required this.tooltip,
    required this.icon,
    required this.items,
    required this.onSelected,
    this.mobileDensity = AdaptiveActionMenuMobileDensity.compact,
    super.key,
  });

  final Key menuKey;
  final String tooltip;
  final Widget icon;
  final List<AdaptiveActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final AdaptiveActionMenuMobileDensity mobileDensity;

  @override
  State<AdaptiveActionMenu<T>> createState() => _AdaptiveActionMenuState<T>();
}

class _AdaptiveActionMenuState<T> extends State<AdaptiveActionMenu<T>> {
  Offset? _lastGlobalPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _lastGlobalPosition = details.globalPosition,
      onSecondaryTapDown: (details) {
        _lastGlobalPosition = details.globalPosition;
      },
      child: IconButton(
        key: widget.menuKey,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: widget.tooltip,
        icon: widget.icon,
        onPressed: widget.items.isEmpty ? null : _openMenu,
      ),
    );
  }

  Future<void> _openMenu() async {
    final useContextMenu = _useContextMenu(context);
    T? selected;
    if (useContextMenu) {
      selected = await _showContextMenu(context);
    } else {
      selected = await _showBottomSheet(context);
    }
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      widget.onSelected(selected);
    }
  }

  bool _useContextMenu(BuildContext context) {
    return shouldUseDesktopMenu(context);
  }

  Future<T?> _showContextMenu(BuildContext context) {
    final position = _resolveContextMenuPosition(
      context,
      anchorContext: context,
      anchorPosition: _lastGlobalPosition,
    );
    return showMenu<T>(
      context: context,
      position: position,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: widget.items
          .map(
            (item) => PopupMenuItem<T>(
              key: item.key,
              value: item.value,
              enabled: item.enabled,
              child: _ActionMenuLabel(item: item, compact: false),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<T?> _showBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surface;
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: backgroundColor,
      builder: (bottomSheetContext) => _AdaptiveActionMenuBottomSheetBody<T>(
        items: widget.items,
        onSelected: (value) => Navigator.of(bottomSheetContext).pop(value),
        density: widget.mobileDensity,
      ),
    );
  }
}

RelativeRect _resolveContextMenuPosition(
  BuildContext context, {
  BuildContext? anchorContext,
  Offset? anchorPosition,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  if (anchorPosition != null) {
    final localPosition = overlay.globalToLocal(anchorPosition);
    final anchorRect = Rect.fromCenter(
      center: localPosition,
      width: 1,
      height: 1,
    );
    return RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size);
  }

  final resolvedAnchorContext = anchorContext ?? context;
  final anchor = resolvedAnchorContext.findRenderObject()! as RenderBox;
  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = anchor.localToGlobal(
    anchor.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  return RelativeRect.fromRect(
    Rect.fromPoints(topLeft, bottomRight),
    Offset.zero & overlay.size,
  );
}

Future<T?> showAdaptiveActionMenu<T>({
  required BuildContext context,
  required List<AdaptiveActionMenuItem<T>> items,
  BuildContext? anchorContext,
  Offset? anchorPosition,
  Widget? mobileHeader,
  Widget? mobileFooter,
  AdaptiveActionMenuMobileDensity mobileDensity =
      AdaptiveActionMenuMobileDensity.compact,
}) {
  final useContextMenu = shouldUseDesktopMenu(context);
  if (useContextMenu) {
    final snapshot = AdaptiveActionMenuAnchor._consume();
    final resolvedAnchorPosition = anchorPosition ?? snapshot.globalPosition;
    final resolvedAnchorContext = anchorContext ?? snapshot.context ?? context;
    final position = _resolveContextMenuPosition(
      context,
      anchorContext: resolvedAnchorContext,
      anchorPosition: resolvedAnchorPosition,
    );
    return showMenu<T>(
      context: context,
      position: position,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: items
          .map(
            (item) => PopupMenuItem<T>(
              key: item.key,
              value: item.value,
              enabled: item.enabled,
              child: _ActionMenuLabel(item: item, compact: false),
            ),
          )
          .toList(growable: false),
    );
  }
  final theme = Theme.of(context);
  final backgroundColor = theme.colorScheme.surface;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: backgroundColor,
    builder: (bottomSheetContext) => _AdaptiveActionMenuBottomSheetBody<T>(
      items: items,
      onSelected: (value) => Navigator.of(bottomSheetContext).pop(value),
      header: mobileHeader,
      footer: mobileFooter,
      density: mobileDensity,
    ),
  );
}

class _ActionMenuLabel<T> extends StatelessWidget {
  const _ActionMenuLabel({required this.item, required this.compact});

  final AdaptiveActionMenuItem<T> item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = item.destructive
        ? colorScheme.error
        : colorScheme.onSurface;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: compact ? 13 : 14,
      fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
      color: item.enabled
          ? foregroundColor
          : colorScheme.onSurface.withValues(alpha: 0.38),
    );
    if (compact || item.icon == null) {
      return Text(item.label, style: textStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          item.icon,
          size: compact ? 18 : 18,
          color: item.enabled
              ? foregroundColor
              : colorScheme.onSurface.withValues(alpha: 0.38),
        ),
        SizedBox(width: compact ? 12 : 10),
        Flexible(child: Text(item.label, style: textStyle)),
      ],
    );
  }
}

class _AdaptiveActionMenuBottomSheetBody<T> extends StatelessWidget {
  const _AdaptiveActionMenuBottomSheetBody({
    required this.items,
    required this.onSelected,
    required this.density,
    this.header,
    this.footer,
  });

  final List<AdaptiveActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final AdaptiveActionMenuMobileDensity density;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.82;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = density == AdaptiveActionMenuMobileDensity.compact;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, isCompact ? 12 : 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ...?(header == null ? null : <Widget>[header!]),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 8 : 10,
                        isCompact ? 4 : 8,
                        isCompact ? 8 : 10,
                        isCompact ? 6 : 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (var index = 0; index < items.length; index++)
                            _buildActionTile(
                              context,
                              item: items[index],
                              isCompact: isCompact,
                              showSectionDivider:
                                  index > 0 && items[index].startsNewSection,
                            ),
                          ...?(footer == null ? null : <Widget>[footer!]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required AdaptiveActionMenuItem<T> item,
    required bool isCompact,
    required bool showSectionDivider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tile = InkWell(
      key: item.key,
      borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
      onTap: item.enabled ? () => onSelected(item.value) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 10 : 12,
        ),
        child: Row(
          children: <Widget>[
            if (item.icon != null) ...<Widget>[
              Icon(
                item.icon,
                size: isCompact ? 18 : 20,
                color: item.enabled
                    ? (item.destructive
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant)
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              SizedBox(width: isCompact ? 12 : 14),
            ],
            Expanded(
              child: _ActionMenuLabel(item: item, compact: isCompact),
            ),
          ],
        ),
      ),
    );
    if (!showSectionDivider) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 10 : 12,
            isCompact ? 4 : 6,
            isCompact ? 10 : 12,
            isCompact ? 8 : 10,
          ),
          child: Divider(
            height: 1,
            thickness: 0.8,
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        tile,
      ],
    );
  }
}
