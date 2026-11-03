import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/player_route_page.dart';
import '../../../lyrics/presentation/widgets/full_lyric_controls.dart';
import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_player_wide_view.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_route_observers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../app/theme/player/app_player_style_models.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../app/theme/player/styles/cassette_player_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../../core/device/screen_wake_lock.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/helpers/user_playlist_song_action_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/adaptive_action_menu.dart';
import '../../../../shared/widgets/app_slider.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_sheet_close_button.dart';
import '../../../../shared/widgets/app_list_tile.dart';
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
import '../controllers/realtime_spectrum_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../layout/player_layout_spec.dart';
import '../layout/player_responsive_layout.dart';
import '../layout/player_wide_layout.dart';
import '../providers/player_providers.dart';
import '../styles/player_style_stage.dart';
import '../styles/player_track_header.dart';
import '../widgets/monet_lyric_page.dart';
import '../widgets/fold_lyric_page.dart';
import '../widgets/cinema_lyric_page.dart';
import '../widgets/cadenza_lyric_page.dart';
import '../widgets/partita_lyric_page.dart';
import '../widgets/tilt_lyric_page.dart';
import '../widgets/star_tunnel_lyric_page.dart';
import '../widgets/kinetic_lyric_page.dart';
import '../widgets/pendolo_lyric_page.dart';
import '../widgets/claddagh_lyric_page.dart';
import '../widgets/player_backdrop.dart';
import '../widgets/player_compact_lyric_section.dart';
import '../widgets/player_control_bar.dart';
import '../widgets/lyric_photo_dimmer.dart';
import '../widgets/player_lyric_page.dart';
import '../widgets/player_more_sheet_widgets.dart';
import '../../../../shared/widgets/app_sheet_header.dart';
import '../widgets/player_sheet_section.dart';
import '../widgets/player_quality_selection_sheet.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/player_queue_sheet.dart';
import '../widgets/player_sleep_timer_sheet.dart';
import '../widgets/player_style_selection_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    this.artistPhotoImageProviderBuilder,
    this.debugOnBuild,
  });

  final ArtistPhotoImageProviderBuilder? artistPhotoImageProviderBuilder;
  @visibleForTesting
  final VoidCallback? debugOnBuild;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

