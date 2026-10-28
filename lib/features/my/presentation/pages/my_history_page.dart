import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/image/local_artwork_bytes_provider.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/utils/share_link_builder.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/domain/entities/player_history_item.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/scroll_to_top_overlay.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../providers/favorite_song_status_providers.dart';
import '../providers/my_history_providers.dart';

class MyHistoryPage extends ConsumerWidget {
  const MyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appConfigProvider.select((config) => config.localeCode));
    final config = ref.read(appConfigProvider);
    final state = ref.watch(myHistoryControllerProvider);
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'my.history')),
          actions: <Widget>[
            IconButton(
              onPressed: state.value?.isNotEmpty == true
                  ? () => _clearHistory(context, ref)
                  : null,
              tooltip: AppI18n.t(config, 'my.history.clear'),
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: state.when(
                data: (items) => _HistoryList(
                  items: items,
                  emptyText: AppI18n.t(config, 'my.history.empty'),
                  onTap: (index) => _playHistory(context, ref, items, index),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _HistoryErrorView(
                  message: '$error',
                  retryLabel: AppI18n.t(config, 'my.retry'),
                  onRetry: () =>
                      ref.read(myHistoryControllerProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider);
    final confirmed = await confirmAppAction(
      context,
      title: AppI18n.t(config, 'my.history.clear'),
      message: AppI18n.t(config, 'my.history.clear_confirm'),
      confirmLabel: AppI18n.t(config, 'my.history.clear'),
    );
    if (confirmed && context.mounted) {
      await ref.read(myHistoryControllerProvider.notifier).clear();
    }
  }

  Future<void> _playHistory(
    BuildContext context,
    WidgetRef ref,
    List<PlayerHistoryItem> items,
    int startIndex,
  ) async {
    if (startIndex < 0 || startIndex >= items.length) {
      return;
    }
    await ref
        .read(playerControllerProvider.notifier)
        .playHistoryItem(items[startIndex]);
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList({
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  final List<PlayerHistoryItem> items;
  final String emptyText;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  final _scrollController = ScrollController();

  List<PlayerHistoryItem> get items => widget.items;
  String get emptyText => widget.emptyText;
  ValueChanged<int> get onTap => widget.onTap;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    if (items.isEmpty) return Center(child: Text(emptyText));
    return Column(
      children: <Widget>[
        MusicDetailPlayAllHeaderBox(
          countText: AppI18n.formatByLocaleCode(
            localeCode,
            'detail.play_all_count',
            {'count': '${items.length}'},
          ),
          onPlayAll: () => unawaited(
            ref
                .read(playerControllerProvider.notifier)
                .replaceQueue(
                  items.map(_toTrack).toList(growable: false),
                  queueSource: PlayerQueueSource(
                    routePath: AppRoutes.myHistory,
                    queryParameters: const <String, String>{},
                    title: AppI18n.tByLocaleCode(localeCode, 'my.history'),
                  ),
                ),
          ),
        ),
        Expanded(child: _buildSongs(ref, localeCode)),
      ],
    );
  }

  Widget _buildSongs(WidgetRef ref, String localeCode) {
    return ScrollToTopOverlay(
      controller: _scrollController,
      child: SongListComponent(
        itemCount: items.length,
        controller: _scrollController,
        enablePaging: false,
        itemBuilder: (context, index) {
          final item = items[index];
          return Consumer(
            key: ValueKey((item.id, item.platform, item.playedAt)),
            builder: (context, ref, child) {
              final song = _toSongInfo(item);
              final coverUrl = _cover(item.artworkUrl);
              final songId = item.id.trim();
              final platform = item.platform?.trim() ?? '';
              final canToggleFavorite =
                  songId.isNotEmpty &&
                  platform.isNotEmpty &&
                  platform.toLowerCase() != 'local';
              final isLiked =
                  canToggleFavorite &&
                  ref.watch(
                    favoriteSongStatusProvider.select(
                      (state) => state.songKeys.contains(
                        buildFavoriteSongKey(
                          songId: songId,
                          platform: platform,
                        ),
                      ),
                    ),
                  );
              final isCurrent = ref.watch(
                playerControllerProvider.select(
                  (state) => isCurrentSongIdentity(
                    currentTrackIdentityOf(state.displayTrack),
                    song,
                  ),
                ),
              );
              final artwork = ref
                  .watch(localArtworkBytesProvider(item.artworkPath ?? ''))
                  .value;
              return OnlineSongListItem(
                song: song,
                coverUrl: coverUrl,
                coverBytes: artwork,
                subtitleText: _playedText(item.playedAt, localeCode),
                isCurrent: isCurrent,
                isLiked: isLiked,
                onTap: () => onTap(index),
                onLikeTap: canToggleFavorite
                    ? () => _toggleSongLike(
                        ref: ref,
                        songId: songId,
                        platform: platform,
                        liked: isLiked,
                      )
                    : null,
                onMoreTap: () => _showSongActions(
                  context: context,
                  ref: ref,
                  config: ref.read(appConfigProvider),
                  platforms:
                      ref.read(onlinePlatformsProvider).value ?? const [],
                  item: item,
                  song: song,
                  coverUrl: coverUrl,
                ),
              );
            },
          );
        },
      ),
    );
  }

  SongInfo _toSongInfo(PlayerHistoryItem item) {
    final artistNames = item.artist
        .split(RegExp(r'\s*/\s*'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != '-')
        .toList(growable: false);
    return SongInfo(
      name: item.title.isEmpty ? item.id : item.title,
      subtitle: '',
      id: item.id,
      duration: item.duration ?? 0,
      mvId: '',
      album: item.album.trim().isEmpty
          ? null
          : SongInfoAlbumInfo(name: item.album.trim(), id: ''),
      artists: artistNames
          .map((name) => SongInfoArtistInfo(id: '', name: name))
          .toList(growable: false),
      links: const <LinkInfo>[],
      platform: item.platform?.trim() ?? '',
      cover: item.artworkUrl,
      path: null,
      size: null,
      quality: null,
      alias: null,
    );
  }

  String? _cover(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return null;
  }

  String _playedText(int playedAt, String localeCode) {
    final safe = playedAt > 10000000000 ? playedAt : playedAt * 1000;
    final time = DateTime.fromMillisecondsSinceEpoch(safe);
    final label =
        '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return AppI18n.formatByLocaleCode(localeCode, 'my.history.played_at', {
      'time': label,
    });
  }

  Future<void> _showSongActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppConfigState config,
    required List<OnlinePlatform> platforms,
    required PlayerHistoryItem item,
    required SongInfo song,
    required String? coverUrl,
  }) {
    final platform = item.platform?.trim() ?? '';
    final isOnline = platform.isNotEmpty && platform.toLowerCase() != 'local';
    final platformLabel = resolvePlatformLabel(platform, platforms: platforms);
    final canViewComment =
        isOnline &&
        platformSupportsSongComment(platformId: platform, platforms: platforms);
    return showSongActionsSheet(
      context: context,
      coverUrl: coverUrl,
      title: song.title,
      subtitle: song.artist,
      duration: (item.duration ?? 0) > 0
          ? Duration(seconds: item.duration!)
          : null,
      hasMv: false,
      sourceLabel: AppI18n.format(config, 'song.source', <String, String>{
        'platform': platformLabel.isEmpty ? '-' : platformLabel,
      }),
      onPlay: () => unawaited(_playNow(ref: ref, item: item)),
      onPlayNext: () => unawaited(_insertNext(ref: ref, item: item)),
      onAddToPlaylist: () => unawaited(_appendToQueue(ref: ref, item: item)),
      onWatchMv: () {},
      onViewDetail:
          canOpenSongDetail(
            songId: item.id,
            platformId: platform,
            platforms: platforms,
          )
          ? () => openSongDetailPage(
              context: context,
              songId: item.id,
              platformId: platform,
              title: song.title,
            )
          : null,
      onViewComment: canViewComment
          ? () => _openSongComments(
              context: context,
              ref: ref,
              songId: item.id,
              platformId: platform,
              title: song.title,
            )
          : null,
      onViewSheetMusic:
          canListSongSheetMusic(
            songId: item.id,
            platformId: platform,
            platforms: platforms,
          )
          ? () => openSongSheetMusicPage(
              context: context,
              songId: item.id,
              platformId: platform,
              title: song.title,
            )
          : null,
      onCopySongName: () => unawaited(
        _copyText(
          context: context,
          value: song.title,
          success: AppI18n.t(config, 'player.copy.name_done'),
        ),
      ),
      onCopySongShareLink: isOnline
          ? () => unawaited(
              _copyText(
                context: context,
                value: buildShareLink(
                  type: 'song',
                  platform: platform,
                  id: item.id,
                ),
                success: AppI18n.t(config, 'player.copy.share_done'),
              ),
            )
          : null,
      onSearchSameName: isOnline
          ? () => _openSongSearch(
              context: context,
              platformId: platform,
              keyword: song.title,
            )
          : null,
      onCopySongId: () => unawaited(
        _copyText(
          context: context,
          value: item.id,
          success: AppI18n.t(config, 'player.copy.id_done'),
        ),
      ),
    );
  }

  Future<void> _playNow({
    required WidgetRef ref,
    required PlayerHistoryItem item,
  }) async {
    await ref.read(playerControllerProvider.notifier).playHistoryItem(item);
  }

  Future<void> _insertNext({
    required WidgetRef ref,
    required PlayerHistoryItem item,
  }) async {
    await ref
        .read(playerControllerProvider.notifier)
        .insertNextTrack(_toTrack(item));
  }

  Future<void> _appendToQueue({
    required WidgetRef ref,
    required PlayerHistoryItem item,
  }) async {
    await ref
        .read(playerControllerProvider.notifier)
        .appendTrack(_toTrack(item));
  }

  Future<void> _copyText({
    required BuildContext context,
    required String value,
    required String success,
  }) async {
    final text = value.trim();
    if (text.isEmpty) {
      final localeCode = Localizations.localeOf(context).languageCode;
      AppMessageService.showWarning(
        AppI18n.tByLocaleCode(localeCode, 'search.copy_empty'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    AppMessageService.showSuccess(success);
  }

  void _openSongSearch({
    required BuildContext context,
    required String platformId,
    required String keyword,
  }) {
    final uri = Uri(
      path: AppRoutes.onlineSearch,
      queryParameters: <String, String>{
        'platform': platformId,
        'keyword': keyword,
      },
    );
    context.push(uri.toString());
  }

  void _openSongComments({
    required BuildContext context,
    required WidgetRef ref,
    required String songId,
    required String platformId,
    required String title,
  }) {
    if (!_platformSupports(
      ref: ref,
      platformId: platformId,
      featureFlag: PlatformFeatureSupportFlag.getCommentList,
    )) {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'search.comment_unsupported'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineComments,
      queryParameters: <String, String>{
        'id': songId,
        'resource_type': 'song',
        'platform': platformId,
        'title': title,
      },
    );
    context.push(uri.toString());
  }

  bool _platformSupports({
    required WidgetRef ref,
    required String platformId,
    required BigInt featureFlag,
  }) {
    final normalized = platformId.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'local') {
      return false;
    }
    final all = ref.read(onlinePlatformsProvider).value;
    if (all == null) {
      return true;
    }
    for (final platform in all) {
      if (platform.id != normalized) {
        continue;
      }
      return platform.available && platform.supports(featureFlag);
    }
    return false;
  }

  PlayerTrack _toTrack(PlayerHistoryItem item) {
    final platform = item.platform?.trim() ?? '';
    return PlayerTrack(
      id: item.id,
      title: item.title.isEmpty ? item.id : item.title,
      artist: item.artist,
      album: item.album.isEmpty ? null : item.album,
      albumId: item.albumId,
      artists: item.artists,
      url: platform.toLowerCase() == 'local' ? item.url : '',
      path: item.playbackPath,
      artworkUrl: item.artworkUrl.isEmpty ? null : item.artworkUrl,
      platform: platform.isEmpty ? null : platform,
      duration: (item.duration ?? 0) > 0
          ? Duration(seconds: item.duration!)
          : null,
    );
  }

  Future<void> _toggleSongLike({
    required WidgetRef ref,
    required String songId,
    required String platform,
    required bool liked,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(songId: songId, platform: platform, like: !liked);
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ?? '收藏操作失败，请稍后重试',
      );
    }
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
