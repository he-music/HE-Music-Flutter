import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';

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
    final actions = _buildActions(localeCode);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                height: 72,
                child: loading
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        children: <Widget>[
                          for (final action in actions)
                            Expanded(
                              child: _BatchActionButton(
                                action: action,
                                enabled: enabled && action.onPressed != null,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_BatchAction> _buildActions(String localeCode) {
    return <_BatchAction>[
      _BatchAction(
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.play'),
        iconRole: AppSkinIconRole.batchPlay,
        onPressed: onPlayPressed,
      ),
      _BatchAction(
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
        iconRole: AppSkinIconRole.batchAddToQueue,
        onPressed: onAddToQueuePressed,
      ),
      _BatchAction(
        label: AppI18n.tByLocaleCode(
          localeCode,
          'detail.batch.add_to_playlist',
        ),
        iconRole: AppSkinIconRole.batchAddToPlaylist,
        onPressed: onAddToPlaylistPressed,
      ),
      if (onRemoveFromPlaylistPressed != null)
        _BatchAction(
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.remove_from_playlist',
          ),
          iconRole: AppSkinIconRole.songRemove,
          onPressed: onRemoveFromPlaylistPressed,
        ),
    ];
  }
}

class _BatchAction {
  const _BatchAction({
    required this.label,
    required this.iconRole,
    required this.onPressed,
  });

  final String label;
  final AppSkinIconRole iconRole;
  final VoidCallback? onPressed;
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({required this.action, required this.enabled});

  final _BatchAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Tooltip(
      message: action.label,
      child: InkWell(
        onTap: enabled ? action.onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AppSkinIcon(role: action.iconRole, size: 24, color: color),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
