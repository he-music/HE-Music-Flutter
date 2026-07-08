import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/helpers/user_playlist_song_action_helper.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/utils/share_link_builder.dart';
import '../../../download/domain/entities/download_task.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../download/presentation/widgets/download_quality_sheet.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/player_quality_option.dart';
import '../../domain/entities/player_track.dart';
import '../controllers/player_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';
import '../widgets/player_backdrop.dart';
import '../widgets/player_control_bar.dart';
import '../widgets/player_info_page.dart';
import '../widgets/player_lyric_page.dart';
import '../widgets/player_more_sheet_widgets.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_queue_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _pageCount = 2;
  static const SystemUiOverlayStyle _playerOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(playerControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      playerControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        final message = next?.trim() ?? '';
        if (message.isEmpty || message == previous?.trim()) {
          return;
        }
        AppMessageService.showError(message);
      },
    );
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final backdropImageProvider = artworkProvider(
      track?.artworkUrl,
      track?.artworkBytes,
    );
    final usePortraitArtistPhoto = resolvePlayerArtistPhotoPortraitForTest(
      MediaQuery.sizeOf(context),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _playerOverlayStyle,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: PlayerBackdrop(
                style: config.playerBackgroundStyle,
                imageProvider: backdropImageProvider,
                track: track,
                isPortrait: usePortraitArtistPhoto,
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metaControlPage = _PlayerMetaControlPage(
                    noTrackText: AppI18n.t(config, 'player.noTrack'),
                    controller: controller,
                    compactLayout: true,
                    onOpenQueue: _openQueueSheet,
                    onOpenMore: _openMoreSheet,
                    onOpenLyrics: () => _animateToPage(1),
                    onOpenQuality: () async {
                      final track = ref.read(
                        playerControllerProvider.select((s) => s.currentTrack),
                      );
                      final onlinePlatformId = (track?.platform ?? '').trim();
                      final currentAvailableQualities =
                          track != null &&
                              onlinePlatformId.isNotEmpty &&
                              onlinePlatformId != 'local'
                          ? await _resolveSongQualityOptions(
                              track: track,
                              platformId: onlinePlatformId,
                              ref: ref,
                            )
                          : ref.read(
                              playerControllerProvider.select(
                                (s) => s.currentAvailableQualities,
                              ),
                            );
                      final currentSelectedQuality = ref.read(
                        playerControllerProvider.select(
                          (s) => s.currentSelectedQualityName,
                        ),
                      );
                      if (currentAvailableQualities.isEmpty) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      _openQualitySheet(
                        context,
                        controller,
                        currentAvailableQualities,
                        currentSelectedQuality,
                      );
                    },
                    onOpenSpeed: () {
                      final speed = ref.read(
                        playerControllerProvider.select((s) => s.speed),
                      );
                      _openSpeedSheet(context, controller, speed);
                    },
                  );
                  final lyricPage = PlayerLyricPage(
                    emptyText: AppI18n.t(config, 'player.lyrics.empty'),
                    onSeek: (position) {
                      controller.seek(position);
                    },
                    artworkUrl: track?.artworkUrl,
                    artworkBytes: track?.artworkBytes,
                    center: false,
                  );
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                            child: Column(
                              children: <Widget>[
                                _PlayerTopBar(
                                  currentPage: _currentPage,
                                  total: _pageCount,
                                  onTapDot: _animateToPage,
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: PageView(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      if (_currentPage == index) {
                                        return;
                                      }
                                      setState(() => _currentPage = index);
                                    },
                                    children: <Widget>[
                                      metaControlPage,
                                      lyricPage,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _animateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _openQueueSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }

  void _openMoreSheet() {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final controller = ref.read(playerControllerProvider.notifier);
          final track = ref.watch(
            playerControllerProvider.select((s) => s.currentTrack),
          );
          final speed = ref.watch(
            playerControllerProvider.select((s) => s.speed),
          );
          final volume = ref.watch(
            playerControllerProvider.select((s) => s.volume),
          );
          final currentAvailableQualities = ref.watch(
            playerControllerProvider.select((s) => s.currentAvailableQualities),
          );
          final currentSelectedQuality = ref.watch(
            playerControllerProvider.select(
              (s) => s.currentSelectedQualityName,
            ),
          );
          final onlinePlatformId = (track?.platform ?? '').trim();
          final canOnline =
              onlinePlatformId.isNotEmpty && onlinePlatformId != 'local';
          final displayQualities = canOnline && track != null
              ? _buildSongQualityOptions(
                  track: track,
                  platformId: onlinePlatformId,
                  ref: ref,
                )
              : currentAvailableQualities;
          final currentSelectedQualityOption = _findQualityOptionByName(
            displayQualities,
            currentSelectedQuality,
          );
          final downloadQualities = canOnline && track != null
              ? _buildSongQualityOptions(
                  track: track,
                  platformId: onlinePlatformId,
                  ref: ref,
                )
              : const <PlayerQualityOption>[];
          final searchPlatformId = _resolveSearchPlatformId(
            ref,
            preferredPlatformId: canOnline ? onlinePlatformId : null,
          );
          final canSearchSameName =
              track != null &&
              track.title.trim().isNotEmpty &&
              searchPlatformId != null;
          final config = ref.read(appConfigProvider);
          final platforms =
              ref.read(onlinePlatformsProvider).value ??
              const <OnlinePlatform>[];
          final canViewDetail = canOnline && track != null;
          final canViewAlbum =
              canOnline &&
              hasValidAlbumId(track?.albumId) &&
              platformSupportsAlbumDetail(
                platformId: onlinePlatformId,
                platforms: platforms,
              );
          final artistActionLabel = canOnline && track != null
              ? (platformSupportsArtistDetail(
                      platformId: onlinePlatformId,
                      platforms: platforms,
                    )
                    ? songArtistActionLabel(
                        track.artists,
                        localeCode: config.localeCode,
                      )
                    : null)
              : null;
          final canViewArtists =
              canOnline && track != null && artistActionLabel != null;
          final canViewComments =
              canOnline &&
              platformSupportsSongComment(
                platformId: onlinePlatformId,
                platforms: platforms,
              );
          final canWatchMv =
              canOnline &&
              ((track?.mvId?.trim().isNotEmpty ?? false) &&
                  (track?.mvId?.trim() != '0'));
          final onlineKeyword = track?.title.trim() ?? '';
          final onlineId = track?.id ?? '';
          final onlineTitle = track?.title.trim() ?? '';
          final sourcePlatformLabel = canOnline
              ? resolvePlatformLabel(onlinePlatformId, platforms: platforms)
              : 'LOCAL';

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              children: <Widget>[
                if (track != null)
                  PlayerSheetHero(
                    coverUrl: track.artworkUrl,
                    title: track.title,
                    subtitle: (track.artist ?? '-').trim().isEmpty
                        ? '-'
                        : (track.artist ?? '-'),
                  ),
                PlayerSheetActionTile(
                  icon: Icons.speed_rounded,
                  title: AppI18n.t(config, 'player.action.speed'),
                  subtitle: '${speed.toStringAsFixed(2)}x',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openSpeedSheet(rootContext, controller, speed);
                  },
                ),
                PlayerSheetActionTile(
                  icon: Icons.volume_up_rounded,
                  title: AppI18n.t(config, 'player.action.volume'),
                  subtitle: '${(volume * 100).round()}%',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openVolumeSheet(rootContext, controller, volume);
                  },
                ),
                PlayerSheetActionTile(
                  icon: Icons.search_rounded,
                  title: AppI18n.t(config, 'player.action.search_same'),
                  enabled: canSearchSameName,
                  onTap: canSearchSameName
                      ? () {
                          Navigator.of(sheetContext).pop();
                          _goToDetail(
                            Uri(
                              path: AppRoutes.onlineSearch,
                              queryParameters: <String, String>{
                                'platform': searchPlatformId,
                                'keyword': onlineKeyword,
                              },
                            ).toString(),
                          );
                        }
                      : null,
                ),
                PlayerSheetActionTile(
                  icon: Icons.high_quality_rounded,
                  title: AppI18n.t(config, 'player.action.quality'),
                  subtitle: currentSelectedQualityOption?.name,
                  enabled: canOnline && currentAvailableQualities.isNotEmpty,
                  onTap: canOnline && currentAvailableQualities.isNotEmpty
                      ? () async {
                          Navigator.of(sheetContext).pop();
                          final qualities = track != null
                              ? await _resolveSongQualityOptions(
                                  track: track,
                                  platformId: onlinePlatformId,
                                  ref: ref,
                                )
                              : displayQualities;
                          if (!rootContext.mounted) {
                            return;
                          }
                          _openQualitySheet(
                            rootContext,
                            controller,
                            qualities,
                            currentSelectedQuality,
                          );
                        }
                      : null,
                ),
                if (canOnline)
                  PlayerSheetActionTile(
                    icon: Icons.download_rounded,
                    title: AppI18n.t(config, 'player.action.download'),
                    enabled: downloadQualities.isNotEmpty,
                    onTap: downloadQualities.isEmpty
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              _downloadCurrentTrack(
                                track: track!,
                                platformId: onlinePlatformId,
                                qualities: downloadQualities,
                                selectedQualityName: currentSelectedQuality,
                              ),
                            );
                          },
                  ),
                if (canViewDetail)
                  PlayerSheetActionTile(
                    icon: Icons.info_outline_rounded,
                    title: AppI18n.t(config, 'song.action.view_detail'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goToDetail(
                        Uri(
                          path: AppRoutes.songDetail,
                          queryParameters: <String, String>{
                            'id': track.id,
                            'platform': onlinePlatformId,
                            'title': onlineTitle,
                          },
                        ).toString(),
                      );
                    },
                  ),
                if (canViewAlbum)
                  PlayerSheetActionTile(
                    icon: Icons.album_outlined,
                    title: AppI18n.t(config, 'player.action.view_album'),
                    subtitle: track?.album?.trim() ?? '',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goToDetail(
                        Uri(
                          path: AppRoutes.albumDetail,
                          queryParameters: <String, String>{
                            'id': track!.albumId!.trim(),
                            'platform': onlinePlatformId,
                            if ((track.album ?? '').trim().isNotEmpty)
                              'title': track.album!.trim(),
                          },
                        ).toString(),
                      );
                    },
                  ),
                if (canViewArtists)
                  PlayerSheetActionTile(
                    icon: Icons.person_outline_rounded,
                    title: artistActionLabel,
                    subtitle: track.artist ?? '',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openArtistSelectionAndGo(
                        platformId: onlinePlatformId,
                        artists: track.artists,
                      );
                    },
                  ),
                if (canViewComments)
                  PlayerSheetActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: AppI18n.t(config, 'player.action.view_comments'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goToDetail(
                        Uri(
                          path: AppRoutes.onlineComments,
                          queryParameters: <String, String>{
                            'id': onlineId,
                            'platform': onlinePlatformId,
                            'resource_type': 'song',
                            if (onlineTitle.isNotEmpty) 'title': onlineTitle,
                          },
                        ).toString(),
                      );
                    },
                  ),
                if (canOnline)
                  PlayerSheetActionTile(
                    icon: Icons.library_add_rounded,
                    title: AppI18n.t(config, 'detail.batch.add_to_playlist'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_addCurrentSongToUserPlaylist(track!));
                    },
                  ),
                if (canOnline)
                  PlayerSheetActionTile(
                    icon: Icons.share_rounded,
                    title: AppI18n.t(config, 'player.action.copy_share'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await Clipboard.setData(
                        ClipboardData(
                          text: buildShareLink(
                            type: 'song',
                            platform: onlinePlatformId,
                            id: track!.id,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _showMessage(AppI18n.t(config, 'player.copy.share_done'));
                    },
                  ),
                if (canOnline)
                  PlayerSheetActionTile(
                    icon: Icons.ondemand_video_rounded,
                    title: AppI18n.t(config, 'player.action.watch_mv'),
                    enabled: canWatchMv,
                    onTap: canWatchMv
                        ? () {
                            Navigator.of(sheetContext).pop();
                            _goToDetail(
                              Uri(
                                path: AppRoutes.videoDetail,
                                queryParameters: <String, String>{
                                  'id': track!.mvId!.trim(),
                                  'platform': onlinePlatformId,
                                  if (onlineTitle.isNotEmpty)
                                    'title': onlineTitle,
                                },
                              ).toString(),
                            );
                          }
                        : null,
                  ),
                PlayerSheetActionTile(
                  icon: Icons.copy_rounded,
                  title: AppI18n.t(config, 'player.action.copy_name'),
                  enabled: track != null && track.title.trim().isNotEmpty,
                  onTap: track == null || track.title.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await Clipboard.setData(
                            ClipboardData(text: track.title),
                          );
                          if (!mounted) return;
                          _showMessage(
                            AppI18n.t(config, 'player.copy.name_done'),
                          );
                        },
                ),
                PlayerSheetActionTile(
                  icon: Icons.copy_rounded,
                  title: AppI18n.t(config, 'player.action.copy_id'),
                  enabled: track != null && track.id.trim().isNotEmpty,
                  onTap: track == null || track.id.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await Clipboard.setData(
                            ClipboardData(text: track.id),
                          );
                          if (!mounted) return;
                          _showMessage(
                            AppI18n.t(config, 'player.copy.id_done'),
                          );
                        },
                ),
                PlayerSourceInfoRow(
                  label: AppI18n.format(config, 'song.source', <String, String>{
                    'platform': sourcePlatformLabel,
                  }),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSpeedSheet(
    BuildContext context,
    PlayerController controller,
    double current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.5, 2.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppI18n.t(
                              ref.read(appConfigProvider),
                              'player.action.speed',
                            ),
                          ),
                        ),
                        Text('${value.toStringAsFixed(2)}x'),
                      ],
                    ),
                    Slider(
                      value: value,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30,
                      label: '${value.toStringAsFixed(2)}x',
                      onChanged: (next) {
                        setState(() => value = next);
                      },
                      onChangeEnd: (next) {
                        controller.setSpeed(next);
                      },
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () {
                        controller.setSpeed(1.0);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        AppI18n.t(
                          ref.read(appConfigProvider),
                          'player.reset.speed',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadCurrentTrack({
    required PlayerTrack track,
    required String platformId,
    required List<PlayerQualityOption> qualities,
    required String? selectedQualityName,
  }) async {
    final config = ref.read(appConfigProvider);
    final selected = await showDownloadQualitySheet(
      context: context,
      qualities: qualities,
      selectedQualityName: selectedQualityName ?? qualities.first.name,
    );
    if (selected == null) {
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: track.title,
            quality: DownloadTaskQuality(
              label: selected.name,
              bitrate: selected.quality.toDouble(),
              fileExtension: selected.format.trim().toLowerCase(),
            ),
            songId: track.id,
            platform: platformId,
            artist: track.artist,
            album: track.album,
            artworkUrl: track.artworkUrl,
          );
      if (!mounted) {
        return;
      }
      _showMessage(
        AppI18n.format(config, 'player.download.added', <String, String>{
          'title': track.title,
        }),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(AppI18n.t(config, 'player.download.failed'));
    }
  }

  Future<List<PlayerQualityOption>> _resolveSongQualityOptions({
    required WidgetRef ref,
    required PlayerTrack track,
    required String platformId,
  }) async {
    final immediate = _buildSongQualityOptions(
      ref: ref,
      track: track,
      platformId: platformId,
    );
    if (immediate.any(
      (quality) => (quality.description ?? '').trim().isNotEmpty,
    )) {
      return immediate;
    }
    final platforms = await ref.read(onlinePlatformsProvider.future);
    return _buildSongQualityOptions(
      ref: ref,
      track: track,
      platformId: platformId,
      platforms: platforms,
    );
  }

  List<PlayerQualityOption> _buildSongQualityOptions({
    required WidgetRef ref,
    required PlayerTrack track,
    required String platformId,
    List<OnlinePlatform>? platforms,
  }) {
    final resolvedPlatforms =
        platforms ?? ref.read(onlinePlatformsProvider).value;
    final qualityDescriptions = <String, String>{};
    for (final platform in resolvedPlatforms ?? const <OnlinePlatform>[]) {
      if (platform.id == platformId) {
        qualityDescriptions.addAll(platform.qualities);
        break;
      }
    }
    return buildDownloadQualityOptions(
      links: track.links,
      qualityDescriptions: qualityDescriptions,
    );
  }

  void _openVolumeSheet(
    BuildContext context,
    PlayerController controller,
    double current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.0, 1.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppI18n.t(
                              ref.read(appConfigProvider),
                              'player.action.volume',
                            ),
                          ),
                        ),
                        Text('${(value * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: value,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '${(value * 100).round()}%',
                      onChanged: (next) {
                        setState(() => value = next);
                      },
                      onChangeEnd: (next) {
                        controller.setVolume(next);
                      },
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: () {
                        controller.setVolume(1.0);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        AppI18n.t(
                          ref.read(appConfigProvider),
                          'player.reset.volume',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openQualitySheet(
    BuildContext context,
    PlayerController controller,
    List<PlayerQualityOption> availableQualities,
    String? current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final quality in availableQualities)
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: Text(quality.name),
                  subtitle: _buildQualitySubtitle(quality),
                  trailing: current == quality.name
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.switchCurrentQualityByName(quality.name);
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 关闭播放器后把详情页压入根 Navigator。
  ///
  /// 播放器和详情页都在根 navigator，使用 push 保留来源页面的返回栈。
  void _goToDetail(String location) {
    Navigator.of(context).pop();
    unawaited(GoRouter.of(context).push(location));
  }

  /// 弹出歌手选择面板，选择后关闭播放器并导航到歌手详情。
  void _openArtistSelectionAndGo({
    required String platformId,
    required List<SongInfoArtistInfo> artists,
  }) {
    final available = artists
        .where((a) => a.id.trim().isNotEmpty && a.name.trim().isNotEmpty)
        .toList();
    if (available.isEmpty) {
      _showMessage(
        AppI18n.t(ref.read(appConfigProvider), 'song.artist.unavailable'),
      );
      return;
    }
    if (available.length == 1) {
      _goToDetail(
        Uri(
          path: AppRoutes.artistDetail,
          queryParameters: <String, String>{
            'id': available.first.id.trim(),
            'platform': platformId,
            'title': available.first.name.trim(),
          },
        ).toString(),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final artist in available)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(artist.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _goToDetail(
                      Uri(
                        path: AppRoutes.artistDetail,
                        queryParameters: <String, String>{
                          'id': artist.id.trim(),
                          'platform': platformId,
                          'title': artist.name.trim(),
                        },
                      ).toString(),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCurrentSongToUserPlaylist(PlayerTrack track) async {
    final platform = (track.platform ?? '').trim();
    final id = track.id.trim();
    if (platform.isEmpty || platform == 'local' || id.isEmpty) {
      return;
    }
    await addSingleSongToUserPlaylist(
      context: context,
      ref: ref,
      song: IdPlatformInfo(id: id, platform: platform),
    );
  }

  String? _resolveSearchPlatformId(
    WidgetRef ref, {
    String? preferredPlatformId,
  }) {
    final preferred = preferredPlatformId?.trim() ?? '';
    if (preferred.isNotEmpty && preferred != 'local') {
      return preferred;
    }
    final platforms = ref.read(onlinePlatformsProvider).value;
    if (platforms == null || platforms.isEmpty) {
      return null;
    }
    for (final platform in platforms) {
      if (platform.available) {
        return platform.id;
      }
    }
    return null;
  }

  PlayerQualityOption? _findQualityOptionByName(
    List<PlayerQualityOption> options,
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }

  Widget? _buildQualitySubtitle(PlayerQualityOption quality) {
    final parts = <String>[
      if ((quality.description ?? '').trim().isNotEmpty)
        quality.description!.trim(),
      if (quality.sizeLabel.isNotEmpty) quality.sizeLabel,
    ];
    if (parts.isEmpty) {
      return null;
    }
    return Text(parts.join(' · '));
  }
}

@visibleForTesting
bool resolvePlayerArtistPhotoPortraitForTest(Size windowSize) {
  return windowSize.height >= windowSize.width ||
      windowSize.width < LayoutTokens.desktopBreakpoint;
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.currentPage,
    required this.total,
    required this.onTapDot,
  });

  final int currentPage;
  final int total;
  final ValueChanged<int> onTapDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: Navigator.of(context).pop,
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(total, (index) {
              final active = index == currentPage;
              return GestureDetector(
                onTap: () => onTapDot(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PlayerStageCard extends StatelessWidget {
  const _PlayerStageCard({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 14, 12, compact ? 6 : 10),
      child: child,
    );
  }
}

class _PlayerMetaControlPage extends StatelessWidget {
  const _PlayerMetaControlPage({
    required this.noTrackText,
    required this.controller,
    required this.compactLayout,
    required this.onOpenQueue,
    required this.onOpenMore,
    required this.onOpenLyrics,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final PlayerController controller;
  final bool compactLayout;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context) {
    final infoSection = PlayerInfoPage(
      noTrackText: noTrackText,
      compactLayout: compactLayout,
      fillHeight: false,
      onOpenLyrics: onOpenLyrics,
      onOpenQuality: onOpenQuality,
      onOpenSpeed: onOpenSpeed,
    );
    final stageSection = _PlayerStageCard(
      compact: compactLayout,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const _PlayerFavoriteButton(),
              const Spacer(),
              _PlayerUtilityRow(onOpenMore: onOpenMore),
            ],
          ),
          SizedBox(height: compactLayout ? 6 : 10),
          _PlayerProgressSection(onSeek: controller.seek),
          SizedBox(height: compactLayout ? 12 : 18),
          _PlayerControlSection(
            controller: controller,
            compactLayout: compactLayout,
            onOpenQueue: onOpenQueue,
          ),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: infoSection,
          ),
        ),
        SizedBox(height: compactLayout ? 4 : 8),
        stageSection,
      ],
    );
  }
}

class _PlayerUtilityRow extends ConsumerWidget {
  const _PlayerUtilityRow({required this.onOpenMore});

  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlayerUtilityButton(
          icon: Icons.more_horiz_rounded,
          color: Colors.white.withValues(alpha: 0.82),
          onTap: onOpenMore,
        ),
      ],
    );
  }
}

class _PlayerFavoriteButton extends ConsumerWidget {
  const _PlayerFavoriteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((s) => s.currentTrack),
    );
    final platformId = (track?.platform ?? '').trim();
    final canOnline = platformId.isNotEmpty && platformId != 'local';

    if (!canOnline || track == null) {
      return const SizedBox(width: 40, height: 40);
    }

    final isFavorited = ref.watch(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: track.id, platform: platformId),
        ),
      ),
    );

    final color = isFavorited
        ? Colors.redAccent
        : Colors.white.withValues(alpha: 0.82);

    return _PlayerUtilityButton(
      icon: isFavorited
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      color: color,
      onTap: () async {
        await ref
            .read(onlineControllerProvider.notifier)
            .toggleSongFavorite(
              songId: track.id,
              platform: platformId,
              like: !isFavorited,
            );
      },
    );
  }
}

class _PlayerUtilityButton extends StatelessWidget {
  const _PlayerUtilityButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _PlayerProgressSection extends ConsumerWidget {
  const _PlayerProgressSection({required this.onSeek});

  final Future<void> Function(Duration) onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playerControllerProvider.select((state) => state.position),
    );
    final duration = ref.watch(
      playerControllerProvider.select((state) => state.duration),
    );
    return PlayerProgressBar(
      position: position,
      duration: duration,
      onSeek: onSeek,
    );
  }
}

class _PlayerControlSection extends ConsumerWidget {
  const _PlayerControlSection({
    required this.controller,
    required this.compactLayout,
    required this.onOpenQueue,
  });

  final PlayerController controller;
  final bool compactLayout;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    return PlayerControlBar(
      config: config,
      compact: compactLayout,
      isPlaying: isPlaying,
      playMode: playMode,
      showPlayModeButton: !isRadioMode,
      playModeLocked: isRadioMode,
      showQueueButton: !isRadioMode,
      onOpenQueue: onOpenQueue,
      onCyclePlayMode: controller.cyclePlayMode,
      onPrevious: controller.playPrevious,
      onPlayPause: controller.togglePlayPause,
      onNext: controller.playNext,
    );
  }
}
