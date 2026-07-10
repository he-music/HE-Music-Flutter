import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../online/presentation/widgets/search_playlist_list_item.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/my_overview_state.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../providers/my_overview_providers.dart';
import '../providers/my_playlist_shelf_providers.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  int _playlistTabIndex = 0;
  final Set<int> _expandedPlaylistTabs = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = theme.platform;
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(myOverviewControllerProvider);
    final historyCount = ref.watch(
      playerControllerProvider.select(
        (playerState) => playerState.historyCount,
      ),
    );
    final tokenSet = config.authToken != null && config.authToken!.isNotEmpty;
    final overview = state.overview;
    final showQrScanEntry =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    _syncOverviewLoading(tokenSet, state);
    final header = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            AppI18n.t(config, 'my.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (showQrScanEntry)
          IconButton(
            tooltip: AppI18n.t(config, 'common.scan'),
            onPressed: () => context.push(AppRoutes.loginQrScan),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        IconButton(
          tooltip: AppI18n.t(config, 'settings.title'),
          onPressed: () => context.push(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
    final accountCard = _AccountCard(
      localeCode: config.localeCode,
      nickname: overview?.profile.nickname,
      username: overview?.profile.username,
      avatarUrl: overview?.profile.avatarUrl,
      tokenSet: tokenSet,
      loading: state.loading,
      onLogin: () => _openLogin(context),
    );
    final errorCard = state.errorMessage == null
        ? null
        : _ErrorCard(
            message: state.errorMessage!,
            retryLabel: AppI18n.t(config, 'common.retry'),
            onRetry: tokenSet
                ? ref.read(myOverviewControllerProvider.notifier).refresh
                : () => _openLogin(context),
          );
    final quickEntryCards = <Widget>[
      _EntryCard(
        icon: Icons.history_rounded,
        title: AppI18n.t(config, 'my.entry.history'),
        subtitle: historyCount > 0
            ? AppI18n.format(config, 'playlist.track_count', <String, String>{
                'count': '$historyCount',
              })
            : null,
        onTap: () => context.push(AppRoutes.myHistory),
      ),
      const SizedBox(height: 10),
      _EntryCard(
        icon: Icons.library_music_rounded,
        title: AppI18n.t(config, 'local.title'),
        onTap: () => context.push(AppRoutes.library),
      ),
      const SizedBox(height: 10),
      _EntryCard(
        icon: Icons.download_rounded,
        title: AppI18n.t(config, 'my.download'),
        onTap: () => context.push(AppRoutes.downloads),
      ),
      if (tokenSet) ...<Widget>[
        const SizedBox(height: 10),
        _EntryCard(
          icon: Icons.favorite_border_rounded,
          title: AppI18n.t(config, 'my.collection'),
          onTap: () => context.push(AppRoutes.myCollection),
        ),
      ],
    ];
    final playlistSection = tokenSet
        ? _PlaylistShelfSection(
            configLocaleCode: config.localeCode,
            selectedIndex: _playlistTabIndex,
            onTabSelected: (index) {
              setState(() {
                _playlistTabIndex = index;
              });
            },
            onCreatePlaylist: _createPlaylist,
            isExpanded: _expandedPlaylistTabs.contains(_playlistTabIndex),
            onToggleExpanded: () {
              setState(() {
                if (_expandedPlaylistTabs.contains(_playlistTabIndex)) {
                  _expandedPlaylistTabs.remove(_playlistTabIndex);
                } else {
                  _expandedPlaylistTabs.add(_playlistTabIndex);
                }
              });
            },
          )
        : null;

    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: <Widget>[
        Positioned(
          top: -topInset,
          left: 0,
          right: 0,
          bottom: 0,
          child: const _MyBackground(),
        ),
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            LayoutTokens.compactPageGutter,
            topInset + 8,
            LayoutTokens.compactPageGutter,
            24,
          ),
          children: <Widget>[
            header,
            const SizedBox(height: 12),
            accountCard,
            if (errorCard != null) ...<Widget>[
              const SizedBox(height: 12),
              errorCard,
            ],
            const SizedBox(height: 18),
            ...quickEntryCards,
            if (playlistSection != null) ...<Widget>[
              const SizedBox(height: 18),
              playlistSection,
            ],
          ],
        ),
      ],
    );
  }

  void _syncOverviewLoading(bool tokenSet, MyOverviewState state) {
    if (!tokenSet) {
      if (state.loading ||
          state.overview != null ||
          state.errorMessage != null) {
        Future.microtask(() {
          ref.read(myOverviewControllerProvider.notifier).clear();
        });
      }
      return;
    }
    if (!state.loading &&
        state.overview == null &&
        state.errorMessage == null) {
      Future.microtask(() {
        ref.read(myOverviewControllerProvider.notifier).initialize();
      });
    }
  }

  void _openLogin(BuildContext context) {
    context.push(
      Uri(
        path: AppRoutes.login,
        queryParameters: const <String, String>{'redirect': AppRoutes.home},
      ).toString(),
    );
  }

  Future<void> _createPlaylist() async {
    final config = ref.read(appConfigProvider);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppI18n.t(config, 'my.playlist.create.title')),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: AppI18n.t(config, 'my.playlist.create.hint'),
            ),
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
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(AppI18n.t(config, 'my.playlist.create.submit')),
            ),
          ],
        );
      },
    );
    controller.dispose();
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

