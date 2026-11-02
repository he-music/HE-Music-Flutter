import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../app/theme/player/app_player_style_theme.dart';
import '../../app/theme/app_ui_theme.dart';
import '../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
import '../constants/layout_tokens.dart';
import '../utils/platform_utils.dart';
import 'adaptive_action_menu.dart';
import 'app_network_image.dart';
import 'app_adaptive_controls.dart';
import 'app_list_tile.dart';

class SongActionsSheetController {
  SongActionsSheetController._();

  static final ValueNotifier<bool> hasOpenSheet = ValueNotifier<bool>(false);
  static VoidCallback? _dismissOpenSheet;

  static bool dismissOpenSheet() {
    final dismiss = _dismissOpenSheet;
    if (dismiss == null) {
      return false;
    }
    dismiss();
    return true;
  }

  static Future<T?> trackRoute<T>({
    required Future<T?> routeFuture,
    required VoidCallback dismiss,
  }) {
    final token = Object();
    _dismissOpenSheet = dismiss;
    if (!hasOpenSheet.value) {
      hasOpenSheet.value = true;
    }
    return routeFuture.whenComplete(() => _unregister(token, dismiss));
  }

  static void _register(Object token, VoidCallback dismiss) {
    _dismissOpenSheet = dismiss;
    _setHasOpenSheet(true);
  }

  static void _unregister(Object token, VoidCallback dismiss) {
    if (_dismissOpenSheet == dismiss) {
      _dismissOpenSheet = null;
      _setHasOpenSheet(false);
    }
  }

