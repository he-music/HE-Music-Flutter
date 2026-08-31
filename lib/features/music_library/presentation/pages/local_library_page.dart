import 'dart:async';
import 'dart:io' show File, FileSystemException, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/database/local_music_database.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../features/player/domain/entities/player_track.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../controllers/local_library_controller.dart';
import '../helpers/local_song_share_action.dart';
import '../providers/local_library_providers.dart';

enum _LocalLibraryView { songs, artists, albums, genres, folders }

class LocalLibraryPage extends ConsumerStatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  ConsumerState<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends ConsumerState<LocalLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  _LocalLibraryView _view = _LocalLibraryView.songs;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // 页面首次加载时开始监听歌曲列表流
      Future.microtask(() {
        ref.read(localLibraryControllerProvider.notifier).startWatchingSongs();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localLibraryControllerProvider);
    final controller = ref.read(localLibraryControllerProvider.notifier);
    final selectionController = ref.read(
      localLibrarySelectionProvider.notifier,
    );
    final isMultiSelectMode = ref.watch(
      localLibrarySelectionProvider.select((state) => state.isMultiSelectMode),
    );
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final isSearching = controller.searchState.isActive;
    final page = Scaffold(
      appBar: _LocalLibraryAppBar(
        state: state,
        controller: controller,
        localeCode: localeCode,
        isSearching: isSearching,
        searchController: _searchController,
        onCloseSearch: () => _closeSearch(controller),
        onClearSearch: () => _clearSearch(controller),
        onShowClearDialog: () =>
            _showClearDialog(context, controller, localeCode),
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Expanded(
            child: state.when(
              data: (songs) => _SongList(
                songs: songs,
                view: _view,
                onScan: controller.scanLibrary,
                onClear: controller.clearLibrary,
                localeCode: localeCode,
                sortBy: controller.sortBy,
                sortAscending: controller.sortAscending,
                artistGroups: controller.artistGroups,
                albumGroups: controller.albumGroups,
                genreGroups: controller.genreGroups,
                loadingMore: controller.loadingMore,
                hasMore: controller.hasMore,
                loadMoreErrorMessage: controller.loadMoreErrorMessage,
                onViewChanged: (view) => setState(() => _view = view),
                onPlayTap: (index) =>
                    _playLocalSong(context, ref, songs, index),
                onPlayGroupTap: (groupSongs, index) =>
                    _playLocalSong(context, ref, groupSongs, index),
                onMoreTap: (song) =>
                    _showMoreActionsSheet(context, song, localeCode, ref),
                onSortChanged: controller.changeSortBy,
                onLoadMore: controller.loadMore,
                onLongPress: selectionController.enterMultiSelect,
                onSelectionToggle: selectionController.toggleSelection,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorView(
                message: '$error',
                localeCode: localeCode,
                onRetry: controller.scanLibrary,
              ),
            ),
          ),
          _LocalLibrarySelectionBottomBar(
            songs: state.asData?.value ?? const <LocalSong>[],
            localeCode: localeCode,
            onPlay: (songs) async {
              selectionController.exitMultiSelect();
              await _playLocalSong(context, ref, songs, 0);
            },
            onAddToQueue: (songs) {
              for (final song in songs) {
                ref
                    .read(playerControllerProvider.notifier)
                    .appendTrack(_toPlayerTrack(song));
              }
              selectionController.exitMultiSelect();
            },
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !isMultiSelectMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isMultiSelectMode) {
          selectionController.exitMultiSelect();
        }
      },
      child: page,
    );
  }

  Future<void> _playLocalSong(
    BuildContext context,
    WidgetRef ref,
    List<LocalSong> songs,
    int index,
  ) async {
    if (index < 0 || index >= songs.length) {
      return;
    }
    final song = songs[index];
    // 从磁盘缓存获取封面文件路径，持久化后可恢复
    final extractor = ref.read(localArtworkExtractorProvider);
    final artworkFile = await extractor.getArtworkFile(song.filePath);
    final track = _toPlayerTrack(song, artworkUrl: artworkFile?.path);
    await ref.read(playerControllerProvider.notifier).insertNextAndPlay(track);
    // 记录播放统计
    ref.read(localMusicRepositoryProvider).incrementPlayCount(song.id);
  }

  PlayerTrack _toPlayerTrack(LocalSong song, {String? artworkUrl}) {
    return PlayerTrack(
      id: 'local-${song.id}',
      title: song.title,
      path: song.filePath,
      artist: song.artist,
      album: song.album,
      url: '',
      artworkUrl: artworkUrl,
      artworkBytes: song.artworkBytes,
      format: song.formatLabel.isEmpty ? null : song.formatLabel,
      bitrate: song.bitrate,
      sampleRate: song.sampleRate,
      platform: 'local',
    );
  }

  void _clearSearch(LocalLibraryController controller) {
    _searchController.clear();
    controller.updateSearchQuery('');
  }

  void _closeSearch(LocalLibraryController controller) {
    _searchController.clear();
    controller.toggleSearch();
  }

  Future<void> _showClearDialog(
    BuildContext context,
    LocalLibraryController controller,
    String localeCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppI18n.tByLocaleCode(localeCode, 'local.clear_dialog.title'),
        ),
        content: Text(
          AppI18n.tByLocaleCode(localeCode, 'local.clear_dialog.content'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppI18n.tByLocaleCode(localeCode, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'local.clear_dialog.confirm'),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearLibrary();
    }
  }

  void _showMoreActionsSheet(
    BuildContext context,
    LocalSong song,
    String localeCode,
    WidgetRef ref,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'local.more.play_next'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _playLocalSong(context, ref, [song], 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'local.more.add_to_queue'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                final track = _toPlayerTrack(song);
                ref.read(playerControllerProvider.notifier).appendTrack(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'local.more.share'),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await _shareLocalSong(context, song, localeCode, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(
                AppI18n.tByLocaleCode(localeCode, 'local.more.edit_metadata'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.localMetadataEdit, extra: song);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLocalSong(
    BuildContext context,
    LocalSong song,
    String localeCode,
    WidgetRef ref,
  ) async {
    await shareLocalSongIfAvailable(
      song: song,
      fileExists: _localFileExists,
      shareSong: ref.read(localSongFileShareProvider),
      onMissing: () {
        if (!mounted) {
          return;
        }
        AppMessageService.showWarning(
          AppI18n.tByLocaleCode(localeCode, 'local.share.missing'),
        );
      },
    );
  }

  Future<bool> _localFileExists(String path) async {
    try {
      return await File(path).exists();
    } on FileSystemException {
      return false;
    }
  }
}

class _LocalLibraryAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const _LocalLibraryAppBar({
    required this.state,
    required this.controller,
    required this.localeCode,
    required this.isSearching,
    required this.searchController,
    required this.onCloseSearch,
    required this.onClearSearch,
    required this.onShowClearDialog,
  });

  final AsyncValue<List<LocalSong>> state;
  final LocalLibraryController controller;
  final String localeCode;
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onCloseSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onShowClearDialog;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(localLibrarySelectionProvider);
    if (selection.isMultiSelectMode) {
      final songs = state.asData?.value ?? const <LocalSong>[];
      final selectedCount = selection.selectedSongIds.length;
      final allSelected = songs.isNotEmpty && selectedCount == songs.length;
      return AppBar(
        leading: IconButton(
          onPressed: ref
              .read(localLibrarySelectionProvider.notifier)
              .exitMultiSelect,
          icon: const AppSkinIcon(role: AppSkinIconRole.close),
          tooltip: AppI18n.tByLocaleCode(localeCode, 'common.cancel'),
        ),
        title: Text('$selectedCount'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref
                .read(localLibrarySelectionProvider.notifier)
                .selectAll(songs),
            icon: AppSkinIcon(
              role: allSelected
                  ? AppSkinIconRole.batchDeselectAll
                  : AppSkinIconRole.batchSelectAll,
            ),
            tooltip: AppI18n.tByLocaleCode(
              localeCode,
              allSelected ? 'local.select.deselect_all' : 'local.select.all',
            ),
          ),
        ],
      );
    }
    if (isSearching) {
      return AppBar(
        leading: AppBackButton(onPressed: onCloseSearch),
        title: TextField(
          controller: searchController,
          onChanged: controller.updateSearchQuery,
          decoration: InputDecoration(
            hintText: AppI18n.tByLocaleCode(localeCode, 'local.search_hint'),
            border: InputBorder.none,
          ),
        ),
        actions: <Widget>[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: onClearSearch,
                icon: const AppSkinIcon(role: AppSkinIconRole.close),
                tooltip: AppI18n.tByLocaleCode(localeCode, 'common.clear'),
              );
            },
          ),
        ],
      );
    }
    return AppBar(
      leading: const AppBackButton(),
      title: Text(AppI18n.tByLocaleCode(localeCode, 'local.title')),
      actions: <Widget>[
        IconButton(
          onPressed: controller.toggleSearch,
          tooltip: AppI18n.tByLocaleCode(localeCode, 'common.search'),
          icon: const AppSkinIcon(role: AppSkinIconRole.search),
        ),
        IconButton(
          onPressed: controller.scanLibrary,
          tooltip: AppI18n.tByLocaleCode(localeCode, 'common.scan'),
          icon: const AppSkinIcon(role: AppSkinIconRole.localLibraryScan),
        ),
        IconButton(
          onPressed: onShowClearDialog,
          tooltip: AppI18n.tByLocaleCode(localeCode, 'common.clear'),
          icon: const AppSkinIcon(role: AppSkinIconRole.localLibraryClear),
        ),
      ],
    );
  }
}