class _MyBackground extends StatelessWidget {
  const _MyBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.primaryContainer.withValues(alpha: 0.10),
              theme.colorScheme.surface.withValues(alpha: 0.98),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.localeCode,
    required this.nickname,
    required this.username,
    required this.avatarUrl,
    required this.tokenSet,
    required this.loading,
    required this.onLogin,
  });

  final String localeCode;
  final String? nickname;
  final String? username;
  final String? avatarUrl;
  final bool tokenSet;
  final bool loading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = (nickname ?? '').trim().isNotEmpty
        ? nickname!.trim()
        : ((username ?? '').trim().isNotEmpty
              ? username!.trim()
              : AppI18n.tByLocaleCode(localeCode, 'my.profile.guest'));
    final subtitle = tokenSet
        ? ((username ?? '').trim().isEmpty
              ? AppI18n.tByLocaleCode(localeCode, 'my.profile.logged_in')
              : '@${username!.trim()}')
        : AppI18n.tByLocaleCode(localeCode, 'my.profile.login_hint');
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          AppNetworkAvatar(
            imageUrl: avatarUrl,
            radius: 30,
            backgroundColor: colorScheme.primaryContainer,
            fallbackIcon: Icons.person_rounded,
            iconColor: colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                else if (!tokenSet) ...<Widget>[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onLogin,
                    child: Text(
                      AppI18n.tByLocaleCode(localeCode, 'my.profile.login_now'),
                    ),
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.64,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
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
                icon: Icons.add_rounded,
                tooltip: AppI18n.tByLocaleCode(
                  configLocaleCode,
                  'my.playlist.create.title',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeState.isLoading && items.isEmpty)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (activeState.hasError && items.isEmpty)
          _InlineRetryCard(
            message: AppI18n.tByLocaleCode(
              configLocaleCode,
              'my.playlist.load_failed',
            ),
            retryLabel: AppI18n.tByLocaleCode(configLocaleCode, 'common.retry'),
            onRetry: () => ref.invalidate(
              selectedIndex == 0
                  ? myCreatedPlaylistsProvider
                  : myFavoritePlaylistsProvider,
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlaylistTabButton(
          label: AppI18n.tByLocaleCode(localeCode, 'my.playlist.tab.created'),
          selected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        const SizedBox(width: 10),
        _PlaylistTabButton(
          label: AppI18n.tByLocaleCode(localeCode, 'my.playlist.tab.favorites'),
          selected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
      ],
    );
  }
}

class _PlaylistTabButton extends StatelessWidget {
  const _PlaylistTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 26 : 12,
                height: 3,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistActionButton extends StatelessWidget {
  const _PlaylistActionButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final Future<void> Function() onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: colorScheme.onSurface),
            ),
          ),
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
        for (var index = 0; index < visibleItems.length; index++) ...<Widget>[
          SearchPlaylistListItem(
            title: visibleItems[index].title,
            subtitle: visibleItems[index].subtitle,
            coverUrl: visibleItems[index].coverUrl,
            songCountText: buildPlaylistSongCountText(
              count: visibleItems[index].songCount,
              localeCode: localeCode,
            ),
            onTap: () {
              if (isCreatedList) {
                context.push(
                  Uri(
                    path: AppRoutes.userPlaylistDetail,
                    queryParameters: <String, String>{
                      'id': visibleItems[index].id,
                      'title': visibleItems[index].title,
                    },
                  ).toString(),
                );
                return;
              }
              context.push(
                Uri(
                  path: AppRoutes.playlistDetail,
                  queryParameters: <String, String>{
                    'id': visibleItems[index].id,
                    'platform': visibleItems[index].platform,
                    'title': visibleItems[index].title,
                  },
                ).toString(),
              );
            },
          ),
          if (index != visibleItems.length - 1) const SizedBox(height: 10),
        ],
        if (items.length > 5) ...<Widget>[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              expanded
                  ? AppI18n.tByLocaleCode(localeCode, 'my.playlist.collapse')
                  : AppI18n.tByLocaleCode(localeCode, 'my.playlist.expand'),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
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
