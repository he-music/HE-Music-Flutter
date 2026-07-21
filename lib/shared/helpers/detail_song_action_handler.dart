import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_message_service.dart';
import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/router/app_routes.dart';
import '../../core/network/network_error_message.dart';
import '../../features/download/domain/entities/download_task.dart';
import '../../features/download/presentation/providers/download_providers.dart';
import '../../features/download/presentation/widgets/download_quality_sheet.dart';
import '../../features/my/presentation/providers/favorite_song_status_providers.dart';
import '../../features/my/presentation/providers/my_overview_providers.dart';
import '../../features/my/presentation/providers/my_playlist_shelf_providers.dart';
import '../../features/my/presentation/providers/user_playlist_detail_providers.dart';
import '../../features/online/domain/entities/online_platform.dart';
import '../../features/online/presentation/providers/online_providers.dart';
import '../../features/player/domain/entities/player_quality_option.dart';
import '../../features/player/domain/entities/player_queue_source.dart';
import '../../features/player/domain/entities/player_track.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../models/he_music_models.dart';
import '../utils/cover_resolver.dart';
import '../utils/favorite_song_key.dart';
import '../utils/share_link_builder.dart';
import '../widgets/select_user_playlist_sheet.dart';
import '../widgets/song_actions_sheet.dart';
import 'album_id_helper.dart';
import 'platform_label_helper.dart';
import 'song_detail_navigation_helper.dart';
import 'song_artist_navigation_helper.dart';
import 'song_batch_helpers.dart' as batch_helpers;

typedef SongPlatformIdResolver = String Function(SongInfo song);
typedef SongMvNavigationHandler =
    void Function(BuildContext context, SongInfo song, String platformId);
typedef SongFavoriteErrorMessageBuilder = String? Function(Object error);

class DetailSongActionHandler {
  DetailSongActionHandler({
    required this.ref,
    this.queueSource,
    this.platformIdResolver,
    this.onWatchMv,
  });

  final WidgetRef ref;
  final PlayerQueueSource? queueSource;
  final SongPlatformIdResolver? platformIdResolver;
  final SongMvNavigationHandler? onWatchMv;

  String resolvePlatformId(SongInfo song) {
    final resolved = platformIdResolver?.call(song) ?? song.platform;
    return resolved.trim();
  }

  String resolveCoverUrl(SongInfo song) {
    return _resolveCoverUrl(song, size: 300);
  }

  String _resolvePlayerCoverUrl(SongInfo song) {
    return _resolveCoverUrl(song, size: maxCoverSize);
  }