class _LocalLibrarySelectionBottomBar extends ConsumerWidget {
  const _LocalLibrarySelectionBottomBar({
    required this.songs,
    required this.localeCode,
    required this.onPlay,
    required this.onAddToQueue,
  });

  final List<LocalSong> songs;
  final String localeCode;
  final Future<void> Function(List<LocalSong> songs) onPlay;
  final ValueChanged<List<LocalSong>> onAddToQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(localLibrarySelectionProvider);
    if (!selection.isMultiSelectMode) {
      return const SizedBox.shrink();
    }
    final selectedSongs = songs
        .where((song) => selection.selectedSongIds.contains(song.id))
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _SelectionActionButton(
              iconRole: AppSkinIconRole.batchPlay,
              label: AppI18n.tByLocaleCode(localeCode, 'local.select.play'),
              onTap: selectedSongs.isEmpty
                  ? null
                  : () => unawaited(onPlay(selectedSongs)),
            ),
            _SelectionActionButton(
              iconRole: AppSkinIconRole.batchAddToQueue,
              label: AppI18n.tByLocaleCode(
                localeCode,
                'local.select.add_to_queue',
              ),
              onTap: selectedSongs.isEmpty
                  ? null
                  : () => onAddToQueue(selectedSongs),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({
    required this.songs,
    required this.view,
    required this.onScan,
    required this.onClear,
    required this.localeCode,
    required this.sortBy,
    required this.sortAscending,
    required this.artistGroups,
    required this.albumGroups,
    required this.genreGroups,
    required this.loadingMore,
    required this.hasMore,
    required this.loadMoreErrorMessage,
    required this.onViewChanged,
    required this.onPlayTap,
    required this.onPlayGroupTap,
    required this.onMoreTap,
    required this.onSortChanged,
    required this.onLoadMore,
    required this.onLongPress,
    required this.onSelectionToggle,
  });

  final List<LocalSong> songs;
  final _LocalLibraryView view;
  final Future<void> Function() onScan;
  final Future<void> Function() onClear;
  final String localeCode;
  final SongSortBy sortBy;
  final bool sortAscending;
  final List<ArtistGroup> artistGroups;
  final List<AlbumGroup> albumGroups;
  final List<GenreGroup> genreGroups;
  final bool loadingMore;
  final bool hasMore;
  final String? loadMoreErrorMessage;
  final ValueChanged<_LocalLibraryView> onViewChanged;
  final ValueChanged<int> onPlayTap;
  final void Function(List<LocalSong> songs, int index) onPlayGroupTap;
  final void Function(LocalSong song) onMoreTap;
  final ValueChanged<SongSortBy> onSortChanged;
  final Future<void> Function() onLoadMore;
  final void Function(String songId) onLongPress;
  final void Function(String songId) onSelectionToggle;

  @override
  Widget build(BuildContext context) {
    // macOS 上即使没有歌曲也显示标签页，方便用户管理扫描文件夹
    if (songs.isEmpty && !Platform.isMacOS) {
      return _EmptyLibrary(onScan: onScan, localeCode: localeCode);
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      UnderlineTab(
                        label: AppI18n.tByLocaleCode(
                          localeCode,
                          'local.tab.songs',
                        ),
                        selected: view == _LocalLibraryView.songs,
                        enabled: true,
                        onTap: () => onViewChanged(_LocalLibraryView.songs),
                      ),
                      UnderlineTab(
                        label: AppI18n.tByLocaleCode(
                          localeCode,
                          'local.tab.artists',
                        ),
                        selected: view == _LocalLibraryView.artists,
                        enabled: true,
                        onTap: () => onViewChanged(_LocalLibraryView.artists),
                      ),
                      UnderlineTab(
                        label: AppI18n.tByLocaleCode(
                          localeCode,
                          'local.tab.albums',
                        ),
                        selected: view == _LocalLibraryView.albums,
                        enabled: true,
                        onTap: () => onViewChanged(_LocalLibraryView.albums),
                      ),
                      UnderlineTab(
                        label: AppI18n.tByLocaleCode(
                          localeCode,
                          'local.tab.genres',
                        ),
                        selected: view == _LocalLibraryView.genres,
                        enabled: true,
                        onTap: () => onViewChanged(_LocalLibraryView.genres),
                      ),
                      if (Platform.isMacOS)
                        UnderlineTab(
                          label: AppI18n.tByLocaleCode(
                            localeCode,
                            'local.tab.folders',
                          ),
                          selected: view == _LocalLibraryView.folders,
                          enabled: true,
                          onTap: () => onViewChanged(_LocalLibraryView.folders),
                        ),
                    ],
                  ),
                ),
              ),
              Visibility(
                visible: view == _LocalLibraryView.songs,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _buildSortButton(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (view) {
            _LocalLibraryView.songs => _buildSongList(),
            _LocalLibraryView.artists => _buildArtistGroupList(
              context,
              groups: artistGroups,
            ),
            _LocalLibraryView.albums => _buildAlbumGroupList(
              context,
              groups: albumGroups,
            ),
            _LocalLibraryView.genres => _buildGenreGroupList(
              context,
              groups: genreGroups,
            ),
            _LocalLibraryView.folders => _FolderManagerView(
              localeCode: localeCode,
            ),
          },
        ),
      ],
    );
  }

  Widget _buildSortButton(BuildContext context) {
    return PopupMenuButton<SongSortBy>(
      icon: Icon(
        sortAscending
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        size: 20,
      ),
      onSelected: onSortChanged,
      itemBuilder: (context) => SongSortBy.values
          .map(
            (sort) => PopupMenuItem(
              value: sort,
              child: Row(
                children: <Widget>[
                  if (sortBy == sort)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(sort.label),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSongList() {
    return SongListComponent(
      itemCount: songs.length,
      loadingMore: loadingMore,
      hasMore: hasMore,
      onLoadMore: onLoadMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      onRetryLoadMore: onLoadMore,
      // macOS 上歌曲为空时显示扫描按钮
      empty: Platform.isMacOS && songs.isEmpty
          ? _EmptyLibrary(onScan: onScan, localeCode: localeCode)
          : null,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _LocalSongRow(
          song: song,
          localeCode: localeCode,
          onLongPress: () => onLongPress(song.id),
          onPlayTap: () => onPlayTap(index),
          onMoreTap: () => onMoreTap(song),
          onSelectionToggle: () => onSelectionToggle(song.id),
        );
      },
    );
  }

  Widget _buildArtistGroupList(
    BuildContext context, {
    required List<ArtistGroup> groups,
  }) {
    if (groups.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'local.empty.artist')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _GroupListItem(
          title: group.name,
          subtitle: AppI18n.formatByLocaleCode(
            localeCode,
            'local.group.artist_subtitle',
            {'songs': '${group.songCount}', 'albums': '${group.albumCount}'},
          ),
          icon: Icons.person_rounded,
          onTap: () => context.push(
            '${AppRoutes.artistDetail}?platform=local'
            '&id=${Uri.encodeComponent(group.name)}'
            '&title=${Uri.encodeComponent(group.name)}',
          ),
        );
      },
    );
  }

  Widget _buildAlbumGroupList(
    BuildContext context, {
    required List<AlbumGroup> groups,
  }) {
    if (groups.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'local.empty.album')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _GroupListItem(
          title: group.name,
          subtitle: AppI18n.formatByLocaleCode(
            localeCode,
            'local.group.album_subtitle',
            {'songs': '${group.songCount}', 'artists': group.artist},
          ),
          icon: Icons.album_rounded,
          artworkPath: group.artworkPath,
          onTap: () => context.push(
            '${AppRoutes.albumDetail}?platform=local'
            '&id=${Uri.encodeComponent(group.name)}'
            '&title=${Uri.encodeComponent(group.name)}',
          ),
        );
      },
    );
  }

  Widget _buildGenreGroupList(
    BuildContext context, {
    required List<GenreGroup> groups,
  }) {
    if (groups.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'local.empty.genre')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _GroupListItem(
          title: group.name,
          subtitle: AppI18n.formatByLocaleCode(
            localeCode,
            'local.group.genre_subtitle',
            {'songs': '${group.songCount}'},
          ),
          icon: Icons.category_rounded,
          onTap: () => context.push(
            '${AppRoutes.localGenre}?name=${Uri.encodeComponent(group.name)}',
          ),
        );
      },
    );
  }
}