  static void _setHasOpenSheet(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasOpenSheet.value != value) {
        hasOpenSheet.value = value;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

Future<void> showSongActionsSheet({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPosition,
  bool forceBottomSheet = false,
  bool useRootNavigator = true,
  required String? coverUrl,
  Uint8List? coverBytes,
  required String title,
  required String subtitle,
  Duration? duration,
  required bool hasMv,
  required String sourceLabel,
  String? playActionLabel,
  VoidCallback? onPlay,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToPlaylist,
  VoidCallback? onDownload,
  VoidCallback? onAddToUserPlaylist,
  VoidCallback? onRemoveFromPlaylist,
  VoidCallback? onWatchMv,
  VoidCallback? onShareFile,
  VoidCallback? onEditMetadata,
  VoidCallback? onViewDetail,
  VoidCallback? onViewComment,
  VoidCallback? onViewSheetMusic,
  String? albumActionLabel,
  VoidCallback? onViewAlbum,
  String? artistActionLabel,
  VoidCallback? onViewArtists,
  required VoidCallback onCopySongName,
  VoidCallback? onCopySongShareLink,
  VoidCallback? onSearchSameName,
  required VoidCallback onCopySongId,
}) {
  final localeCode = Localizations.localeOf(context).languageCode;
  final resolvedPlayActionLabel =
      playActionLabel ?? AppI18n.tByLocaleCode(localeCode, 'song.action.play');
  final groups = <List<AdaptiveActionMenuItem<VoidCallback>>>[
    [
      if (onPlay != null)
        AdaptiveActionMenuItem(
          value: onPlay,
          label: resolvedPlayActionLabel,
          iconRole: AppSkinIconRole.songPlay,
        ),
      AdaptiveActionMenuItem(
        value: onPlayNext,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.play_next'),
        iconRole: AppSkinIconRole.songPlayNext,
      ),
      AdaptiveActionMenuItem(
        value: onAddToPlaylist,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
        iconRole: AppSkinIconRole.songAddToQueue,
      ),
      if (onAddToUserPlaylist != null)
        AdaptiveActionMenuItem(
          value: onAddToUserPlaylist,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.add_to_playlist',
          ),
          iconRole: AppSkinIconRole.songAddToPlaylist,
        ),
      if (onDownload != null)
        AdaptiveActionMenuItem(
          value: onDownload,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.download'),
          iconRole: AppSkinIconRole.songDownload,
        ),
    ],
    [
      if (artistActionLabel != null && onViewArtists != null)
        AdaptiveActionMenuItem(
          value: onViewArtists,
          label: artistActionLabel,
          iconRole: AppSkinIconRole.songArtist,
        ),
      if (albumActionLabel != null && onViewAlbum != null)
        AdaptiveActionMenuItem(
          value: onViewAlbum,
          label: albumActionLabel,
          iconRole: AppSkinIconRole.songAlbum,
        ),
      if (onViewComment != null)
        AdaptiveActionMenuItem(
          value: onViewComment,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'player.action.view_comments',
          ),
          iconRole: AppSkinIconRole.songComments,
        ),
      if (hasMv && onWatchMv != null)
        AdaptiveActionMenuItem(
          value: onWatchMv,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.watch_mv'),
          iconRole: AppSkinIconRole.songWatchVideo,
        ),
      if (onViewSheetMusic != null)
        AdaptiveActionMenuItem(
          value: onViewSheetMusic,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'song.action.view_sheet_music',
          ),
          icon: Icons.library_music_outlined,
        ),
      if (onViewDetail != null)
        AdaptiveActionMenuItem(
          value: onViewDetail,
          label: AppI18n.tByLocaleCode(localeCode, 'song.action.view_detail'),
          iconRole: AppSkinIconRole.songDetails,
        ),
      if (onSearchSameName != null)
        AdaptiveActionMenuItem(
          value: onSearchSameName,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.search_same'),
          iconRole: AppSkinIconRole.songSearchSameName,
        ),
      if (onEditMetadata != null)
        AdaptiveActionMenuItem(
          value: onEditMetadata,
          label: AppI18n.tByLocaleCode(localeCode, 'local.more.edit_metadata'),
          icon: Icons.edit_rounded,
        ),
    ],
    [
      if (onShareFile != null)
        AdaptiveActionMenuItem(
          value: onShareFile,
          label: AppI18n.tByLocaleCode(localeCode, 'local.more.share'),
          iconRole: AppSkinIconRole.songShare,
        ),
      if (onCopySongShareLink != null)
        AdaptiveActionMenuItem(
          value: onCopySongShareLink,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.copy_share'),
          iconRole: AppSkinIconRole.songShare,
        ),
      AdaptiveActionMenuItem(
        value: onCopySongName,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_name'),
        iconRole: AppSkinIconRole.songCopyName,
      ),
      AdaptiveActionMenuItem(
        value: onCopySongId,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_id'),
        iconRole: AppSkinIconRole.songCopyId,
      ),
    ],
    if (onRemoveFromPlaylist != null)
      [
        AdaptiveActionMenuItem(
          value: onRemoveFromPlaylist,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.remove_from_playlist',
          ),
          iconRole: AppSkinIconRole.songRemove,
          destructive: true,
        ),
      ],
  ].where((group) => group.isNotEmpty).toList(growable: false);
  if (!forceBottomSheet && shouldUseDesktopMenu(context)) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    return SongActionsSheetController.trackRoute<VoidCallback>(
      routeFuture: showAdaptiveActionMenu<VoidCallback>(
        context: context,
        items: [for (final group in groups) ...group],
        useRootNavigator: useRootNavigator,
        anchorContext: anchorContext,
        anchorPosition: anchorPosition,
      ),
      dismiss: () => navigator.maybePop(),
    ).then((callback) => callback?.call());
  }
  Widget builder(BuildContext sheetContext) => _TrackedSongActionsSheetBody(
    child: _SongActionsSheetBody(
      groups: groups,
      header: _SongHeader(
        coverUrl: coverUrl,
        coverBytes: coverBytes,
        title: title,
        subtitle: subtitle,
        duration: duration,
      ),
      sourceLabel: sourceLabel,
    ),
  );
  if (Theme.of(context).extension<AppPlayerStyleTheme>() != null) {
    return showPlayerStyledBottomSheet<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      showDragHandle: true,
      useAppAccent: true,
      heightFactor: LayoutTokens.playerActionSheetHeightFactor,
      builder: builder,
    );
  }
  return showAppThemedBottomSheet<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    heightFactor: LayoutTokens.actionSheetMaxHeightFactor,
    builder: builder,
  );
}

class _TrackedSongActionsSheetBody extends StatefulWidget {
  const _TrackedSongActionsSheetBody({required this.child});

  final Widget child;

  @override
  State<_TrackedSongActionsSheetBody> createState() =>
      _TrackedSongActionsSheetBodyState();
}

class _TrackedSongActionsSheetBodyState
    extends State<_TrackedSongActionsSheetBody> {
  final Object _token = Object();
  late final VoidCallback _dismiss;

  @override
  void initState() {
    super.initState();
    _dismiss = () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    };
    SongActionsSheetController._register(_token, _dismiss);
  }

  @override
  void dispose() {
    SongActionsSheetController._unregister(_token, _dismiss);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _SongActionsSheetBody extends StatefulWidget {
  const _SongActionsSheetBody({
    required this.groups,
    required this.header,
    required this.sourceLabel,
  });

  final List<List<AdaptiveActionMenuItem<VoidCallback>>> groups;
  final Widget header;
  final String sourceLabel;

  @override
  State<_SongActionsSheetBody> createState() => _SongActionsSheetBodyState();
}

class _SongActionsSheetBodyState extends State<_SongActionsSheetBody> {
  bool _dismissed = false;

  Future<void> _select(AdaptiveActionMenuItem<VoidCallback> action) async {
    if (_dismissed || !action.enabled) return;
    _dismissed = true;
    final route = ModalRoute.of(context);
    Navigator.of(context).pop();
    await route?.completed;
    action.value();
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = AppUiTheme.usesCupertino(context);
    final locale = Localizations.localeOf(context).languageCode;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: widget.header),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: AppIconButton(
                  key: const ValueKey('song-actions-close'),
                  tooltip: AppI18n.tByLocaleCode(locale, 'common.close'),
                  icon: Icon(
                    cupertino
                        ? CupertinoIcons.xmark_circle_fill
                        : Icons.close_rounded,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              widget.sourceLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (!cupertino) const Divider(height: 1),
          Flexible(
            child: cupertino
                ? _CupertinoSongActions(
                    groups: widget.groups,
                    onSelected: (action) => unawaited(_select(action)),
                  )
                : _MaterialSongActions(
                    groups: widget.groups,
                    onSelected: (action) => unawaited(_select(action)),
                  ),
          ),
        ],
      ),
    );
  }
}

