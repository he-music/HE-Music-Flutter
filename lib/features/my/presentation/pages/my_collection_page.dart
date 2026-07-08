import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../../online/presentation/widgets/search_playlist_list_item.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';
import '../providers/my_collection_providers.dart';

class MyCollectionPage extends ConsumerStatefulWidget {
  const MyCollectionPage({super.key});

  @override
  ConsumerState<MyCollectionPage> createState() => _MyCollectionPageState();
}

class _MyCollectionPageState extends ConsumerState<MyCollectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(myCollectionControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(myCollectionControllerProvider);
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'my.collection')),
          actions: <Widget>[
            IconButton(
              onPressed: ref
                  .read(myCollectionControllerProvider.notifier)
                  .refreshAll,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: AppI18n.t(config, 'my.refresh'),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            _TypeTabs(
              config: config,
              selectedType: state.selectedType,
              onTypeSelected: ref
                  .read(myCollectionControllerProvider.notifier)
                  .selectType,
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              _ErrorPanel(
                message: state.errorMessage!,
                retryLabel: AppI18n.t(config, 'my.retry'),
                onRetry: ref
                    .read(myCollectionControllerProvider.notifier)
                    .refreshAll,
              ),
            Expanded(
              child: _CollectionList(
                config: config,
                selectedType: state.selectedType,
                items: state.selectedItems,
                emptyText: AppI18n.t(config, 'my.collection.empty'),
                onRemove: (item) => _confirmRemove(context, config, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppConfigState config,
    MyFavoriteItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppI18n.t(config, 'my.collection.remove')),
          content: Text(AppI18n.t(config, 'my.collection.remove_confirm')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppI18n.t(config, 'my.collection.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppI18n.t(config, 'my.collection.confirm')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(item);
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.config,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final AppConfigState config;
  final MyFavoriteType selectedType;
  final ValueChanged<MyFavoriteType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          UnderlineTab(
            label: AppI18n.t(config, 'my.collection.tab.playlists'),
            selected: selectedType == MyFavoriteType.playlists,
            enabled: true,
            onTap: () => onTypeSelected(MyFavoriteType.playlists),
          ),
          const SizedBox(width: 12),
          UnderlineTab(
            label: AppI18n.t(config, 'my.collection.tab.artists'),
            selected: selectedType == MyFavoriteType.artists,
            enabled: true,
            onTap: () => onTypeSelected(MyFavoriteType.artists),
          ),
          const SizedBox(width: 12),
          UnderlineTab(
            label: AppI18n.t(config, 'my.collection.tab.albums'),
            selected: selectedType == MyFavoriteType.albums,
            enabled: true,
            onTap: () => onTypeSelected(MyFavoriteType.albums),
          ),
        ],
      ),
    );
  }
}

class _CollectionList extends ConsumerWidget {
  const _CollectionList({
    required this.config,
    required this.selectedType,
    required this.items,
    required this.emptyText,
    required this.onRemove,
  });

  final AppConfigState config;
  final MyFavoriteType selectedType;
  final List<MyFavoriteItem> items;
  final String emptyText;
  final ValueChanged<MyFavoriteItem> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return SongListComponent(
      itemCount: items.length,
      enablePaging: false,
      itemBuilder: (context, index) {
        final item = items[index];
        if (selectedType == MyFavoriteType.playlists) {
          return SearchPlaylistListItem(
            title: item.title,
            subtitle: item.subtitle,
            coverUrl: item.coverUrl,
            songCountText: buildPlaylistSongCountText(
              count: item.songCount,
              localeCode: config.localeCode,
            ),
            onTap: () {
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
          );
        }
        return ListTile(
          leading: _CoverAvatar(coverUrl: item.coverUrl),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing: IconButton(
            onPressed: () => onRemove(item),
            icon: const Icon(Icons.favorite_rounded),
            color: Theme.of(context).colorScheme.error,
            tooltip: AppI18n.t(config, 'my.collection.remove'),
          ),
        );
      },
    );
  }
}

class _CoverAvatar extends StatelessWidget {
  const _CoverAvatar({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
      return AppNetworkAvatar(
        imageUrl: coverUrl,
        radius: 20,
        fallbackIcon: Icons.music_note_rounded,
      );
    }
    return const CircleAvatar(child: Icon(Icons.music_note_rounded));
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