class _LocalSongRow extends ConsumerWidget {
  const _LocalSongRow({
    required this.song,
    required this.localeCode,
    required this.onLongPress,
    required this.onPlayTap,
    required this.onMoreTap,
    required this.onSelectionToggle,
  });

  final LocalSong song;
  final String localeCode;
  final VoidCallback onLongPress;
  final VoidCallback onPlayTap;
  final VoidCallback onMoreTap;
  final VoidCallback onSelectionToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      localLibrarySelectionProvider.select(
        (state) => (
          isMultiSelectMode: state.isMultiSelectMode,
          isSelected: state.selectedSongIds.contains(song.id),
        ),
      ),
    );
    return GestureDetector(
      onLongPress: onLongPress,
      child: SongListItem(
        data: SongListItemData(
          title: song.title,
          artistAlbumText: '${song.artist} - ${song.album}',
          subtitleText: song.filePath,
          coverBytes: song.artworkBytes,
          tags: <String>[
            AppI18n.tByLocaleCode(localeCode, 'local.tag.local'),
            if (song.formatLabel.isNotEmpty) song.formatLabel,
          ],
        ),
        selectable: selection.isMultiSelectMode,
        selected: selection.isSelected,
        onTap: selection.isMultiSelectMode ? onSelectionToggle : onPlayTap,
        onSelectTap: onSelectionToggle,
        onMoreTap: selection.isMultiSelectMode ? null : onMoreTap,
      ),
    );
  }
}