enum _PlayerOrientationPreference {
  systemManaged,
  manualLandscape,
  portraitAfterExit,
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver, RouteAware {
  static const _pageCount = 2;
  late final PageController _pageController = PageController();
  final GlobalKey _lyricPageKey = GlobalKey(debugLabel: 'player-lyric-page');
  final ValueNotifier<int> _seekRevision = ValueNotifier<int>(0);
  int _currentPage = 0;
  int? _mobilePageToRestore;
  PlayerLayoutMode? _lastLayoutMode;
  bool _isLandscapeSystemUiActive = false;
  bool _closingPlayer = false;
  _PlayerOrientationPreference _orientationPreference =
      _PlayerOrientationPreference.systemManaged;
  late final ScreenWakeLockPort _screenWakeLockPort;
  late bool _isPlaybackSessionActive;
  AppLifecycleState? _appLifecycleState;
  PageRoute<dynamic>? _pageRoute;
  bool _isCurrentPageRoute = false;
  bool _isDisposed = false;
  bool _desiredWakeLockEnabled = false;
  bool? _appliedWakeLockEnabled;
  bool? _inFlightWakeLockTarget;
  bool _isWakeLockSyncRunning = false;
  PlayerLayoutMode? _spectrumLayoutMode;
  bool _usesRealtimeSpectrum = false;
  RealtimeSpectrumController? _spectrumController;
  bool _spectrumSyncScheduled = false;
  List<Color> _classicBackdropColors = const <Color>[];
  bool _wideLayoutActive = false;
  bool _wideStageVisible = true;

  @override
  void initState() {
    super.initState();
    _screenWakeLockPort = ref.read(screenWakeLockPortProvider);
    _isPlaybackSessionActive = ref.read(
      playerControllerProvider.select((state) => state.isPlaybackSessionActive),
    );
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<bool>(
      playerControllerProvider.select((state) => state.isPlaybackSessionActive),
      (previous, next) {
        _isPlaybackSessionActive = next;
        _requestWakeLockSync();
      },
      fireImmediately: false,
    );
    Future.microtask(() {
      ref.read(playerControllerProvider.notifier).initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRoute = ModalRoute.of(context);
    if (nextRoute is! PageRoute<dynamic> || identical(nextRoute, _pageRoute)) {
      return;
    }
    final previousRoute = _pageRoute;
    if (previousRoute != null) {
      appPageRouteObserver.unsubscribe(this);
    }
    _pageRoute = nextRoute;
    appPageRouteObserver.subscribe(this, nextRoute);
  }

  @override
  void dispose() {
    final pageRoute = _pageRoute;
    if (pageRoute != null) {
      appPageRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _isCurrentPageRoute = false;
    _isDisposed = true;
    _requestWakeLockSync();
    _spectrumController?.setConsumerVisible(false);
    if (_usesMobileOrientationControls) {
      unawaited(
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]),
      );
      unawaited(_restoreDefaultSystemUi(force: true));
    }
    _pageController.dispose();
    _seekRevision.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    _requestWakeLockSync();
    _requestSpectrumVisibilitySync();
  }

  @override
  void didPush() {
    _setCurrentPageRoute(true);
  }

  @override
  void didPopNext() {
    _setCurrentPageRoute(true);
  }

  @override
  void didPushNext() {
    _setCurrentPageRoute(false);
  }

  @override
  void didPop() {
    _setCurrentPageRoute(false);
  }

  void _setCurrentPageRoute(bool isCurrent) {
    if (_isCurrentPageRoute == isCurrent) {
      return;
    }
    _isCurrentPageRoute = isCurrent;
    _requestWakeLockSync();
    _requestSpectrumVisibilitySync();
  }

  void _requestWakeLockSync() {
    if (!_isMobileTargetPlatform) {
      return;
    }
    _desiredWakeLockEnabled =
        !_isDisposed &&
        _appLifecycleState == AppLifecycleState.resumed &&
        _isCurrentPageRoute &&
        _isPlaybackSessionActive;
    if (_isWakeLockSyncRunning || !_needsWakeLockSync) {
      return;
    }
    unawaited(_drainWakeLockSync());
  }

  bool get _isMobileTargetPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _needsWakeLockSync {
    if (_desiredWakeLockEnabled) {
      return _appliedWakeLockEnabled != true;
    }
    return _appliedWakeLockEnabled == true || _inFlightWakeLockTarget == true;
  }

  // 串行执行平台调用，快速状态变化始终继续收敛到最后一个目标。
  Future<void> _drainWakeLockSync() async {
    _isWakeLockSyncRunning = true;
    var failed = false;
    try {
      while (_needsWakeLockSync) {
        final target = _desiredWakeLockEnabled;
        _inFlightWakeLockTarget = target;
        try {
          await _screenWakeLockPort.setEnabled(target);
          _appliedWakeLockEnabled = target;
        } catch (error, stackTrace) {
          failed = true;
          developer.log(
            'Screen wake lock sync failed',
            name: 'PlayerPage',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        } finally {
          _inFlightWakeLockTarget = null;
        }
      }
    } finally {
      _isWakeLockSyncRunning = false;
      if (!failed && _needsWakeLockSync) {
        unawaited(_drainWakeLockSync());
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildPlayer(context, constraints.biggest),
  );

  Widget _buildPlayer(BuildContext context, Size viewportSize) {
    widget.debugOnBuild?.call();
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (
          stageId: state.playerStageId,
          backdropId: state.playerBackdropId,
          lyricsId: state.playerLyricsId,
          playerWideView: state.playerWideView,
          localeCode: state.localeCode,
        ),
      ),
    );
    final stage = AppPlayerStageRegistry.instance.resolve(config.stageId);
    final backdrop = AppPlayerBackdropRegistry.instance.resolve(
      config.backdropId,
    );
    final lyrics = AppPlayerLyricsRegistry.instance.resolve(config.lyricsId);
    final scenePalette = _resolvePlayerScenePalette(
      stage.stageKind,
      _classicBackdropColors,
    );
    final controller = ref.read(playerControllerProvider.notifier);
    Future<void> seek(Duration position) {
      _seekRevision.value += 1;
      return controller.seek(position);
    }

    Future<void> seekFromLyric(Duration position) {
      _seekRevision.value += 1;
      return controller.seekFromLyric(position);
    }

    final presentation = ref.watch(
      playerControllerProvider.select(
        (state) => (
          currentTrack: state.currentTrack,
          displayTrack: state.displayTrack,
          isTrackTransitioning: state.isTrackTransitioning,
        ),
      ),
    );
    final onlinePlatforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final displayedTrack = presentation.displayTrack;
    final VoidCallback? onOpenArtist =
        !presentation.isTrackTransitioning &&
            _canOpenTrackArtist(displayedTrack, onlinePlatforms)
        ? () => _openTrackArtist(displayedTrack!)
        : null;
    final backdropImageProvider = artworkProvider(
      displayedTrack?.artworkUrl,
      displayedTrack?.artworkBytes,
    );
    final usePortraitArtistPhoto = resolvePlayerArtistPhotoPortraitForTest(
      viewportSize,
    );
    final allowMobileLandscape = _usesMobileOrientationControls;
    final currentLayoutMode = PlayerLayoutSpec.resolve(
      BoxConstraints.tight(viewportSize),
      allowMobileLandscape: allowMobileLandscape,
    ).mode;
    final isMobileLandscape =
        currentLayoutMode == PlayerLayoutMode.mobileLandscape;
    final useWideLayout = PlayerWideLayout.supports(
      viewportSize,
      isMobileLandscape: isMobileLandscape,
    );
    if (_wideLayoutActive && !useWideLayout) {
      _restoreCurrentPageAfterLayoutChange(_currentPage);
    }
    _wideLayoutActive = useWideLayout;
    _wideStageVisible = config.playerWideView != AppPlayerWideView.lyrics;
    _usesRealtimeSpectrum = stage.usesRealtimeSpectrum;
    _scheduleSpectrumVisibilitySync();
    final landscapeSafeMinimum = isMobileLandscape
        ? resolvePlayerLandscapeContentInsets(
            resolvePlayerLandscapeSafeInsets(
              size: viewportSize,
              systemGestureInsets: MediaQuery.systemGestureInsetsOf(context),
              displayFeatures: MediaQuery.of(context).displayFeatures,
            ),
          )
        : EdgeInsets.zero;
    final shouldRestorePortraitOnPop =
        _usesMobileOrientationControls &&
        (currentLayoutMode == PlayerLayoutMode.mobileLandscape ||
            _orientationPreference ==
                _PlayerOrientationPreference.manualLandscape);
    Widget buildLyricPage({bool showControls = true}) {
      final lyricPage = PlayerLyricPage(
        key: _lyricPageKey,
        emptyText: AppI18n.tByLocaleCode(
          config.localeCode,
          'player.lyrics.empty',
        ),
        onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
        artworkUrl: presentation.currentTrack?.artworkUrl,
        artworkBytes: presentation.currentTrack?.artworkBytes,
        center:
            useWideLayout && config.playerWideView == AppPlayerWideView.lyrics,
        fontScale: useWideLayout && viewportSize.height >= 600 ? 1.5 : 1,
      );
      final content = switch (lyrics.lyricsKind) {
        AppPlayerLyricsKind.legacy => lyricPage,
        AppPlayerLyricsKind.monet => MonetLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.fold => FoldLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.cinema => CinemaLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.partita => PartitaLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.cadenza => CadenzaLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.tilt => TiltLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.starTunnel => StarTunnelLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.kinetic => KineticLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.pendolo => PendoloLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
        AppPlayerLyricsKind.claddagh => CladdaghLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
          seekListenable: _seekRevision,
        ),
      };
      final lyricContent = showControls
          ? Column(
              children: [
                Expanded(child: content),
                const FullLyricControls(),
              ],
            )
          : content;
      return lyricContent;
    }

    if (useWideLayout) {
      _handleLayoutModeResolved(currentLayoutMode);
      return PopScope(
        canPop: !shouldRestorePortraitOnPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_exitLandscape());
        },
        child: _PlayerScenePaletteScope(
          palette: scenePalette,
          child: PlayerWideLayout(
            view: config.playerWideView,
            localeCode: config.localeCode,
            onViewChanged: ref
                .read(appConfigProvider.notifier)
                .setPlayerWideView,
            onClose: () =>
                unawaited(PlayerDismissRegion.close(context, _closePlayer)),
            onOpenMore: presentation.isTrackTransitioning
                ? null
                : _openMoreSheet,
            background: Stack(
              fit: StackFit.expand,
              children: [
                Consumer(
                  builder: (context, ref, _) => PlayerBackdrop(
                    motionActive:
                        backdrop.backdropKind != AppPlayerBackdropKind.fluid ||
                        ref.watch(
                          playerControllerProvider.select((s) => s.isPlaying),
                        ),
                    backdropKind: backdrop.backdropKind,
                    imageProvider: backdropImageProvider,
                    track: displayedTrack,
                    isPortrait: usePortraitArtistPhoto,
                    artistPhotoImageProviderBuilder:
                        widget.artistPhotoImageProviderBuilder,
                    onClassicPaletteChanged: scenePalette == null
                        ? null
                        : _handleClassicPaletteChanged,
                  ),
                ),
                if (backdrop.backdropKind.supportsLyricBrightness &&
                    config.playerWideView != AppPlayerWideView.cover)
                  const LyricPhotoDimmer(),
              ],
            ),
            stageMaxWidth: stage.stageMaxWidth,
            stageAspectRatio: stage.stageKind == AppPlayerStageKind.cassette
                ? cassettePlayerStageAspectRatio
                : 1,
            metadataHeight: PlayerTrackHeader.resolveLayoutHeight(context),
            // The classic sleeve paints its visible cover at 94% of the stage.
            metadataWidthFactor:
                stage.stageKind == AppPlayerStageKind.classic ||
                    stage.stageKind == AppPlayerStageKind.none
                ? .94
                : 1,
            stage: PlayerStyleStage(
              stageKind: stage.stageKind,
              track: displayedTrack,
              maxWidth: stage.stageMaxWidth,
              cassetteLabel: stage.stageKind == AppPlayerStageKind.cassette
                  ? PlayerTrackHeader(
                      noTrackText: AppI18n.tByLocaleCode(
                        config.localeCode,
                        'player.noTrack',
                      ),
                      artistSlotWidth: 220,
                      layout: PlayerTrackHeaderLayout.cassetteLabel,
                      showCassetteMetadataBadges: false,
                      onOpenQuality: () =>
                          _openCurrentQualitySheet(context, controller),
                      onOpenSpeed: () => _openSpeedSheet(
                        context,
                        controller,
                        ref.read(
                          playerControllerProvider.select((s) => s.speed),
                        ),
                      ),
                    )
                  : null,
            ),
            lyrics: buildLyricPage(showControls: false),
            metadata: Row(
              children: [
                Expanded(
                  child: PlayerTrackHeader(
                    noTrackText: AppI18n.tByLocaleCode(
                      config.localeCode,
                      'player.noTrack',
                    ),
                    artistSlotWidth: 220,
                    onOpenArtist: onOpenArtist,
                    onOpenQuality: () =>
                        _openCurrentQualitySheet(context, controller),
                    onOpenSpeed: () => _openSpeedSheet(
                      context,
                      controller,
                      ref.read(playerControllerProvider.select((s) => s.speed)),
                    ),
                  ),
                ),
                const _PlayerFavoriteButton(),
              ],
            ),
            progress: _PlayerProgressSection(onSeek: seek),
            controls: _PlayerControlSection(
              controller: controller,
              compactLayout: true,
              onOpenQueue: _openQueueSheet,
            ),
            actions: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Visibility(
                  visible: config.playerWideView != AppPlayerWideView.cover,
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: const FullLyricControls(showPlaybackControl: false),
                ),
                _PlayerWideVolumeControl(controller: controller),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !shouldRestorePortraitOnPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_exitLandscape());
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, _) => PlayerBackdrop(
                  motionActive:
                      backdrop.backdropKind != AppPlayerBackdropKind.fluid ||
                      ref.watch(
                        playerControllerProvider.select(
                          (state) => state.isPlaying,
                        ),
                      ),
                  backdropKind: backdrop.backdropKind,
                  imageProvider: backdropImageProvider,
                  track: displayedTrack,
                  isPortrait: usePortraitArtistPhoto,
                  artistPhotoImageProviderBuilder:
                      widget.artistPhotoImageProviderBuilder,
                  onClassicPaletteChanged: scenePalette == null
                      ? null
                      : _handleClassicPaletteChanged,
                ),
              ),
            ),
            if (backdrop.backdropKind.supportsLyricBrightness)
              // 遮罩覆盖整张背景；翻页布局仅在歌词页按设置降低照片亮度。
              Positioned.fill(
                child: LyricPhotoDimmer(
                  pageController:
                      currentLayoutMode == PlayerLayoutMode.mobilePortrait
                      ? _pageController
                      : null,
                ),
              ),
            Positioned.fill(
              child: SafeArea(
                left: !isMobileLandscape,
                top: !isMobileLandscape,
                right: !isMobileLandscape,
                bottom: !isMobileLandscape,
                minimum: landscapeSafeMinimum,
                child: _PlayerScenePaletteScope(
                  palette: scenePalette,
                  child: PlayerResponsiveLayout(
                    pageController: _pageController,
                    onLayoutModeResolved: _handleLayoutModeResolved,
                    allowMobileLandscape: allowMobileLandscape,
                    onPageChanged: (index) {
                      final pageToRestore = _mobilePageToRestore;
                      if (pageToRestore != null && index != pageToRestore) {
                        return;
                      }
                      if (_currentPage == index) {
                        return;
                      }
                      setState(() => _currentPage = index);
                      _requestSpectrumVisibilitySync();
                    },
                    topBarBuilder: (context, spec) {
                      final header = _PlayerTopBar(
                        currentPage: _currentPage,
                        total: _pageCount,
                        showPageIndicator:
                            spec.mode == PlayerLayoutMode.mobilePortrait,
                        onClose: () => unawaited(
                          PlayerDismissRegion.close(context, _closePlayer),
                        ),
                        onTapDot: _animateToPage,
                      );
                      return spec.mode == PlayerLayoutMode.mobilePortrait
                          ? PlayerDismissRegion(
                              onDismiss: _closePlayer,
                              child: header,
                            )
                          : header;
                    },
                    mainPlayerBuilder: (context, spec) =>
                        _PlayerMetaControlPage(
                          noTrackText: AppI18n.tByLocaleCode(
                            config.localeCode,
                            'player.noTrack',
                          ),
                          controller: controller,
                          onSeek: seek,
                          layoutSpec: spec,
                          stageKind: stage.stageKind,
                          stageMaxWidth: stage.stageMaxWidth,
                          track: displayedTrack,
                          onOpenArtist: onOpenArtist,
                          onOpenQueue: _openQueueSheet,
                          onOpenMore: _openMoreSheet,
                          onOpenLyrics: () => _animateToPage(1),
                          onOpenQuality: () =>
                              _openCurrentQualitySheet(context, controller),
                          onOpenSpeed: () {
                            final speed = ref.read(
                              playerControllerProvider.select((s) => s.speed),
                            );
                            _openSpeedSheet(context, controller, speed);
                          },
                        ),
                    mobileLandscapeBuilder: (context, spec) =>
                        _PlayerMobileLandscapeLayout(
                          noTrackText: AppI18n.tByLocaleCode(
                            config.localeCode,
                            'player.noTrack',
                          ),
                          controller: controller,
                          onSeek: seek,
                          layoutSpec: spec,
                          stageKind: stage.stageKind,
                          stageMaxWidth: stage.stageMaxWidth,
                          track: displayedTrack,
                          lyrics: buildLyricPage(showControls: false),
                          exitLandscapeTooltip: AppI18n.tByLocaleCode(
                            config.localeCode,
                            'player.action.exit_landscape',
                          ),
                          onExitLandscape: () => unawaited(_exitLandscape()),
                          onOpenArtist: onOpenArtist,
                          onOpenQueue: _openQueueSheet,
                          onOpenQuality: () =>
                              _openCurrentQualitySheet(context, controller),
                          onOpenSpeed: () {
                            final speed = ref.read(
                              playerControllerProvider.select((s) => s.speed),
                            );
                            _openSpeedSheet(context, controller, speed);
                          },
                        ),
                    lyricsBuilder: (context, spec) => buildLyricPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleClassicPaletteChanged(List<Color> colors) {
    if (!mounted) return;
    if (listEquals(colors, _classicBackdropColors)) return;
    setState(() {
      _classicBackdropColors = List<Color>.unmodifiable(colors);
    });
  }

  Future<void> _openCurrentQualitySheet(
    BuildContext context,
    PlayerController controller,
  ) async {
    final track = ref.read(
      playerControllerProvider.select((state) => state.currentTrack),
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
              (state) => state.currentAvailableQualities,
            ),
          );
    final currentSelectedQuality = ref.read(
      playerControllerProvider.select(
        (state) => state.currentSelectedQualityName,
      ),
    );
    if (currentAvailableQualities.isEmpty || !context.mounted) return;
    _openQualitySheet(
      context,
      controller,
      currentAvailableQualities,
      currentSelectedQuality,
    );
  }

  void _animateToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _restoreCurrentPageAfterLayoutChange(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _mobilePageToRestore = null;
      _currentPage = page;
      _pageController.jumpToPage(page);
    });
  }

  void _handleLayoutModeResolved(PlayerLayoutMode mode) {
    final previousMode = _lastLayoutMode;
    if (mode == previousMode) return;
    _lastLayoutMode = mode;
    _spectrumLayoutMode = mode;
    _scheduleSpectrumVisibilitySync();
    _scheduleSystemUiForLayout(mode);
    if (mode != PlayerLayoutMode.mobilePortrait &&
        previousMode == PlayerLayoutMode.mobilePortrait) {
      _mobilePageToRestore = _currentPage;
      return;
    }
    if (mode == PlayerLayoutMode.mobilePortrait && previousMode != null) {
      _restoreCurrentPageAfterLayoutChange(
        _mobilePageToRestore ?? _currentPage,
      );
    }
  }

  void _scheduleSpectrumVisibilitySync() {
    if (_spectrumSyncScheduled) {
      return;
    }
    _spectrumSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spectrumSyncScheduled = false;
      if (!mounted) {
        return;
      }
      _requestSpectrumVisibilitySync();
    });
  }

