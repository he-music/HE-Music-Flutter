import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
import '../utils/platform_utils.dart';
import 'adaptive_action_menu.dart';
import 'app_network_image.dart';

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
  }
}

Future<void> showSongActionsSheet({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPosition,
  bool forceBottomSheet = false,
  bool useRootNavigator = true,
  required String? coverUrl,
  required String title,
  required String subtitle,
  required bool hasMv,
  required String sourceLabel,
  String? playActionLabel,
  required VoidCallback onPlay,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToPlaylist,
  VoidCallback? onDownload,
  VoidCallback? onAddToUserPlaylist,
  VoidCallback? onRemoveFromPlaylist,
  required VoidCallback onWatchMv,
  VoidCallback? onViewDetail,
  VoidCallback? onViewComment,
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
  if (!forceBottomSheet && shouldUseDesktopMenu(context)) {
    final actions = <AdaptiveActionMenuItem<VoidCallback>>[
      AdaptiveActionMenuItem<VoidCallback>(
        value: onPlay,
        label: resolvedPlayActionLabel,
        iconRole: AppSkinIconRole.songPlay,
      ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onPlayNext,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.play_next'),
        iconRole: AppSkinIconRole.songPlayNext,
      ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onAddToPlaylist,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
        iconRole: AppSkinIconRole.songAddToQueue,
      ),
      if (onDownload != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onDownload,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.download'),
          iconRole: AppSkinIconRole.songDownload,
        ),
      if (onAddToUserPlaylist != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onAddToUserPlaylist,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.add_to_playlist',
          ),
          iconRole: AppSkinIconRole.songAddToPlaylist,
        ),
      if (onRemoveFromPlaylist != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onRemoveFromPlaylist,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'detail.batch.remove_from_playlist',
          ),
          iconRole: AppSkinIconRole.songRemove,
        ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onWatchMv,
        label: AppI18n.tByLocaleCode(localeCode, 'player.action.watch_mv'),
        iconRole: AppSkinIconRole.songWatchVideo,
        enabled: hasMv,
      ),
      if (onViewDetail != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onViewDetail,
          label: AppI18n.tByLocaleCode(localeCode, 'song.action.view_detail'),
          iconRole: AppSkinIconRole.songDetails,
        ),
      if (onViewComment != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onViewComment,
          label: AppI18n.tByLocaleCode(
            localeCode,
            'player.action.view_comments',
          ),
          iconRole: AppSkinIconRole.songComments,
        ),
      if (albumActionLabel != null && onViewAlbum != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onViewAlbum,
          label: albumActionLabel,
          iconRole: AppSkinIconRole.songAlbum,
        ),
      if (artistActionLabel != null && onViewArtists != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onViewArtists,
          label: artistActionLabel,
          iconRole: AppSkinIconRole.songArtist,
        ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onCopySongName,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_name'),
        iconRole: AppSkinIconRole.songCopyName,
      ),
      AdaptiveActionMenuItem<VoidCallback>(
        value: onCopySongId,
        label: AppI18n.tByLocaleCode(localeCode, 'song.action.copy_id'),
        iconRole: AppSkinIconRole.songCopyId,
      ),
      if (onCopySongShareLink != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onCopySongShareLink,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.copy_share'),
          iconRole: AppSkinIconRole.songShare,
        ),
      if (onSearchSameName != null)
        AdaptiveActionMenuItem<VoidCallback>(
          value: onSearchSameName,
          label: AppI18n.tByLocaleCode(localeCode, 'player.action.search_same'),
          iconRole: AppSkinIconRole.songSearchSameName,
        ),
    ];
    final navigator = Navigator.of(context);
    return SongActionsSheetController.trackRoute<VoidCallback>(
      routeFuture: showAdaptiveActionMenu<VoidCallback>(
        context: context,
        items: actions,
        anchorContext: anchorContext,
        anchorPosition: anchorPosition,
      ),
      dismiss: () {
        navigator.maybePop();
      },
    ).then((callback) {
      callback?.call();
    });
  }
  return showAppThemedBottomSheet<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _TrackedSongActionsSheetBody(
        child: _SongActionsSheetBody(
          coverUrl: coverUrl,
          title: title,
          subtitle: subtitle,
          resolvedPlayActionLabel: resolvedPlayActionLabel,
          localeCode: localeCode,
          hasMv: hasMv,
          onPlay: onPlay,
          onPlayNext: onPlayNext,
          onAddToPlaylist: onAddToPlaylist,
          onDownload: onDownload,
          onAddToUserPlaylist: onAddToUserPlaylist,
          onRemoveFromPlaylist: onRemoveFromPlaylist,
          onWatchMv: onWatchMv,
          onViewDetail: onViewDetail,
          onViewComment: onViewComment,
          albumActionLabel: albumActionLabel,
          onViewAlbum: onViewAlbum,
          artistActionLabel: artistActionLabel,
          onViewArtists: onViewArtists,
          onCopySongName: onCopySongName,
          onCopySongShareLink: onCopySongShareLink,
          onSearchSameName: onSearchSameName,
          onCopySongId: onCopySongId,
          sourceLabel: sourceLabel,
        ),
      );
    },
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

