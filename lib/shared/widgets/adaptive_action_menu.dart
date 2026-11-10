import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../app/theme/app_ui_theme.dart';

import '../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../app/theme/player/app_player_style_theme.dart';
import 'app_adaptive_controls.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
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
    this.iconRole,
    this.enabled = true,
    this.destructive = false,
    this.selected,
    this.startsNewSection = false,
  });

  final T value;
  final String label;
  final Key? key;
  final IconData? icon;
  final AppSkinIconRole? iconRole;
  final bool enabled;
  final bool destructive;

  /// Null for commands; a boolean exposes the state of a choice.
  final bool? selected;
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
      child: AppIconButton(
        key: widget.menuKey,
        onPressed: widget.items.isEmpty ? null : _openMenu,
        tooltip: widget.tooltip,
        icon: widget.icon,
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
      useRootOverlay: true,
    );
    return showMenu<T>(
      context: context,
      useRootNavigator: true,
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
    if (AppUiTheme.usesCupertino(context)) {
      return _showCupertinoActions(context, widget.items);
    }
    return _showActionMenuBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      builder: (bottomSheetContext) => _AdaptiveActionMenuBottomSheetBody<T>(
        items: widget.items,
        onSelected: (value) => Navigator.of(bottomSheetContext).pop(value),
        density: widget.mobileDensity,
      ),
    );
  }
}

Future<T?> _showActionMenuBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool useRootNavigator,
}) {
  if (Theme.of(context).extension<AppPlayerStyleTheme>() != null) {
    return showPlayerStyledBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      fitContent: true,
      builder: builder,
    );
  }
  return showAppThemedBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    fitContent: true,
    builder: builder,
  );
}

RelativeRect _resolveContextMenuPosition(
  BuildContext context, {
  BuildContext? anchorContext,
  Offset? anchorPosition,
  bool useRootOverlay = false,
}) {
  final overlay =
      Overlay.of(
            context,
            rootOverlay: useRootOverlay,
          ).context.findRenderObject()!
          as RenderBox;
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
  Widget? title,
  Widget? message,
  bool forceBottomSheet = false,
  bool useRootNavigator = true,
  Widget? mobileFooter,
  AdaptiveActionMenuMobileDensity mobileDensity =
      AdaptiveActionMenuMobileDensity.compact,
}) {
  final useContextMenu = !forceBottomSheet && shouldUseDesktopMenu(context);
  if (useContextMenu) {
    final snapshot = AdaptiveActionMenuAnchor._consume();
    final resolvedAnchorPosition = anchorPosition ?? snapshot.globalPosition;
    final resolvedAnchorContext = anchorContext ?? snapshot.context ?? context;
    final position = _resolveContextMenuPosition(
      context,
      anchorContext: resolvedAnchorContext,
      anchorPosition: resolvedAnchorPosition,
      useRootOverlay: useRootNavigator,
    );
    return showMenu<T>(
      context: context,
      useRootNavigator: useRootNavigator,
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
  if (AppUiTheme.usesCupertino(context) &&
      mobileHeader == null &&
      mobileFooter == null) {
    return _showCupertinoActions(
      context,
      items,
      title: title,
      message: message,
      useRootNavigator: useRootNavigator,
    );
  }
  return _showActionMenuBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (bottomSheetContext) => _AdaptiveActionMenuBottomSheetBody<T>(
      items: items,
      onSelected: (value) => Navigator.of(bottomSheetContext).pop(value),
      header: mobileHeader,
      footer: mobileFooter,
      density: mobileDensity,
    ),
  );
}

Future<T?> _showCupertinoActions<T>(
  BuildContext context,
  List<AdaptiveActionMenuItem<T>> items, {
  Widget? title,
  Widget? message,
  bool useRootNavigator = true,
}) async {
  var dismissed = false;
  ModalRoute<T>? popupRoute;
  void dismiss(BuildContext popupContext, [T? value]) {
    if (dismissed) return;
    dismissed = true;
    Navigator.of(popupContext).pop(value);
  }

  Widget builder(BuildContext popupContext) {
    popupRoute = ModalRoute.of<T>(popupContext);
    return CupertinoActionSheet(
      title: title,
      message: message,
      actions: [
        for (final item in items)
          if (item.enabled)
            CupertinoActionSheetAction(
              key: item.key,
              isDestructiveAction: item.destructive,
              onPressed: () => dismiss(popupContext, item.value),
              child: Semantics(
                selected: item.selected,
                child: item.selected == true
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ExcludeSemantics(
                            child: Icon(CupertinoIcons.check_mark, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(item.label)),
                        ],
                      )
                    : Text(item.label),
              ),
            )
          else
            CupertinoButton(
              key: item.key,
              onPressed: null,
              child: Text(item.label),
            ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => dismiss(popupContext),
        child: Text(CupertinoLocalizations.of(popupContext).cancelButtonLabel),
      ),
    );
  }

  final popup = Theme.of(context).extension<AppPlayerStyleTheme>() != null
      ? showPlayerCupertinoActionSheet<T>(
          context: context,
          useRootNavigator: useRootNavigator,
          sheetBuilder: builder,
        )
      : showCupertinoModalPopup<T>(
          context: context,
          useRootNavigator: useRootNavigator,
          semanticsDismissible: true,
          builder: builder,
        );
  final result = await popup;
  // A subsequent menu or detail route must not overlap the outgoing popup.
  await popupRoute?.completed;
  return result;
}

class _ActionMenuLabel<T> extends StatelessWidget {
  const _ActionMenuLabel({
    required this.item,
    required this.compact,
    this.showIcon = true,
  });

  final AdaptiveActionMenuItem<T> item;
  final bool compact;
  final bool showIcon;

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
    if (!showIcon || compact || (item.icon == null && item.iconRole == null)) {
      return Text(item.label, style: textStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionMenuIcon<T>(
          item: item,
          size: 18,
          color: item.enabled
              ? (item.destructive ? colorScheme.error : colorScheme.primary)
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
            if (item.icon != null || item.iconRole != null) ...<Widget>[
              _ActionMenuIcon<T>(
                item: item,
                size: isCompact ? 18 : 20,
                color: item.enabled
                    ? (item.destructive
                          ? colorScheme.error
                          : colorScheme.primary)
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              SizedBox(width: isCompact ? 12 : 14),
            ],
            Expanded(
              child: _ActionMenuLabel(
                item: item,
                compact: isCompact,
                showIcon: false,
              ),
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

class _ActionMenuIcon<T> extends StatelessWidget {
  const _ActionMenuIcon({
    required this.item,
    required this.size,
    required this.color,
  });

  final AdaptiveActionMenuItem<T> item;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final role = item.iconRole;
    if (role != null) {
      return AppSkinIcon(role: role, size: size, color: color);
    }
    return Icon(item.icon, size: size, color: color);
  }
}