  void _requestSpectrumVisibilitySync() {
    final mode = _spectrumLayoutMode;
    final stageVisible = _wideLayoutActive
        ? _wideStageVisible
        : mode != PlayerLayoutMode.mobilePortrait || _currentPage == 0;
    // macOS 窗口失去键盘焦点时会进入 inactive，但窗口和舞台仍然可见。
    final lifecycleAllowsCapture =
        _appLifecycleState == AppLifecycleState.resumed ||
        (defaultTargetPlatform == TargetPlatform.macOS &&
            _appLifecycleState == AppLifecycleState.inactive);
    final shouldCapture =
        !_isDisposed &&
        _usesRealtimeSpectrum &&
        lifecycleAllowsCapture &&
        _isCurrentPageRoute &&
        stageVisible;
    if (shouldCapture) {
      _spectrumController ??= ref.read(
        realtimeSpectrumControllerProvider.notifier,
      );
    }
    final controller = _spectrumController;
    if (controller == null) {
      return;
    }
    controller.setConsumerVisible(shouldCapture);
  }

  void _scheduleSystemUiForLayout(PlayerLayoutMode mode) {
    if (!_usesMobileOrientationControls) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastLayoutMode != mode) return;
      if (mode == PlayerLayoutMode.mobileLandscape) {
        unawaited(_enableLandscapeSystemUi());
      } else {
        unawaited(_restoreDefaultSystemUi());
      }
    });
  }

  Future<void> _enableLandscapeSystemUi() async {
    if (!_usesMobileOrientationControls || _isLandscapeSystemUiActive) return;
    _isLandscapeSystemUiActive = true;
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } on PlatformException {
      _isLandscapeSystemUiActive = false;
    }
  }

  Future<void> _restoreDefaultSystemUi({bool force = false}) async {
    if (!_usesMobileOrientationControls ||
        (!_isLandscapeSystemUiActive && !force)) {
      return;
    }
    _isLandscapeSystemUiActive = false;
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } on PlatformException {
      return;
    }
  }

  bool get _usesMobileOrientationControls =>
      supportsPlayerOrientationControlsForTest(
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      );

  Future<void> _enterManualLandscape() async {
    if (!_usesMobileOrientationControls) return;
    setState(() {
      _orientationPreference = _PlayerOrientationPreference.manualLandscape;
    });
    try {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _orientationPreference = _PlayerOrientationPreference.systemManaged;
      });
    }
  }

  Future<void> _exitLandscape() async {
    if (!_usesMobileOrientationControls) return;
    setState(() {
      _orientationPreference = _PlayerOrientationPreference.portraitAfterExit;
    });
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _closePlayer() async {
    final route = ModalRoute.of(context);
    if (_closingPlayer ||
        route == null ||
        !route.isActive ||
        !route.isCurrent) {
      return;
    }
    final navigator = Navigator.of(context);
    _closingPlayer = true;
    try {
      if (_usesMobileOrientationControls) {
        _orientationPreference = _PlayerOrientationPreference.systemManaged;
        await Future.wait<void>(<Future<void>>[
          SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]),
          _restoreDefaultSystemUi(force: true),
        ]);
      }
      // System back can pop this route while platform cleanup is pending.
      // mounted alone remains true throughout its reverse transition.
      if (!mounted || !route.isActive || !route.isCurrent) return;
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        // A deep link may have opened the player as the only router page.
        GoRouter.maybeOf(context)?.go(AppRoutes.home);
      }
    } finally {
      _closingPlayer = false;
    }
  }

  void _openQueueSheet() {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      fixedHeightFactor: LayoutTokens.queueSheetHeightFactor,
      builder: (context) => const PlayerQueueSheet(),
    );
  }

  void _openMoreSheet() {
    final track = ref.read(playerControllerProvider).currentTrack;
    if (track == null) {
      unawaited(
        showPlayerStyledBottomSheet<void>(
          context: context,
          fitContent: true,
          useAppAccent: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSheetHeader(
                  title: AppI18n.tByLocaleCode(
                    Localizations.localeOf(sheetContext).languageCode,
                    'common.more',
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildPlaybackActions(sheetContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final controller = ref.read(playerControllerProvider.notifier);
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final platform = (track.platform ?? '').trim();
    final online = platform.isNotEmpty && platform != 'local';
    final qualities = online
        ? _buildSongQualityOptions(ref: ref, track: track, platformId: platform)
        : const <PlayerQualityOption>[];
    final canViewDetail =
        online &&
        canOpenSongDetail(
          songId: track.id,
          platformId: platform,
          platforms: platforms,
        );
    final canViewAlbum =
        online &&
        hasValidAlbumId(track.albumId) &&
        platformSupportsAlbumDetail(platformId: platform, platforms: platforms);
    final artistLabel =
        online &&
            platformSupportsArtistDetail(
              platformId: platform,
              platforms: platforms,
            )
        ? songArtistActionLabel(track.artists, localeCode: config.localeCode)
        : null;
    final searchPlatform = _resolveSearchPlatformId(
      ref,
      preferredPlatformId: online ? platform : null,
    );
    void navigate(String path, Map<String, String> parameters) =>
        _goToDetail(Uri(path: path, queryParameters: parameters).toString());
    Future<void> copy(String text, String messageKey) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) AppMessageService.showSuccess(AppI18n.t(config, messageKey));
    }

    unawaited(
      showSongActionsSheet(
        context: context,
        forceBottomSheet: true,
        leadingActionsBuilder: _buildPlaybackActions,
        showQueueActions: false,
        coverUrl: track.artworkUrl,
        coverBytes: track.artworkBytes,
        title: track.title,
        subtitle: track.artist ?? '-',
        duration: track.duration,
        sourceLabel: AppI18n.format(config, 'song.source', {
          'platform': online
              ? resolvePlatformLabel(platform, platforms: platforms)
              : 'LOCAL',
        }),
        hasMv:
            online &&
            (track.mvId?.trim().isNotEmpty ?? false) &&
            track.mvId!.trim() != '0',
        onPlayNext: () => unawaited(controller.insertNextTrack(track)),
        onAddToPlaylist: () => unawaited(controller.appendTrack(track)),
        onAddToUserPlaylist: online
            ? () => unawaited(_addCurrentSongToUserPlaylist(track))
            : null,
        onDownload: online && qualities.isNotEmpty
            ? () => unawaited(
                _downloadCurrentTrack(
                  track: track,
                  platformId: platform,
                  qualities: qualities,
                  selectedQualityName: ref
                      .read(playerControllerProvider)
                      .currentSelectedQualityName,
                ),
              )
            : null,
        onViewDetail: canViewDetail
            ? () => navigate(AppRoutes.songDetail, {
                'id': track.id,
                'platform': platform,
                'title': track.title,
              })
            : null,
        onViewComment:
            online &&
                platformSupportsSongComment(
                  platformId: platform,
                  platforms: platforms,
                )
            ? () => navigate(AppRoutes.onlineComments, {
                'id': track.id,
                'platform': platform,
                'resource_type': 'song',
                'title': track.title,
              })
            : null,
        onViewSheetMusic:
            online &&
                canListSongSheetMusic(
                  songId: track.id,
                  platformId: platform,
                  platforms: platforms,
                )
            ? () => navigate(AppRoutes.songSheetMusic, {
                'song_id': track.id,
                'platform': platform,
                'title': track.title,
              })
            : null,
        albumActionLabel: canViewAlbum
            ? AppI18n.t(config, 'player.action.view_album')
            : null,
        onViewAlbum: canViewAlbum
            ? () => navigate(AppRoutes.albumDetail, {
                'id': track.albumId!.trim(),
                'platform': platform,
                'title': track.album ?? '',
              })
            : null,
        artistActionLabel: artistLabel,
        onViewArtists: artistLabel == null
            ? null
            : () => _openArtistSelectionAndGo(
                platformId: platform,
                artists: track.artists,
              ),
        onWatchMv: !online
            ? null
            : () => navigate(AppRoutes.videoDetail, {
                'id': track.mvId!.trim(),
                'platform': platform,
                'title': track.title,
              }),
        onCopySongName: () =>
            unawaited(copy(track.title, 'player.copy.name_done')),
        onCopySongId: () => unawaited(copy(track.id, 'player.copy.id_done')),
        onCopySongShareLink: online
            ? () => unawaited(
                copy(
                  buildShareLink(
                    type: 'song',
                    platform: platform,
                    id: track.id,
                  ),
                  'player.copy.share_done',
                ),
              )
            : null,
        onSearchSameName: searchPlatform == null || track.title.trim().isEmpty
            ? null
            : () => navigate(AppRoutes.onlineSearch, {
                'platform': searchPlatform,
                'keyword': track.title.trim(),
              }),
      ),
    );
  }

  Widget _buildPlaybackActions(BuildContext sheetContext) {
    final rootContext = context;
    var opening = false;
    return Consumer(
      builder: (context, ref, child) {
        final selection = ref.watch(
          playerControllerProvider.select(
            (state) => (
              track: state.currentTrack,
              speed: state.speed,
              volume: state.volume,
              quality: state.currentSelectedQualityName,
              qualities: state.currentAvailableQualities,
            ),
          ),
        );
        final locale = ref.watch(
          appConfigProvider.select((config) => config.localeCode),
        );
        String label(String key) => AppI18n.tByLocaleCode(locale, key);
        final controller = ref.read(playerControllerProvider.notifier);
        final track = selection.track;
        final platform = (track?.platform ?? '').trim();
        final online = platform.isNotEmpty && platform != 'local';
        final platforms = ref.watch(onlinePlatformsProvider).value;
        final displayQualities = online && track != null
            ? _buildSongQualityOptions(
                ref: ref,
                track: track,
                platformId: platform,
                platforms: platforms,
              )
            : selection.qualities;
        final quality = _findQualityOptionByName(
          displayQualities,
          selection.quality,
        );
        Future<void> open(VoidCallback action) async {
          if (opening) return;
          opening = true;
          final route = ModalRoute.of(sheetContext);
          Navigator.of(sheetContext).pop();
          await route?.completed;
          if (mounted && rootContext.mounted) action();
        }

        final rows = <Widget>[
          PlayerSheetActionTile(
            icon: Icons.speed_rounded,
            title: label('player.action.speed'),
            subtitle: '${selection.speed.toStringAsFixed(2)}x',
            onTap: () => unawaited(
              open(
                () => _openSpeedSheet(rootContext, controller, selection.speed),
              ),
            ),
          ),
          PlayerSheetActionTile(
            icon: Icons.volume_up_rounded,
            title: label('player.action.volume'),
            subtitle: '${(selection.volume * 100).round()}%',
            onTap: () => unawaited(
              open(
                () =>
                    _openVolumeSheet(rootContext, controller, selection.volume),
              ),
            ),
          ),
          PlayerSleepTimerActionTile(
            onTap: () =>
                unawaited(open(() => _openSleepTimerSheet(rootContext))),
          ),
          PlayerSheetActionTile(
            icon: Icons.palette_outlined,
            title: label('player.action.style'),
            onTap: () =>
                unawaited(open(() => _openPlayerStyleSheet(rootContext))),
          ),
          if (_usesMobileOrientationControls)
            PlayerSheetActionTile(
              icon: Icons.stay_current_landscape_rounded,
              title: label('player.action.landscape_mode'),
              onTap: () =>
                  unawaited(open(() => unawaited(_enterManualLandscape()))),
            ),
          PlayerSheetActionTile(
            icon: Icons.high_quality_rounded,
            title: label('player.action.quality'),
            subtitle: online ? quality?.name : track?.audioQualityLabel,
            enabled: online && selection.qualities.isNotEmpty,
            onTap: online && selection.qualities.isNotEmpty
                ? () => unawaited(
                    open(
                      () => unawaited(
                        _openCurrentQualitySheet(rootContext, controller),
                      ),
                    ),
                  )
                : null,
          ),
        ];
        return AppUiTheme.usesCupertino(context)
            ? PlayerSheetSection(
                title: label('player.more.playback'),
                children: rows,
              )
            : Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }

  void _openPlayerStyleSheet(BuildContext context) {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      fixedHeightFactor: PlayerStyleSelectionSheet.heightFactorOf(context),
      maxWidth: 640,
      showDragHandle: true,
      builder: (context) => PlayerStyleSelectionSheet(
        track: ref.read(playerControllerProvider).currentTrack,
      ),
    );
  }

  void _openSleepTimerSheet(BuildContext context) {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      fitContent: true,
      showDragHandle: true,
      builder: (context) => const PlayerSleepTimerSheet(),
    );
  }

  void _openSpeedSheet(
    BuildContext context,
    PlayerController controller,
    double current,
  ) {
    showPlayerStyledBottomSheet<void>(
      context: context,
      fitContent: true,
      heightFactor: LayoutTokens.playerActionSheetHeightFactor,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.5, 2.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                          if (AppUiTheme.usesCupertino(context))
                            const AppSheetCloseButton(),
                        ],
                      ),
                      AppSlider(
                        value: value,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label: '${value.toStringAsFixed(2)}x',
                        semanticFormatterCallback: (value) =>
                            '${value.toStringAsFixed(2)}x',
                        onChanged: (next) {
                          setState(() => value = next);
                        },
                        onChangeEnd: (next) {
                          controller.setSpeed(next);
                        },
                      ),
                      const SizedBox(height: 6),
                      AppButton.filled(
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
      AppMessageService.showSuccess(
        AppI18n.format(config, 'player.download.added', <String, String>{
          'title': track.title,
        }),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(AppI18n.t(config, 'player.download.failed'));
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
    showPlayerStyledBottomSheet<void>(
      context: context,
      fitContent: true,
      heightFactor: LayoutTokens.playerActionSheetHeightFactor,
      showDragHandle: true,
      builder: (sheetContext) {
        var value = current.clamp(0.0, 1.0);
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                          if (AppUiTheme.usesCupertino(context))
                            const AppSheetCloseButton(),
                        ],
                      ),
                      AppSlider(
                        value: value,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: '${(value * 100).round()}%',
                        semanticFormatterCallback: (value) =>
                            '${(value * 100).round()}%',
                        onChanged: (next) {
                          setState(() => value = next);
                        },
                        onChangeEnd: (next) {
                          controller.setVolume(next);
                        },
                      ),
                      const SizedBox(height: 6),
                      AppButton.filled(
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
    showPlayerStyledBottomSheet<void>(
      context: context,
      fitContent: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => PlayerQualitySelectionSheet(
        title: AppI18n.tByLocaleCode(
          Localizations.localeOf(sheetContext).languageCode,
          'player.quality.title',
        ),
        listKey: const ValueKey<String>('player-quality-sheet-list'),
        qualities: availableQualities,
        selectedQualityName: current,
        onSelected: (quality) {
          Navigator.of(sheetContext).pop();
          controller.switchCurrentQualityByName(quality.name);
        },
      ),
    );
  }

  /// 保留播放器作为详情页的返回目标。
  void _goToDetail(String location) {
    final route = ModalRoute.of(context);
    if (!mounted || route == null || !route.isActive || !route.isCurrent) {
      return;
    }
    unawaited(GoRouter.of(context).push(location));
  }

  bool _canOpenTrackArtist(PlayerTrack? track, List<OnlinePlatform> platforms) {
    if (track == null) {
      return false;
    }
    final platformId = (track.platform ?? '').trim();
    if (platformId == 'local') {
      return (track.artist ?? '').trim().isNotEmpty;
    }
    return platformSupportsArtistDetail(
          platformId: platformId,
          platforms: platforms,
        ) &&
        songArtistActionLabel(track.artists) != null;
  }

  void _openTrackArtist(PlayerTrack track) {
    final platformId = (track.platform ?? '').trim();
    if (platformId == 'local') {
      final artistName = (track.artist ?? '').trim();
      _goToDetail(
        Uri(
          path: AppRoutes.artistDetail,
          queryParameters: <String, String>{
            'id': artistName,
            'platform': platformId,
            'title': artistName,
          },
        ).toString(),
      );
      return;
    }
    _openArtistSelectionAndGo(platformId: platformId, artists: track.artists);
  }

  /// 弹出歌手选择面板，选择后在播放器上方打开歌手详情。
  Future<void> _openArtistSelectionAndGo({
    required String platformId,
    required List<SongInfoArtistInfo> artists,
  }) async {
    final available = artists
        .where((a) => a.id.trim().isNotEmpty && a.name.trim().isNotEmpty)
        .toList();
    if (available.isEmpty) {
      AppMessageService.showWarning(
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
    if (AppUiTheme.usesCupertino(context) && available.length <= 6) {
      final localeCode = Localizations.localeOf(context).languageCode;
      final artist = await showAdaptiveActionMenu<SongInfoArtistInfo>(
        context: context,
        title: Text(AppI18n.tByLocaleCode(localeCode, 'song.artist.select')),
        message: Text(
          AppI18n.formatByLocaleCode(localeCode, 'song.artist.count', {
            'count': '${available.length}',
          }),
        ),
        items: [
          for (final artist in available)
            AdaptiveActionMenuItem(value: artist, label: artist.name),
        ],
      );
      if (artist == null || !mounted) return;
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
      return;
    }
    showPlayerStyledBottomSheet<void>(
      context: context,
      fitContent: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _buildConstrainedPlayerSheetList(
          context: sheetContext,
          listKey: const ValueKey<String>('player-artist-selection-sheet-list'),
          children: <Widget>[
            for (final artist in available)
              AppListTile(
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
}

Widget _buildConstrainedPlayerSheetList({
  required BuildContext context,
  required List<Widget> children,
  Key? listKey,
  EdgeInsetsGeometry? padding,
}) {
  return SafeArea(
    child: ListView(
      key: listKey,
      shrinkWrap: true,
      padding: padding,
      children: children,
    ),
  );
}

@visibleForTesting
bool resolvePlayerArtistPhotoPortraitForTest(Size windowSize) {
  return windowSize.height >= windowSize.width;
}

@visibleForTesting
bool supportsPlayerOrientationControlsForTest({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb) return false;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

PlayerScenePalette? _resolvePlayerScenePalette(
  AppPlayerStageKind stageKind,
  List<Color> backdropColors,
) {
  return switch (stageKind) {
    AppPlayerStageKind.classic || AppPlayerStageKind.none =>
      classicPlayerScenePaletteFromBackdrop(backdropColors),
    AppPlayerStageKind.cassette => CassettePlayerPalette.fromBackdrop(
      backdropColors,
    ),
    AppPlayerStageKind.vinyl || AppPlayerStageKind.radialSpectrum => null,
  };
}

class _PlayerScenePaletteScope extends StatelessWidget {
  const _PlayerScenePaletteScope({required this.palette, required this.child});

  final PlayerScenePalette? palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    final base = Theme.of(context);
    final extensions = List<ThemeExtension<dynamic>>.of(base.extensions.values)
      ..removeWhere((extension) => extension is PlayerScenePalette);
    if (palette != null) {
      extensions.add(palette);
    }
    return AnimatedTheme(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      data: base.copyWith(extensions: extensions),
      child: child,
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.currentPage,
    required this.total,
    required this.showPageIndicator,
    required this.onClose,
    required this.onTapDot,
  });

  final int currentPage;
  final int total;
  final bool showPageIndicator;
  final VoidCallback onClose;
  final ValueChanged<int> onTapDot;

  @override
  Widget build(BuildContext context) {
    final palette = PlayerScenePalette.maybeOf(context);
    final foreground = palette?.foreground ?? Colors.white;
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onClose,
              style: IconButton.styleFrom(foregroundColor: foreground),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
          if (showPageIndicator)
            Row(
              key: const ValueKey<String>('player-page-indicator'),
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

class _PlayerMobileLandscapeLayout extends StatelessWidget {
  const _PlayerMobileLandscapeLayout({
    required this.noTrackText,
    required this.controller,
    required this.onSeek,
    required this.layoutSpec,
    required this.stageKind,
    required this.stageMaxWidth,
    required this.track,
    required this.lyrics,
    required this.exitLandscapeTooltip,
    required this.onExitLandscape,
    required this.onOpenArtist,
    required this.onOpenQueue,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final PlayerController controller;
  final Future<void> Function(Duration) onSeek;
  final PlayerLayoutSpec layoutSpec;
  final AppPlayerStageKind stageKind;
  final double stageMaxWidth;
  final PlayerTrack? track;
  final Widget lyrics;
  final String exitLandscapeTooltip;
  final VoidCallback onExitLandscape;
  final VoidCallback? onOpenArtist;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context) {
    final gap = layoutSpec.verticalGap;
    final palette = PlayerScenePalette.maybeOf(context);
    final usesCassetteLabel = stageKind == AppPlayerStageKind.cassette;
    final exitRail = SizedBox(
      key: const ValueKey<String>('player-mobile-landscape-exit-rail'),
      width: 48,
      child: Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          key: const ValueKey<String>('player-mobile-landscape-exit-button'),
          onPressed: onExitLandscape,
          tooltip: exitLandscapeTooltip,
          style: IconButton.styleFrom(
            foregroundColor: palette?.foreground ?? Colors.white,
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
    );
    final trackHeader = PlayerTrackHeader(
      noTrackText: noTrackText,
      artistSlotWidth: layoutSpec.artistSlotWidth,
      onOpenArtist: onOpenArtist,
      onOpenQuality: onOpenQuality,
      onOpenSpeed: onOpenSpeed,
      layout: PlayerTrackHeaderLayout.mobileLandscape,
    );
    final cassetteLabel = usesCassetteLabel
        ? PlayerTrackHeader(
            noTrackText: noTrackText,
            artistSlotWidth: layoutSpec.artistSlotWidth,
            onOpenArtist: null,
            onOpenQuality: onOpenQuality,
            onOpenSpeed: onOpenSpeed,
            layout: PlayerTrackHeaderLayout.cassetteLabel,
            showCassetteMetadataBadges: false,
          )
        : null;
    final controls = Row(
      key: const ValueKey<String>('player-mobile-landscape-controls'),
      children: <Widget>[
        Expanded(
          child: _PlayerControlSection(
            controller: controller,
            compactLayout: true,
            minimalLayout: true,
            onOpenQueue: onOpenQueue,
          ),
        ),
        const _PlayerFavoriteButton(),
      ],
    );

    return Row(
      key: const ValueKey<String>('player-mobile-landscape-layout'),
      children: <Widget>[
        exitRail,
        const SizedBox(width: 8),
        Expanded(
          key: const ValueKey<String>('player-mobile-landscape-stage'),
          flex: 2,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: gap),
                  child: PlayerStyleStage(
                    stageKind: stageKind,
                    track: track,
                    maxWidth: stageMaxWidth,
                    cassetteLabel: cassetteLabel,
                  ),
                ),
              ),
              _PlayerProgressSection(onSeek: onSeek),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          key: const ValueKey<String>('player-mobile-landscape-details'),
          flex: 3,
          child: Column(
            children: <Widget>[
              if (!usesCassetteLabel) ...<Widget>[
                trackHeader,
                SizedBox(height: gap),
              ],
              Expanded(child: lyrics),
              SizedBox(height: gap),
              controls,
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerMetaControlPage extends StatelessWidget {
  const _PlayerMetaControlPage({
    required this.noTrackText,
    required this.controller,
    required this.onSeek,
    required this.layoutSpec,
    required this.stageKind,
    required this.stageMaxWidth,
    required this.track,
    required this.onOpenArtist,
    required this.onOpenQueue,
    required this.onOpenMore,
    required this.onOpenLyrics,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final PlayerController controller;
  final Future<void> Function(Duration) onSeek;
  final PlayerLayoutSpec layoutSpec;
  final AppPlayerStageKind stageKind;
  final double stageMaxWidth;
  final PlayerTrack? track;
  final VoidCallback? onOpenArtist;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context) {
    final gap = layoutSpec.verticalGap;
    final usesCassetteLabel = stageKind == AppPlayerStageKind.cassette;
    final trackHeader = PlayerTrackHeader(
      noTrackText: noTrackText,
      artistSlotWidth: layoutSpec.artistSlotWidth,
      onOpenArtist: onOpenArtist,
      onOpenQuality: onOpenQuality,
      onOpenSpeed: onOpenSpeed,
      layout: usesCassetteLabel
          ? PlayerTrackHeaderLayout.cassetteLabel
          : PlayerTrackHeaderLayout.standard,
    );
    final cassetteLabel = usesCassetteLabel ? trackHeader : null;
    final utilityBar = _PlayerUtilityBar(onOpenMore: onOpenMore);
    final controls = <Widget>[
      utilityBar,
      _PlayerProgressSection(onSeek: onSeek),
      SizedBox(height: gap),
      _PlayerControlSection(
        controller: controller,
        compactLayout: true,
        onOpenQueue: onOpenQueue,
      ),
    ];

    final lyricPreview = KeyedSubtree(
      key: const ValueKey<String>('player-compact-lyric-preview'),
      child: PlayerCompactLyricSection(onTap: onOpenLyrics),
    );
    return Column(
      key: const ValueKey<String>('player-main-fixed-layout'),
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stageAspectRatio = stageKind == AppPlayerStageKind.cassette
                  ? cassettePlayerStageAspectRatio
                  : 1.0;
              final idealStageWidth = constraints.maxWidth < stageMaxWidth
                  ? constraints.maxWidth
                  : stageMaxWidth;
              final idealStageHeight = idealStageWidth / stageAspectRatio;
              final reservedInformationHeight =
                  PlayerCompactLyricSection.layoutHeight +
                  gap * 2 +
                  (usesCassetteLabel
                      ? 0
                      : PlayerTrackHeader.resolveLayoutHeight(context) + gap);
              final availableStageHeight =
                  constraints.maxHeight - reservedInformationHeight;
              final stageHeight = availableStageHeight <= 0
                  ? 0.0
                  : availableStageHeight < idealStageHeight
                  ? availableStageHeight
                  : idealStageHeight;

              return Column(
                children: <Widget>[
                  SizedBox(
                    height: stageHeight,
                    child: PlayerStyleStage(
                      stageKind: stageKind,
                      track: track,
                      maxWidth: stageMaxWidth,
                      cassetteLabel: cassetteLabel,
                    ),
                  ),
                  SizedBox(height: gap),
                  if (!usesCassetteLabel) ...<Widget>[
                    trackHeader,
                    SizedBox(height: gap),
                  ],
                  lyricPreview,
                  SizedBox(height: gap),
                  const Expanded(
                    child: SizedBox(
                      key: ValueKey<String>('player-info-control-spacer'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ...controls,
      ],
    );
  }
}

class _PlayerUtilityBar extends StatelessWidget {
  const _PlayerUtilityBar({required this.onOpenMore});

  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          const _PlayerFavoriteButton(),
          const Spacer(),
          _PlayerUtilityRow(onOpenMore: onOpenMore),
        ],
      ),
    );
  }
}

class _PlayerUtilityRow extends ConsumerWidget {
  const _PlayerUtilityRow({required this.onOpenMore});

  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrackTransitioning = ref.watch(
      playerControllerProvider.select((state) => state.isTrackTransitioning),
    );
    final palette = PlayerScenePalette.maybeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlayerUtilityButton(
          key: const ValueKey('player-more-button'),
          tooltip: AppI18n.tByLocaleCode(
            Localizations.localeOf(context).languageCode,
            'common.more',
          ),
          icon: Icons.more_horiz_rounded,
          color:
              palette?.foreground.withValues(alpha: 0.88) ??
              Colors.white.withValues(alpha: 0.82),
          onTap: isTrackTransitioning ? null : onOpenMore,
        ),
      ],
    );
  }
}

class _PlayerFavoriteButton extends ConsumerWidget {
  const _PlayerFavoriteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ref.watch(
      playerControllerProvider.select(
        (state) => (
          currentTrack: state.currentTrack,
          isTrackTransitioning: state.isTrackTransitioning,
        ),
      ),
    );
    final track = presentation.currentTrack;
    final platformId = (track?.platform ?? '').trim();
    final canOnline = platformId.isNotEmpty && platformId != 'local';

    if (!canOnline || track == null) {
      return const SizedBox(width: 44, height: 44);
    }

    final isFavorited = ref.watch(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: track.id, platform: platformId),
        ),
      ),
    );
    final palette = PlayerScenePalette.maybeOf(context);

    final color = isFavorited
        ? Colors.redAccent
        : palette?.foreground.withValues(alpha: 0.88) ??
              Colors.white.withValues(alpha: 0.82);

    return _PlayerUtilityButton(
      icon: isFavorited
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      color: color,
      onTap: presentation.isTrackTransitioning
          ? null
          : () async {
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
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 44,
      height: 44,
      child: Icon(icon, color: color, size: 22),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: Opacity(
        opacity: onTap == null ? 0.38 : 1,
        child: AppUiTheme.usesCupertino(context)
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: onTap,
                child: child,
              )
            : InkResponse(onTap: onTap, radius: 24, child: child),
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
    final bufferedPosition = ref.watch(
      playerControllerProvider.select((state) => state.bufferedPosition),
    );
    final isTrackTransitioning = ref.watch(
      playerControllerProvider.select((state) => state.isTrackTransitioning),
    );
    return PlayerProgressBar(
      position: position,
      bufferedPosition: bufferedPosition,
      duration: duration,
      onSeek: onSeek,
      enabled: !isTrackTransitioning,
    );
  }
}

class _PlayerControlSection extends ConsumerWidget {
  const _PlayerControlSection({
    required this.controller,
    required this.compactLayout,
    required this.onOpenQueue,
    this.minimalLayout = false,
  });

  final PlayerController controller;
  final bool compactLayout;
  final VoidCallback onOpenQueue;
  final bool minimalLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    final isTrackTransitioning = ref.watch(
      playerControllerProvider.select((state) => state.isTrackTransitioning),
    );
    return PlayerControlBar(
      localeCode: localeCode,
      compact: compactLayout,
      isPlaying: isPlaying,
      playMode: playMode,
      showPlayModeButton: !minimalLayout && !isRadioMode,
      playModeLocked: isRadioMode,
      isTrackTransitioning: isTrackTransitioning,
      showQueueButton: !minimalLayout && !isRadioMode,
      onOpenQueue: onOpenQueue,
      onCyclePlayMode: controller.cyclePlayMode,
      onPrevious: controller.playPrevious,
      onPlayPause: controller.togglePlayPause,
      onNext: controller.playNext,
    );
  }
}

class _PlayerWideVolumeControl extends ConsumerWidget {
  const _PlayerWideVolumeControl({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(
      playerControllerProvider.select((state) => state.volume),
    );
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final foreground =
        PlayerScenePalette.maybeOf(context)?.foreground ?? Colors.white;
    return Row(
      children: [
        Icon(
          volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: foreground.withValues(alpha: .72),
          size: 20,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: foreground,
              inactiveTrackColor: foreground.withValues(alpha: .2),
              thumbColor: foreground,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: AppSlider(
              key: const ValueKey('player-wide-volume'),
              activeColor: foreground,
              thumbColor: foreground,
              label: AppI18n.tByLocaleCode(locale, 'player.action.volume'),
              value: volume.clamp(0.0, 1.0),
              onChanged: (value) => unawaited(controller.setVolume(value)),
              semanticFormatterCallback: (value) => '${(value * 100).round()}%',
            ),
          ),
        ),
      ],
    );
  }
}
