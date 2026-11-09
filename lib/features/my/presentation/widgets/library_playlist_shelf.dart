import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_alert_dialog.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../providers/my_collection_providers.dart';
import '../providers/my_overview_providers.dart';
import '../providers/my_playlist_shelf_providers.dart';

/// Keeps playlist browsing, creation and expansion state inside the library.
class LibraryPlaylistShelf extends ConsumerStatefulWidget {
  const LibraryPlaylistShelf({super.key});

  @override
  ConsumerState<LibraryPlaylistShelf> createState() =>
      _LibraryPlaylistShelfState();
}

class _LibraryPlaylistShelfState extends ConsumerState<LibraryPlaylistShelf> {
  int _playlistTabIndex = 0;
  final Set<int> _expandedPlaylistTabs = <int>{};

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    return _PlaylistShelfSection(
      configLocaleCode: locale,
      selectedIndex: _playlistTabIndex,
      onTabSelected: (index) {
        if (index == _playlistTabIndex) return;
        if (index == 1) {
          ref.read(myCollectionControllerProvider.notifier).refreshAll();
        }
        setState(() => _playlistTabIndex = index);
      },
      onCreatePlaylist: _createPlaylist,
      isExpanded: _expandedPlaylistTabs.contains(_playlistTabIndex),
      onToggleExpanded: () {
        setState(() {
          if (!_expandedPlaylistTabs.remove(_playlistTabIndex)) {
            _expandedPlaylistTabs.add(_playlistTabIndex);
          }
        });
      },
    );
  }

  Future<void> _createPlaylist() async {
    final config = ref.read(appConfigProvider);
    var playlistName = '';
    final name = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AppAlertDialog(
          title: Text(AppI18n.t(config, 'my.playlist.create.title')),
          content: AppTextField(
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: AppI18n.t(config, 'my.playlist.create.hint'),
            ),
            onChanged: (value) {
              playlistName = value;
            },
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppI18n.t(config, 'common.cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(playlistName.trim()),
              child: Text(AppI18n.t(config, 'my.playlist.create.submit')),
            ),
          ],
        );
      },
    );
    final normalized = (name ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .createPlaylist(normalized);
      ref.invalidate(myCreatedPlaylistsProvider);
      ref.invalidate(myOverviewControllerProvider);
      if (!mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.t(config, 'my.playlist.create.done'),
      );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(config, 'my.playlist.create.failed'),
      );
    }
  }
}

class _PlaylistShelfSection extends ConsumerWidget {
  const _PlaylistShelfSection({
    required this.configLocaleCode,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onCreatePlaylist,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final String configLocaleCode;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Future<void> Function() onCreatePlaylist;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdState = ref.watch(myCreatedPlaylistsProvider);
    final favoriteState = ref.watch(myFavoritePlaylistsProvider);
    final activeState = selectedIndex == 0 ? createdState : favoriteState;
    final items = activeState.value ?? const <MyFavoriteItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PlaylistTabs(
                  localeCode: configLocaleCode,
                  selectedIndex: selectedIndex,
                  onSelected: onTabSelected,
                ),
              ),
            ),
            if (selectedIndex == 0)
              _PlaylistActionButton(
                onPressed: onCreatePlaylist,
                iconRole: AppSkinIconRole.myPlaylistCreate,
                tooltip: AppI18n.tByLocaleCode(
                  configLocaleCode,
                  'my.playlist.create.title',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (activeState.isLoading && items.isEmpty)
          const _PlaylistShelfLoadingSkeleton()
        else if (activeState.hasError && items.isEmpty)
          _InlineRetryCard(
            message: AppI18n.tByLocaleCode(
              configLocaleCode,
              'my.playlist.load_failed',
            ),
            retryLabel: AppI18n.tByLocaleCode(configLocaleCode, 'common.retry'),
            onRetry: () {
              if (selectedIndex == 0) {
                ref.invalidate(myCreatedPlaylistsProvider);
              } else {
                ref.read(myCollectionControllerProvider.notifier).refreshAll();
              }
            },
          )
        else if (items.isEmpty)
          _EmptyShelfCard(
            message: AppI18n.tByLocaleCode(
              configLocaleCode,
              'my.playlist.empty',
            ),
          )
        else
          _PlaylistList(
            items: items,
            isCreatedList: selectedIndex == 0,
            localeCode: configLocaleCode,
            expanded: isExpanded,
            onToggleExpanded: onToggleExpanded,
          ),
      ],
    );
  }
}

