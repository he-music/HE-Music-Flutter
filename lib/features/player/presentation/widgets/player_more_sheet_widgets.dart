import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/widgets/app_network_image.dart';

/// The more menu keeps its existing consumers and actions inside the SDK sheet.
class PlayerMoreActionSheet extends StatelessWidget {
  const PlayerMoreActionSheet({
    required this.children,
    this.listKey,
    super.key,
  });

  final List<Widget> children;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    final heroes = children.whereType<PlayerSheetHero>().toList();
    final sources = children.whereType<PlayerSourceInfoRow>().toList();
    final typography = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight =
        scaler.scale(typography.titleMedium?.fontSize ?? 16) *
        (typography.titleMedium?.height ?? 1.2);
    final subtitleHeight =
        scaler.scale(typography.bodySmall?.fontSize ?? 12) *
        (typography.bodySmall?.height ?? 1.2);
    final textHeight = titleHeight + subtitleHeight + 3;
    // The SDK sheet measures intrinsic height; the cover image uses LayoutBuilder.
    final heroHeight = (textHeight < 48 ? 48.0 : textHeight) + 14;
    return _PlayerActionSheetScope(
      child: CupertinoActionSheet(
        key: listKey,
        title: heroes.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final hero in heroes)
                    SizedBox(height: heroHeight, child: hero),
                ],
              ),
        message: sources.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (final source in sources) Text(source.label)],
              ),
        actions: [
          for (final child in children)
            if (child is! PlayerSheetHero &&
                child is! PlayerSourceInfoRow &&
                child is! SizedBox)
              child,
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(CupertinoLocalizations.of(context).cancelButtonLabel),
        ),
      ),
    );
  }
}

class _PlayerActionSheetScope extends InheritedWidget {
  const _PlayerActionSheetScope({required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlayerActionSheetScope>() !=
      null;

  @override
  bool updateShouldNotify(_PlayerActionSheetScope oldWidget) => false;
}

/// 更多操作表单的头部，显示封面、标题和副标题
class PlayerSheetHero extends StatelessWidget {
  const PlayerSheetHero({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.subtitle,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl == null || coverUrl!.trim().isEmpty
                ? Container(
                    width: 48,
                    height: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : AppNetworkImage(
                    url: coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    fallback: Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.music_note_rounded),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 更多操作表单的操作项
class PlayerSheetActionTile extends StatelessWidget {
  const PlayerSheetActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (_PlayerActionSheetScope.contains(context)) {
      final actionable = enabled && onTap != null;
      final color = actionable
          ? CupertinoColors.label.resolveFrom(context)
          : CupertinoColors.inactiveGray.resolveFrom(context);
      final label = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: color)),
          if ((subtitle ?? '').trim().isNotEmpty)
            Text(
              subtitle!.trim(),
              style: TextStyle(color: color.withValues(alpha: 0.72)),
            ),
        ],
      );
      return actionable
          ? CupertinoActionSheetAction(onPressed: onTap!, child: label)
          : CupertinoButton(onPressed: null, child: label);
    }
    return AppListTile(
      enabled: enabled,
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: (subtitle ?? '').trim().isEmpty ? null : Text(subtitle!.trim()),
      showChevron: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

/// 来源信息行
class PlayerSourceInfoRow extends StatelessWidget {
  const PlayerSourceInfoRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (AppUiTheme.usesCupertino(context)) {
      return AppListTile(
        enabled: false,
        leading: Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      enabled: false,
      minTileHeight: 40,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