class _GroupListItem extends StatelessWidget {
  const _GroupListItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.artworkPath,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// 用于加载专辑封面的歌曲文件路径（原始音频路径）
  final String? artworkPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerHigh,
            ),
            clipBehavior: Clip.antiAlias,
            child: artworkPath != null
                ? _AlbumCover(artworkPath: artworkPath!)
                : Icon(icon, size: 22),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      );
    }
    return child;
  }
}

/// 异步加载专辑封面的小部件
///
/// 根据歌曲原始文件路径，从磁盘缓存中读取已提取的封面图片。
class _AlbumCover extends ConsumerStatefulWidget {
  const _AlbumCover({required this.artworkPath});

  /// 歌曲的原始文件路径（用于定位封面缓存）
  final String artworkPath;

  @override
  ConsumerState<_AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends ConsumerState<_AlbumCover> {
  Future<List<int>?>? _future;

  @override
  void initState() {
    super.initState();
    final extractor = ref.read(localArtworkExtractorProvider);
    _future = extractor.getArtworkBytes(widget.artworkPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return const Icon(Icons.album_rounded, size: 22);
        }
        return Image.memory(
          Uint8List.fromList(snapshot.data!),
          fit: BoxFit.cover,
          width: 48,
          height: 48,
          errorBuilder: (_, _, _) => const Icon(Icons.album_rounded, size: 22),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onScan, required this.localeCode});

  final Future<void> Function() onScan;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.library_music_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppI18n.tByLocaleCode(localeCode, 'local.empty'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(AppI18n.tByLocaleCode(localeCode, 'local.scan')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.localeCode,
    required this.onRetry,
  });

  final String message;
  final String localeCode;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppI18n.tByLocaleCode(localeCode, 'local.rescan')),
            ),
          ],
        ),
      ),
    );
  }
}