class _PlaylistShelfLoadingSkeleton extends StatelessWidget {
  const _PlaylistShelfLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey<String>('my-playlist-shelf-loading-skeleton'),
      height: 180,
      child: Column(
        children: <Widget>[
          _PlaylistShelfRowSkeleton(),
          SizedBox(height: 8),
          _PlaylistShelfRowSkeleton(),
        ],
      ),
    );
  }
}

class _PlaylistShelfRowSkeleton extends StatelessWidget {
  const _PlaylistShelfRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 64, height: 64, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: double.infinity, height: 15, radius: 7),
                SizedBox(height: 9),
                SkeletonBox(width: 132, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTabs extends StatelessWidget {
  const _PlaylistTabs({
    required this.localeCode,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String localeCode;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: <Widget>[
        UnderlineTab(
          enabled: true,
          label: AppI18n.tByLocaleCode(localeCode, 'my.playlist.tab.created'),
          selected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        UnderlineTab(
          enabled: true,
          label: AppI18n.tByLocaleCode(localeCode, 'my.playlist.tab.favorites'),
          selected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
      ],
    );
  }
}

class _PlaylistActionButton extends StatelessWidget {
  const _PlaylistActionButton({
    required this.onPressed,
    required this.iconRole,
    required this.tooltip,
  });

  final Future<void> Function() onPressed;
  final AppSkinIconRole iconRole;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: AppIconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: AppSkinIcon(
          role: iconRole,
          size: 20,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.items,
    required this.isCreatedList,
    required this.localeCode,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<MyFavoriteItem> items;
  final bool isCreatedList;
  final String localeCode;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final visibleItems = expanded
        ? items
        : items.take(5).toList(growable: false);
    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep covers prominent; extra text space comes from natural height.
            final columns = (constraints.maxWidth / 160).floor().clamp(1, 6);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (final item in visibleItems)
                  SizedBox(
                    width: width,
                    child: MediaGridCard(
                      kind: MediaGridCardKind.playlist,
                      title: item.title,
                      subtitle: item.subtitle,
                      coverUrl: item.coverUrl,
                      caption: buildPlaylistSongCountText(
                        count: item.songCount,
                        localeCode: localeCode,
                      ),
                      onTap: () {
                        if (isCreatedList) {
                          context.push(
                            Uri(
                              path: AppRoutes.userPlaylistDetail,
                              queryParameters: <String, String>{
                                'id': item.id,
                                'title': item.title,
                              },
                            ).toString(),
                          );
                          return;
                        }
                        context.push(
                          Uri(
                            path: AppRoutes.playlistDetail,
                            queryParameters: <String, String>{
                              'id': item.id,
                              'platform': item.platform,
                              'title': item.title,
                            },
                          ).toString(),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        if (items.length > 5) ...<Widget>[
          const SizedBox(height: 16),
          AppButton.text(
            onPressed: onToggleExpanded,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    expanded
                        ? AppI18n.tByLocaleCode(
                            localeCode,
                            'my.playlist.collapse',
                          )
                        : AppI18n.tByLocaleCode(
                            localeCode,
                            'my.playlist.expand',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineRetryCard extends StatelessWidget {
  const _InlineRetryCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppSkinContentSurface.backgroundColorOf(
          context,
          materialColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          const SizedBox(width: 8),
          AppButton.text(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

class _EmptyShelfCard extends StatelessWidget {
  const _EmptyShelfCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppSkinContentSurface.backgroundColorOf(
          context,
          materialColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
