import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_sheet_header.dart';
import 'player_sheet_section.dart';

/// A scrolling, grouped panel for the player's many contextual actions.
class PlayerMorePanel extends StatelessWidget {
  const PlayerMorePanel({required this.children, this.listKey, super.key});

  final List<Widget> children;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<Widget>)>[];
    for (final child in children) {
      if (child is PlayerSheetGroup) {
        groups.add((child.title, <Widget>[]));
      } else if (groups.isNotEmpty &&
          child is! PlayerSheetHero &&
          child is! PlayerSourceInfoRow &&
          child is! SizedBox) {
        groups.last.$2.add(child);
      }
    }
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: AppI18n.tByLocaleCode(
              Localizations.localeOf(context).languageCode,
              'common.more',
            ),
          ),
          Flexible(
            child: ListView(
              key: listKey,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ...children.whereType<PlayerSheetHero>(),
                for (final (title, rows) in groups)
                  if (rows.isNotEmpty)
                    PlayerSheetSection(title: title, children: rows),
                ...children.whereType<PlayerSourceInfoRow>(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A structural group marker, omitted from the Material action list.
class PlayerSheetGroup extends StatelessWidget {
  const PlayerSheetGroup(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