/// macOS 扫描文件夹管理视图
class _FolderManagerView extends ConsumerStatefulWidget {
  const _FolderManagerView({required this.localeCode});

  final String localeCode;

  @override
  ConsumerState<_FolderManagerView> createState() => _FolderManagerViewState();
}

class _FolderManagerViewState extends ConsumerState<_FolderManagerView> {
  List<ScanFolder> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final dao = ref.read(localMusicDaoProvider);
    final folders = await dao.getScanFolders('macos');
    setState(() {
      _folders = folders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: _folders.isEmpty
              ? Center(
                  child: Text(
                    AppI18n.tByLocaleCode(
                      widget.localeCode,
                      'local.empty.folder',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return _FolderListItem(
                      folder: folder,
                      localeCode: widget.localeCode,
                      onToggle: (enabled) async {
                        final dao = ref.read(localMusicDaoProvider);
                        await dao.toggleScanFolder(
                          'macos',
                          folder.path,
                          enabled,
                        );
                        _loadFolders();
                      },
                      onDelete: () => _confirmDelete(folder),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addFolder,
              icon: const Icon(Icons.create_new_folder_rounded),
              label: Text(
                AppI18n.tByLocaleCode(widget.localeCode, 'local.folder.add'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addFolder() async {
    if (Platform.isMacOS) {
      // macOS：使用原生文件夹选择器（NSOpenPanel）
      try {
        final path = await _getDirectoryPath();
        if (path != null && path.isNotEmpty) {
          final dao = ref.read(localMusicDaoProvider);
          await dao.addScanFolder('macos', path);
          _loadFolders();
        }
      } catch (e) {
        if (mounted) {
          AppMessageService.showError(
            AppI18n.tByLocaleCode(
              widget.localeCode,
              'local.folder.permission_error',
            ),
          );
        }
      }
    } else {
      // 其他平台：文本输入
      final path = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(
              AppI18n.tByLocaleCode(widget.localeCode, 'local.folder.add'),
            ),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '/path/to/music/folder',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppI18n.tByLocaleCode(widget.localeCode, 'common.cancel'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: Text(
                  AppI18n.tByLocaleCode(widget.localeCode, 'common.confirm'),
                ),
              ),
            ],
          );
        },
      );
      if (path != null && path.isNotEmpty) {
        final dao = ref.read(localMusicDaoProvider);
        await dao.addScanFolder('macos', path);
        _loadFolders();
      }
    }
  }

  /// 调用原生目录选择器（macOS 上为 NSOpenPanel）
  Future<String?> _getDirectoryPath() {
    return getDirectoryPath(
      confirmButtonText: AppI18n.tByLocaleCode(
        widget.localeCode,
        'local.folder.add',
      ),
    );
  }

  Future<void> _confirmDelete(ScanFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppI18n.tByLocaleCode(widget.localeCode, 'local.folder.delete'),
        ),
        content: Text(folder.path),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppI18n.tByLocaleCode(widget.localeCode, 'common.cancel'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              AppI18n.tByLocaleCode(widget.localeCode, 'common.confirm'),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final dao = ref.read(localMusicDaoProvider);
      await dao.removeScanFolder('macos', folder.path);
      _loadFolders();
    }
  }
}

class _FolderListItem extends StatelessWidget {
  const _FolderListItem({
    required this.folder,
    required this.localeCode,
    required this.onToggle,
    required this.onDelete,
  });

  final ScanFolder folder;
  final String localeCode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = folder.enabled == 1;
    return ListTile(
      leading: Icon(
        Icons.folder_rounded,
        color: isEnabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        folder.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isEnabled ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(value: isEnabled, onChanged: onToggle),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  const _SelectionActionButton({
    required this.iconRole,
    required this.label,
    this.onTap,
  });

  final AppSkinIconRole iconRole;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: AppSkinIcon(role: iconRole),
      label: Text(label),
    );
  }
}
