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
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
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
  Widget build(BuildContext context) {
    final state = ref.watch(localLibraryControllerProvider);
    final controller = ref.read(localLibraryControllerProvider.notifier);
    final config = ref.watch(appConfigProvider);
    final isSearching = controller.searchState.isActive;
    final isMultiSelect = controller.isMultiSelectMode;
    return Scaffold(
      appBar: isMultiSelect
          ? _buildSelectionAppBar(context, controller, config, state)
          : isSearching
          ? _buildSearchAppBar(context, controller, config)
          : _buildNormalAppBar(controller, config),
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
                localeCode: config.localeCode,
                sortBy: controller.sortBy,
                sortAscending: controller.sortAscending,
                artistGroups: controller.artistGroups,
                albumGroups: controller.albumGroups,
                genreGroups: controller.genreGroups,
                onViewChanged: (view) => setState(() => _view = view),
                onPlayTap: (index) =>
                    _playLocalSong(context, ref, songs, index),
                onPlayGroupTap: (groupSongs, index) =>
                    _playLocalSong(context, ref, groupSongs, index),
                onMoreTap: (song) =>
                    _showMoreActionsSheet(context, song, config, ref),
                onSortChanged: controller.changeSortBy,
                isMultiSelectMode: controller.isMultiSelectMode,
                selectedSongIds: controller.selectedSongIds,
                onLongPress: controller.enterMultiSelect,
                onSelectionToggle: controller.toggleSelection,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorView(
                message: '$error',
                localeCode: config.localeCode,
                onRetry: controller.scanLibrary,
              ),
            ),
          ),
          // 多选模式底部操作栏
          if (isMultiSelect) _buildSelectionBottomBar(config, ref, state),
        ],
      ),
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
      platform: 'local',
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    LocalLibraryController controller,
    AppConfigState config,
  ) {
    return AppBar(
      leading: const AppBackButton(),
      title: Text(AppI18n.t(config, 'local.title')),
      actions: <Widget>[
        IconButton(
          onPressed: controller.toggleSearch,
          tooltip: AppI18n.t(config, 'common.search'),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: controller.scanLibrary,
          tooltip: AppI18n.t(config, 'common.scan'),
          icon: const Icon(Icons.folder_open_rounded),
        ),
        IconButton(
          onPressed: () => _showClearDialog(context, controller, config),
          tooltip: AppI18n.t(config, 'common.clear'),
          icon: const Icon(Icons.clear_all_rounded),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    LocalLibraryController controller,
    AppConfigState config,
    AsyncValue<List<LocalSong>> state,
  ) {
    final selectedCount = controller.selectedSongIds.length;
    final songs = state.asData?.value ?? [];
    final allSelected = songs.isNotEmpty && selectedCount == songs.length;
    return AppBar(
      leading: IconButton(
        onPressed: controller.exitMultiSelect,
        icon: const Icon(Icons.close_rounded),
        tooltip: AppI18n.t(config, 'common.cancel'),
      ),
      title: Text('$selectedCount'),
      actions: <Widget>[
        IconButton(
          onPressed: () => controller.selectAll(songs),
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          tooltip: allSelected
              ? AppI18n.t(config, 'local.select.deselect_all')
              : AppI18n.t(config, 'local.select.all'),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(
    BuildContext context,
    LocalLibraryController controller,
    AppConfigState config,
  ) {
    return AppBar(
      leading: AppBackButton(onPressed: controller.toggleSearch),
      title: TextField(
        autofocus: true,
        onChanged: controller.updateSearchQuery,
        decoration: InputDecoration(
          hintText: AppI18n.t(config, 'local.search_hint'),
          border: InputBorder.none,
        ),
      ),
      actions: <Widget>[
        if (controller.searchState.query.isNotEmpty)
          IconButton(
            onPressed: () => controller.updateSearchQuery(''),
            icon: const Icon(Icons.close_rounded),
            tooltip: AppI18n.t(config, 'common.clear'),
          ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(
    AppConfigState config,
    WidgetRef ref,
    AsyncValue<List<LocalSong>> state,
  ) {
    final songs = state.asData?.value ?? [];
    final selectedSongs = songs
        .where(
          (s) => ref
              .read(localLibraryControllerProvider.notifier)
              .selectedSongIds
              .contains(s.id),
        )
        .toList();
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
              icon: Icons.play_arrow_rounded,
              label: AppI18n.t(config, 'local.select.play'),
              onTap: selectedSongs.isEmpty
                  ? null
                  : () {
                      ref
                          .read(localLibraryControllerProvider.notifier)
                          .exitMultiSelect();
                      _playLocalSong(context, ref, selectedSongs, 0);
                    },
            ),
            _SelectionActionButton(
              icon: Icons.queue_music_rounded,
              label: AppI18n.t(config, 'local.select.add_to_queue'),
              onTap: selectedSongs.isEmpty
                  ? null
                  : () {
                      for (final song in selectedSongs) {
                        final track = _toPlayerTrack(song);
                        ref
                            .read(playerControllerProvider.notifier)
                            .appendTrack(track);
                      }
                      ref
                          .read(localLibraryControllerProvider.notifier)
                          .exitMultiSelect();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearDialog(
    BuildContext context,
    LocalLibraryController controller,
    AppConfigState config,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppI18n.t(config, 'local.clear_dialog.title')),
        content: Text(AppI18n.t(config, 'local.clear_dialog.content')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppI18n.t(config, 'local.clear_dialog.confirm')),
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
    AppConfigState config,
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
              title: Text(AppI18n.t(config, 'local.more.play_next')),
              onTap: () {
                Navigator.of(context).pop();
                _playLocalSong(context, ref, [song], 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(AppI18n.t(config, 'local.more.add_to_queue')),
              onTap: () {
                Navigator.of(context).pop();
                final track = _toPlayerTrack(song);
                ref.read(playerControllerProvider.notifier).appendTrack(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(AppI18n.t(config, 'local.more.share')),
              onTap: () async {
                Navigator.of(context).pop();
                await _shareLocalSong(context, song, config, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(AppI18n.t(config, 'local.more.edit_metadata')),
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
    AppConfigState config,
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
        AppMessageService.showWarning(AppI18n.t(config, 'local.share.missing'));
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
    required this.onViewChanged,
    required this.onPlayTap,
    required this.onPlayGroupTap,
    required this.onMoreTap,
    required this.onSortChanged,
    required this.isMultiSelectMode,
    required this.selectedSongIds,
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
  final ValueChanged<_LocalLibraryView> onViewChanged;
  final ValueChanged<int> onPlayTap;
  final void Function(List<LocalSong> songs, int index) onPlayGroupTap;
  final void Function(LocalSong song) onMoreTap;
  final ValueChanged<SongSortBy> onSortChanged;
  final bool isMultiSelectMode;
  final Set<String> selectedSongIds;
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
      enablePaging: false,
      // macOS 上歌曲为空时显示扫描按钮
      empty: Platform.isMacOS && songs.isEmpty
          ? _EmptyLibrary(onScan: onScan, localeCode: localeCode)
          : null,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isSelected = selectedSongIds.contains(song.id);
        return GestureDetector(
          onLongPress: () => onLongPress(song.id),
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
            selectable: isMultiSelectMode,
            selected: isSelected,
            onTap: isMultiSelectMode
                ? () => onSelectionToggle(song.id)
                : () => onPlayTap(index),
            onSelectTap: () => onSelectionToggle(song.id),
            onMoreTap: isMultiSelectMode ? null : () => onMoreTap(song),
          ),
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
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