  String _resolveCoverUrl(SongInfo song, {required int size}) {
    final platformId = resolvePlatformId(song);
    if (platformId.isEmpty) {
      return song.cover;
    }
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    return resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: platformId,
      songId: song.id,
      cover: song.cover,
      size: size,
    );
  }

  Future<void> playAll(
    BuildContext context,
    List<SongInfo> songs, {
    int startIndex = 0,
  }) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
      return;
    }
    final playerController = ref.read(playerControllerProvider.notifier);
    try {
      final tracks = songs
          .map(
            (song) =>
                _buildTrack(song: song, platformId: resolvePlatformId(song)),
          )
          .toList(growable: false);
      await playerController.replaceQueue(
        tracks,
        startIndex: startIndex,
        queueSource: queueSource,
      );
    } catch (error) {
      _showErrorMessage(
        AppI18n.format(
          ref.read(appConfigProvider),
          'detail.play_failed',
          <String, String>{'error': '$error'},
        ),
      );
    }
  }

  Future<void> appendAllToQueue(List<SongInfo> songs) async {
    if (songs.isEmpty) {
      return;
    }
    final playerController = ref.read(playerControllerProvider.notifier);
    for (final song in songs) {
      await playerController.appendTrack(
        _buildTrack(song: song, platformId: resolvePlatformId(song)),
      );
    }
  }

  Future<void> playNextSong(SongInfo song) {
    return _insertNext(song, resolvePlatformId(song));
  }

  Future<void> playSongNow(SongInfo song) {
    return _playNow(song, resolvePlatformId(song));
  }

  Future<void> toggleSongFavorite(
    SongInfo song, {
    SongFavoriteErrorMessageBuilder? errorMessageBuilder,
  }) async {
    final platformId = resolvePlatformId(song);
    if (platformId.isEmpty) {
      return;
    }
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: song.id, platform: platformId),
        ),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: platformId,
            like: !liked,
          );
    } catch (error) {
      final message = errorMessageBuilder?.call(error);
      _showErrorMessage(
        message ?? NetworkErrorMessage.resolve(error) ?? '$error',
      );
    }
  }

  List<SongInfo> collectSelectedSongItems(
    List<SongInfo> songs,
    Set<String> selectedSongKeys,
  ) {
    return batch_helpers.collectSelectedSongItems(
      songs,
      selectedSongKeys,
      songIdOf: (song) => song.id,
      platformOf: resolvePlatformId,
    );
  }

  List<IdPlatformInfo> collectSelectedSongs(
    List<SongInfo> songs,
    Set<String> selectedSongKeys,
  ) {
    return batch_helpers.collectSelectedSongIdPlatforms(
      songs,
      selectedSongKeys,
      songIdOf: (song) => song.id,
      platformOf: resolvePlatformId,
    );
  }

  Future<bool> playSelectedSongs(
    BuildContext context, {
    required List<SongInfo> songs,
    required Set<String> selectedSongKeys,
    required bool submittingBatch,
  }) async {
    final selectedSongs = collectSelectedSongItems(songs, selectedSongKeys);
    if (selectedSongs.isEmpty || submittingBatch) {
      return false;
    }
    await playAll(context, selectedSongs);
    return true;
  }

  Future<bool> appendSelectedSongsToQueue(
    BuildContext context, {
    required List<SongInfo> songs,
    required Set<String> selectedSongKeys,
    required bool submittingBatch,
  }) async {
    final selectedSongs = collectSelectedSongItems(songs, selectedSongKeys);
    if (selectedSongs.isEmpty || submittingBatch) {
      return false;
    }
    try {
      await appendAllToQueue(selectedSongs);
      if (!context.mounted) {
        return false;
      }
      AppMessageService.showSuccess(
        AppI18n.t(ref.read(appConfigProvider), 'search.queue.appended'),
      );
      return true;
    } catch (error) {
      _showErrorMessage(NetworkErrorMessage.resolve(error) ?? '$error');
      return false;
    }
  }

  Future<bool> addSelectedSongsToPlaylist(
    BuildContext context, {
    required List<SongInfo> songs,
    required Set<String> selectedSongKeys,
    required bool submittingBatch,
    String? excludedPlaylistId,
  }) async {
    final selectedSongs = collectSelectedSongs(songs, selectedSongKeys);
    if (selectedSongs.isEmpty || submittingBatch) {
      return false;
    }
    final playlist = await showSelectUserPlaylistSheet(
      context,
      excludedPlaylistId: excludedPlaylistId,
    );
    if (playlist == null || !context.mounted) {
      return false;
    }
    try {
      await ref
          .read(userPlaylistDetailRepositoryProvider)
          .addSongs(playlistId: playlist.id, songs: selectedSongs);
      if (playlist.isDefault) {
        final favoriteStatus = ref.read(favoriteSongStatusProvider.notifier);
        for (final song in selectedSongs) {
          favoriteStatus.addSong(songId: song.id, platform: song.platform);
        }
        await ref.read(myOverviewControllerProvider.notifier).refresh();
      }
      ref.invalidate(myCreatedPlaylistsProvider);
      if (!context.mounted) {
        return false;
      }
      AppMessageService.showSuccess(
        AppI18n.t(ref.read(appConfigProvider), 'detail.batch.add_success'),
      );
      return true;
    } catch (error) {
      _showErrorMessage(NetworkErrorMessage.resolve(error) ?? '$error');
      return false;
    }
  }

  /// 从自建歌单中移除选中的歌曲，返回是否成功
  Future<bool> removeSelectedSongsFromPlaylist(
    BuildContext context, {
    required List<SongInfo> songs,
    required Set<String> selectedSongKeys,
    required bool submittingBatch,
    required String playlistId,
    bool isDefaultPlaylist = false,
  }) async {
    final selectedSongs = collectSelectedSongs(songs, selectedSongKeys);
    if (selectedSongs.isEmpty || submittingBatch) {
      return false;
    }
    try {
      await ref
          .read(userPlaylistDetailRepositoryProvider)
          .removeSongs(playlistId: playlistId, songs: selectedSongs);
      if (isDefaultPlaylist) {
        final favoriteStatus = ref.read(favoriteSongStatusProvider.notifier);
        for (final song in selectedSongs) {
          favoriteStatus.removeSong(songId: song.id, platform: song.platform);
        }
        await ref.read(myOverviewControllerProvider.notifier).refresh();
      }
      ref.invalidate(myCreatedPlaylistsProvider);
      if (!context.mounted) {
        return false;
      }
      AppMessageService.showSuccess(
        AppI18n.t(ref.read(appConfigProvider), 'detail.batch.remove_success'),
      );
      return true;
    } catch (error) {
      _showErrorMessage(NetworkErrorMessage.resolve(error) ?? '$error');
      return false;
    }
  }

  void showSongActions({
    required BuildContext context,
    required SongInfo song,
    required String coverUrl,
    String? playActionLabel,
    VoidCallback? onPlay,
    VoidCallback? onRemoveFromPlaylist,
    BuildContext? anchorContext,
    Offset? anchorPosition,
    bool includeViewDetail = true,
    bool forceBottomSheet = false,
    bool useRootNavigator = false,
  }) {
    final platformId = resolvePlatformId(song);
    if (platformId.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'home.platform_not_ready'),
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final albumId = song.album?.id.trim() ?? '';
    final albumTitle = song.album?.name.trim() ?? '';
    final canViewAlbum =
        hasValidAlbumId(albumId) &&
        platformSupportsAlbumDetail(
          platformId: platformId,
          platforms: platforms,
        );
    final canViewDetail = canOpenSongDetail(
      songId: song.id,
      platformId: platformId,
      platforms: platforms,
    );
    final artistActionLabel =
        platformSupportsArtistDetail(
          platformId: platformId,
          platforms: platforms,
        )
        ? songArtistActionLabel(song.artists, localeCode: config.localeCode)
        : null;
    final canViewComment = platformSupportsSongComment(
      platformId: platformId,
      platforms: platforms,
    );
    final availableQualities = _resolveDownloadQualities(
      song: song,
      platforms: platforms,
      platformId: platformId,
    );
    showSongActionsSheet(
      context: context,
      anchorContext: anchorContext,
      anchorPosition: anchorPosition,
      forceBottomSheet: forceBottomSheet,
      useRootNavigator: useRootNavigator,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      title: song.title,
      subtitle: song.artist,
      hasMv: onWatchMv != null && song.hasMv,
      playActionLabel: playActionLabel,
      sourceLabel: AppI18n.format(config, 'song.source', <String, String>{
        'platform': resolvePlatformLabel(platformId, platforms: platforms),
      }),
      onPlay: onPlay ?? () => unawaited(playSongNow(song)),
      onPlayNext: () => unawaited(_insertNext(song, platformId)),
      onAddToPlaylist: () => unawaited(_appendToQueue(song, platformId)),
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      onDownload:
          _canDownload(platformId: platformId, qualities: availableQualities)
          ? () => unawaited(
              _downloadSong(
                context: context,
                song: song,
                platformId: platformId,
                artworkUrl: coverUrl.isEmpty ? null : coverUrl,
                qualities: availableQualities,
              ),
            )
          : null,
      onWatchMv: () {
        if (onWatchMv != null) {
          onWatchMv!.call(context, song, platformId);
        }
      },
      onViewDetail: includeViewDetail && canViewDetail
          ? () => openSongDetailPage(
              context: context,
              songId: song.id,
              platformId: platformId,
              title: song.title,
            )
          : null,
      onViewComment: canViewComment
          ? () => _openSongComments(
              context: context,
              songId: song.id,
              platformId: platformId,
              title: song.title,
            )
          : null,
      albumActionLabel: canViewAlbum
          ? AppI18n.t(config, 'player.action.view_album')
          : null,
      onViewAlbum: canViewAlbum
          ? () => _openAlbumDetail(
              context: context,
              albumId: albumId,
              platformId: platformId,
              albumTitle: albumTitle,
            )
          : null,
      artistActionLabel: artistActionLabel,
      onViewArtists: artistActionLabel == null
          ? null
          : () => unawaited(
              openSongArtistSelection(
                context: context,
                platformId: platformId,
                artists: song.artists,
                onError: AppMessageService.showWarning,
              ),
            ),
      onCopySongName: () => unawaited(
        _copyText(
          context: context,
          value: song.title,
          success: AppI18n.t(config, 'player.copy.name_done'),
        ),
      ),
      onCopySongShareLink: () => unawaited(
        _copyText(
          context: context,
          value: buildShareLink(
            type: 'song',
            platform: platformId,
            id: song.id,
          ),
          success: AppI18n.t(config, 'player.copy.share_done'),
        ),
      ),
      onSearchSameName: () => _openSongSearch(
        context: context,
        platformId: platformId,
        keyword: song.title,
      ),
      onCopySongId: () => unawaited(
        _copyText(
          context: context,
          value: song.id,
          success: AppI18n.t(config, 'player.copy.id_done'),
        ),
      ),
    );
  }

  PlayerTrack _buildTrack({
    required SongInfo song,
    required String platformId,
  }) {
    final coverUrl = _resolvePlayerCoverUrl(song);
    return PlayerTrack(
      id: song.id,
      title: song.title,
      links: song.links,
      artist: song.artist,
      albumId: song.album?.id,
      album: song.album?.name,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: coverUrl.isEmpty ? null : coverUrl,
      platform: platformId,
    );
  }

  Future<void> _playNow(SongInfo song, String platformId) async {
    await ref
        .read(playerControllerProvider.notifier)
        .insertNextAndPlay(_buildTrack(song: song, platformId: platformId));
  }

  Future<void> _insertNext(SongInfo song, String platformId) async {
    await ref
        .read(playerControllerProvider.notifier)
        .insertNextTrack(_buildTrack(song: song, platformId: platformId));
  }

  Future<void> _appendToQueue(SongInfo song, String platformId) async {
    await ref
        .read(playerControllerProvider.notifier)
        .appendTrack(_buildTrack(song: song, platformId: platformId));
  }

  Future<void> _downloadSong({
    required BuildContext context,
    required SongInfo song,
    required String platformId,
    required String? artworkUrl,
    required List<PlayerQualityOption> qualities,
  }) async {
    final config = ref.read(appConfigProvider);
    final selected = await showDownloadQualitySheet(
      context: context,
      qualities: qualities,
      selectedQualityName: qualities.isEmpty ? null : qualities.first.name,
    );
    if (selected == null) {
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: song.title,
            quality: DownloadTaskQuality(
              label: selected.name,
              bitrate: selected.quality.toDouble(),
              fileExtension: selected.format.trim().toLowerCase(),
            ),
            songId: song.id,
            platform: platformId,
            artist: song.artist,
            album: song.album?.name,
            artworkUrl: artworkUrl,
          );
      if (!context.mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.format(config, 'player.download.added', <String, String>{
          'title': song.title,
        }),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      AppMessageService.showError(AppI18n.t(config, 'player.download.failed'));
    }
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

  bool _canDownload({
    required String platformId,
    required List<PlayerQualityOption> qualities,
  }) {
    final normalized = platformId.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != 'local' &&
        qualities.isNotEmpty;
  }

  List<PlayerQualityOption> _resolveDownloadQualities({
    required SongInfo song,
    required List<OnlinePlatform> platforms,
    required String platformId,
  }) {
    return buildDownloadQualityOptions(
      links: song.links,
      qualityDescriptions: _platformQualityDescriptions(
        platforms: platforms,
        platformId: platformId,
      ),
    );
  }

  Map<String, String> _platformQualityDescriptions({
    required List<OnlinePlatform> platforms,
    required String platformId,
  }) {
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  void _openSongComments({
    required BuildContext context,
    required String songId,
    required String platformId,
    required String title,
  }) {
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    if (!platformSupportsSongComment(
      platformId: platformId,
      platforms: platforms,
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

  void _openAlbumDetail({
    required BuildContext context,
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final uri = Uri(
      path: AppRoutes.albumDetail,
      queryParameters: <String, String>{
        'id': albumId,
        'platform': platformId,
        'title': albumTitle.isEmpty
            ? AppI18n.t(ref.read(appConfigProvider), 'album.fallback_title')
            : albumTitle,
      },
    );
    context.push(uri.toString());
  }

  Future<void> _copyText({
    required BuildContext context,
    required String value,
    required String success,
  }) async {
    final text = value.trim();
    if (text.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'search.copy_empty'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    AppMessageService.showSuccess(success);
  }

  void _showErrorMessage(String message) {
    AppMessageService.showError(message);
  }
}