bool _isPlaybackAction(AdaptiveActionMenuItem<VoidCallback> action) =>
    action.iconRole == AppSkinIconRole.songPlay ||
    action.iconRole == AppSkinIconRole.songPlayNext ||
    action.iconRole == AppSkinIconRole.songAddToQueue;

Widget _songActionIcon(
  AdaptiveActionMenuItem<VoidCallback> action,
  Color color,
) => action.iconRole == null
    ? Icon(action.icon, color: color)
    : AppSkinIcon(role: action.iconRole!, color: color);

class _CupertinoSongActions extends ConsumerWidget {
  const _CupertinoSongActions({required this.groups, required this.onSelected});

  final List<List<AdaptiveActionMenuItem<VoidCallback>>> groups;
  final ValueChanged<AdaptiveActionMenuItem<VoidCallback>> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBackground = ref.watch(
      appConfigProvider.select((config) => config.showContentBackground),
    );
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('song-actions-sheet-list'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final group in groups)
          CupertinoListSection.insetGrouped(
            margin: const EdgeInsets.only(bottom: 12),
            backgroundColor: Colors.transparent,
            decoration: BoxDecoration(
              color: showBackground
                  ? Color.alphaBlend(
                      colors.onSurface.withValues(alpha: 0.04),
                      colors.surface,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            children: [
              for (final action in group)
                AppListTile(
                  title: Text(
                    action.label,
                    style: action.destructive
                        ? TextStyle(color: colors.error)
                        : null,
                  ),
                  leading: _songActionIcon(
                    action,
                    action.destructive ? colors.error : colors.primary,
                  ),
                  enabled: action.enabled,
                  onTap: () => onSelected(action),
                ),
            ],
          ),
      ],
    );
  }
}

class _MaterialSongActions extends StatelessWidget {
  const _MaterialSongActions({required this.groups, required this.onSelected});

  final List<List<AdaptiveActionMenuItem<VoidCallback>>> groups;
  final ValueChanged<AdaptiveActionMenuItem<VoidCallback>> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('song-actions-sheet-list'),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) const Divider(height: 17, indent: 16, endIndent: 16),
          for (final action in groups[index])
            ListTile(
              enabled: action.enabled,
              leading: _songActionIcon(
                action,
                action.destructive
                    ? colors.error
                    : _isPlaybackAction(action)
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              textColor: action.destructive ? colors.error : colors.onSurface,
              title: Text(action.label),
              onTap: action.enabled ? () => onSelected(action) : null,
            ),
        ],
      ],
    );
  }
}

class _SongHeader extends StatelessWidget {
  const _SongHeader({
    required this.coverUrl,
    this.coverBytes,
    required this.title,
    required this.subtitle,
    required this.duration,
  });

  final String? coverUrl;
  final Uint8List? coverBytes;
  final String title;
  final String subtitle;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final durationLabel = _formatSongDuration(duration);
    const coverSize = 64.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverBytes != null && coverBytes!.isNotEmpty
                ? Image.memory(
                    coverBytes!,
                    width: coverSize,
                    height: coverSize,
                    fit: BoxFit.cover,
                  )
                : coverUrl == null || coverUrl!.trim().isEmpty
                ? Container(
                    width: coverSize,
                    height: coverSize,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : AppNetworkImage(
                    url: coverUrl!,
                    width: coverSize,
                    height: coverSize,
                    fit: BoxFit.cover,
                    fallback: Container(
                      width: coverSize,
                      height: coverSize,
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
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondaryStyle,
                ),
                if (durationLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    durationLabel,
                    key: const Key('song-actions-duration'),
                    style: secondaryStyle,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatSongDuration(Duration? duration) {
  if (duration == null || duration.inSeconds <= 0) return null;
  final hours = duration.inHours;
  final minutes =
      (hours > 0 ? duration.inMinutes.remainder(60) : duration.inMinutes)
          .toString()
          .padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