class _SongActionsSheetBody extends StatelessWidget {
  const _SongActionsSheetBody({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.resolvedPlayActionLabel,
    required this.localeCode,
    required this.hasMv,
    required this.onPlay,
    required this.onPlayNext,
    required this.onAddToPlaylist,
    required this.onDownload,
    required this.onAddToUserPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onWatchMv,
    required this.onViewDetail,
    required this.onViewComment,
    required this.albumActionLabel,
    required this.onViewAlbum,
    required this.artistActionLabel,
    required this.onViewArtists,
    required this.onCopySongName,
    required this.onCopySongShareLink,
    required this.onSearchSameName,
    required this.onCopySongId,
    required this.sourceLabel,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;
  final String resolvedPlayActionLabel;
  final String localeCode;
  final bool hasMv;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;
  final VoidCallback onAddToPlaylist;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToUserPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback onWatchMv;
  final VoidCallback? onViewDetail;
  final VoidCallback? onViewComment;
  final String? albumActionLabel;
  final VoidCallback? onViewAlbum;
  final String? artistActionLabel;
  final VoidCallback? onViewArtists;
  final VoidCallback onCopySongName;
  final VoidCallback? onCopySongShareLink;
  final VoidCallback? onSearchSameName;
  final VoidCallback onCopySongId;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.60;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: <Widget>[
            _SongHeader(coverUrl: coverUrl, title: title, subtitle: subtitle),
            const Divider(height: 1),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songPlay),
              title: Text(resolvedPlayActionLabel),
              onTap: () {
                Navigator.of(context).pop();
                onPlay();
              },
            ),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songPlayNext),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'song.action.play_next'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onPlayNext();
              },
            ),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songAddToQueue),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'song.action.add_to_queue'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onAddToPlaylist();
              },
            ),
            if (onDownload != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songDownload),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'player.action.download'),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onDownload?.call();
                },
              ),
            if (onAddToUserPlaylist != null)
              ListTile(
                leading: const AppSkinIcon(
                  role: AppSkinIconRole.songAddToPlaylist,
                ),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'detail.batch.add_to_playlist',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onAddToUserPlaylist?.call();
                },
              ),
            if (onRemoveFromPlaylist != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songRemove),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'detail.batch.remove_from_playlist',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveFromPlaylist?.call();
                },
              ),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songWatchVideo),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'player.action.watch_mv'),
              ),
              enabled: hasMv,
              onTap: hasMv
                  ? () {
                      Navigator.of(context).pop();
                      onWatchMv();
                    }
                  : null,
            ),
            if (onViewDetail != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songDetails),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'song.action.view_detail'),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onViewDetail?.call();
                },
              ),
            if (onViewComment != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songComments),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'player.action.view_comments',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onViewComment?.call();
                },
              ),
            if (albumActionLabel != null && onViewAlbum != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songAlbum),
                title: Text(albumActionLabel!),
                onTap: () {
                  Navigator.of(context).pop();
                  onViewAlbum?.call();
                },
              ),
            if (artistActionLabel != null && onViewArtists != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songArtist),
                title: Text(artistActionLabel!),
                onTap: () {
                  Navigator.of(context).pop();
                  onViewArtists?.call();
                },
              ),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songCopyName),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'song.action.copy_name'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onCopySongName();
              },
            ),
            ListTile(
              leading: const AppSkinIcon(role: AppSkinIconRole.songCopyId),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'song.action.copy_id'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onCopySongId();
              },
            ),
            if (onCopySongShareLink != null)
              ListTile(
                leading: const AppSkinIcon(role: AppSkinIconRole.songShare),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'player.action.copy_share'),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onCopySongShareLink?.call();
                },
              ),
            if (onSearchSameName != null)
              ListTile(
                leading: const AppSkinIcon(
                  role: AppSkinIconRole.songSearchSameName,
                ),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'player.action.search_same',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onSearchSameName?.call();
                },
              ),
            _SourceInfoRow(label: sourceLabel),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SourceInfoRow extends StatelessWidget {
  const _SourceInfoRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

class _SongHeader extends StatelessWidget {
  const _SongHeader({
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
                  style: Theme.of(context).textTheme.titleMedium,
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
