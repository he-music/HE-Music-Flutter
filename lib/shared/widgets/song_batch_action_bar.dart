import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import '../utils/platform_utils.dart';
import 'adaptive_action_menu.dart';

class SongBatchActionBar extends StatelessWidget {
  const SongBatchActionBar({
    required this.enabled,
    this.loading = false,
    this.onPlayPressed,
    this.onAddToQueuePressed,
    this.onAddToPlaylistPressed,
    this.onRemoveFromPlaylistPressed,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onAddToQueuePressed;
  final VoidCallback? onAddToPlaylistPressed;
  final VoidCallback? onRemoveFromPlaylistPressed;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Builder(
            builder: (buttonContext) => FilledButton(
              onPressed: enabled && !loading
                  ? () => _showActionsSheet(buttonContext, localeCode)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (loading) ...<Widget>[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    AppI18n.tByLocaleCode(localeCode, 'detail.batch.action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context, String localeCode) {
    if (shouldUseDesktopMenu(context)) {
      return showAdaptiveActionMenu<VoidCallback>(
        context: context,
        anchorContext: context,
        items: _buildActions(localeCode),
      ).then((callback) {
        callback?.call();
      });
    }
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.60;
        final items = _buildActions(localeCode);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: <Widget>[
                for (final item in items)
                  ListTile(
                    key: item.key,
                    leading: item.icon == null ? null : Icon(item.icon),
                    enabled: item.enabled,
                    title: Text(item.label),
                    onTap: item.enabled
                        ? () {
                            Navigator.of(sheetContext).pop();
                            item.value();
                          }
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AdaptiveActionMenuItem<VoidCallback>> _buildActions(String localeCode) {
    return <AdaptiveActionMenuItem<VoidCallback>>[
      AdaptiveActionMenuItem<VoidCallback>(
        value: onPlayPressed ?? () {},
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.play'),
        icon: Icons.play_arrow_rounded,
        enabled: onPlayPressed != null,
      ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onAddToQueuePressed ?? () {},
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
        icon: Icons.queue_music_rounded,
        enabled: onAddToQueuePressed != null,
      ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onAddToPlaylistPressed ?? () {},
        label: AppI18n.tByLocaleCode(
          localeCode,
          'detail.batch.add_to_playlist',
        ),
        icon: Icons.playlist_add_rounded,
        enabled: onAddToPlaylistPressed != null,
      ),
      if (onRemoveFromPlaylistPressed != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onRemoveFromPlaylistPressed!,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.remove_from_playlist',
          ),
          icon: Icons.playlist_remove_rounded,
        ),
    ];
  }
}
