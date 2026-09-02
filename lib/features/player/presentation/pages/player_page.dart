import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_route_observers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../app/theme/player/app_player_style_models.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../app/theme/player/styles/cassette_player_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../../core/device/screen_wake_lock.dart';
import '../../../../core/audio/audio_sleep_timer.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/helpers/user_playlist_song_action_helper.dart';
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
import '../controllers/realtime_spectrum_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../layout/player_layout_spec.dart';
import '../layout/player_responsive_layout.dart';
import '../providers/player_audio_provider.dart';
import '../providers/player_providers.dart';
import '../providers/player_sleep_timer_provider.dart';
import '../styles/player_style_stage.dart';
import '../styles/player_track_header.dart';
import '../widgets/monet_lyric_page.dart';
import '../widgets/partita_lyric_page.dart';
import '../widgets/player_backdrop.dart';
import '../widgets/player_compact_lyric_section.dart';
import '../widgets/player_control_bar.dart';
import '../widgets/player_lyric_page.dart';
import '../widgets/player_more_sheet_widgets.dart';
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

enum _PlayerMoreAction { openStyleSelection, enterLandscape }

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
  Widget build(BuildContext context) {
    widget.debugOnBuild?.call();
    final config = ref.watch(
      appConfigProvider.select(
        (state) =>
            (playerStyleId: state.playerStyleId, localeCode: state.localeCode),
      ),
    );
    final playerStyle = AppPlayerStyleRegistry.instance.resolve(
      config.playerStyleId,
    );
    final scenePalette = _resolvePlayerScenePalette(
      playerStyle.stageKind,
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
      MediaQuery.sizeOf(context),
    );
    final allowMobileLandscape = _usesMobileOrientationControls;
    final currentLayoutMode = PlayerLayoutSpec.resolve(
      BoxConstraints.tight(MediaQuery.sizeOf(context)),
      allowMobileLandscape: allowMobileLandscape,
    ).mode;
    final isMobileLandscape =
        currentLayoutMode == PlayerLayoutMode.mobileLandscape;
    _usesRealtimeSpectrum = playerStyle.usesRealtimeSpectrum;
    _scheduleSpectrumVisibilitySync();
    final landscapeSafeMinimum = isMobileLandscape
        ? resolvePlayerLandscapeContentInsets(
            resolvePlayerLandscapeSafeInsets(
              size: MediaQuery.sizeOf(context),
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
    Widget buildLyricPage() {
      final lyricPage = PlayerLyricPage(
        key: _lyricPageKey,
        emptyText: AppI18n.tByLocaleCode(
          config.localeCode,
          'player.lyrics.empty',
        ),
        onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
        artworkUrl: presentation.currentTrack?.artworkUrl,
        artworkBytes: presentation.currentTrack?.artworkBytes,
        center: false,
      );
      return switch (playerStyle.lyricsKind) {
        AppPlayerLyricsKind.legacy => lyricPage,
        AppPlayerLyricsKind.monet => MonetLyricPage(
          emptyText: AppI18n.tByLocaleCode(
            config.localeCode,
            'player.lyrics.empty',
          ),
          onSeek: presentation.isTrackTransitioning ? null : seekFromLyric,
          palette: scenePalette,
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
      };
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
              child: PlayerBackdrop(
                stageKind: playerStyle.stageKind,
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
                    topBarBuilder: (context, spec) => _PlayerTopBar(
                      currentPage: _currentPage,
                      total: _pageCount,
                      showPageIndicator:
                          spec.mode == PlayerLayoutMode.mobilePortrait,
                      onClose: () => unawaited(_closePlayer()),
                      onTapDot: _animateToPage,
                    ),
                    mainPlayerBuilder: (context, spec) =>
                        _PlayerMetaControlPage(
                          noTrackText: AppI18n.tByLocaleCode(
                            config.localeCode,
                            'player.noTrack',
                          ),
                          controller: controller,
                          onSeek: seek,
                          layoutSpec: spec,
                          stageKind: playerStyle.stageKind,
                          stageMaxWidth: playerStyle.geometry.stageMaxWidth,
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
                          stageKind: playerStyle.stageKind,
                          stageMaxWidth: playerStyle.geometry.stageMaxWidth,
                          track: displayedTrack,
                          lyrics: buildLyricPage(),
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
    final stageVisible =
        mode != PlayerLayoutMode.mobilePortrait || _currentPage == 0;
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
    if (_usesMobileOrientationControls) {
      _orientationPreference = _PlayerOrientationPreference.systemManaged;
      await Future.wait<void>(<Future<void>>[
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]),
        _restoreDefaultSystemUi(force: true),
      ]);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _openQueueSheet() {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }

  void _openMoreSheet() {
    final rootContext = context;
    unawaited(
      showPlayerStyledBottomSheet<_PlayerMoreAction>(
        context: context,
        isScrollControlled: true,
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
              playerControllerProvider.select(
                (s) => s.currentAvailableQualities,
              ),
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
            final sleepTimerPort = ref.watch(sleepTimerAudioPortProvider);
            final sleepTimer = ref.watch(sleepTimerStateProvider).value;
            var sleepTimerNow = DateTime.now();
            if (sleepTimer != null &&
                sleepTimer.isActive &&
                !sleepTimer.waitingForTrackEnd) {
              sleepTimerNow =
                  ref.watch(sleepTimerNowProvider).value ?? sleepTimerNow;
            }
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

            return _buildConstrainedPlayerSheetList(
              context: sheetContext,
              listKey: const ValueKey<String>('player-more-sheet-list'),
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
                  icon: Icons.bedtime_rounded,
                  title: AppI18n.t(config, 'player.sleep_timer.title'),
                  subtitle: formatSleepTimerSummary(
                    config,
                    sleepTimer ?? SleepTimerState.inactive,
                    sleepTimerNow,
                  ),
                  enabled: sleepTimerPort != null,
                  onTap: sleepTimerPort == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _openSleepTimerSheet(rootContext);
                        },
                ),
                PlayerSheetActionTile(
                  icon: Icons.palette_outlined,
                  title: AppI18n.t(config, 'player.action.style'),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop(_PlayerMoreAction.openStyleSelection);
                  },
                ),
                if (_usesMobileOrientationControls)
                  PlayerSheetActionTile(
                    icon: Icons.stay_current_landscape_rounded,
                    title: AppI18n.t(config, 'player.action.landscape_mode'),
                    onTap: () {
                      Navigator.of(
                        sheetContext,
                      ).pop(_PlayerMoreAction.enterLandscape);
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
                  subtitle: canOnline
                      ? currentSelectedQualityOption?.name
                      : track?.audioQualityLabel,
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
                      AppMessageService.showSuccess(
                        AppI18n.t(config, 'player.copy.share_done'),
                      );
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
                          AppMessageService.showSuccess(
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
                          AppMessageService.showSuccess(
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
            );
          },
        ),
      ).then((action) {
        if (action == null || !mounted || !rootContext.mounted) {
          return;
        }
        switch (action) {
          case _PlayerMoreAction.openStyleSelection:
            _openPlayerStyleSheet(rootContext);
          case _PlayerMoreAction.enterLandscape:
            unawaited(_enterManualLandscape());
        }
      }),
    );
  }

  void _openPlayerStyleSheet(BuildContext context) {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerStyleSelectionSheet(),
    );
  }

  void _openSleepTimerSheet(BuildContext context) {
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _buildConstrainedPlayerSheetList(
          context: sheetContext,
          listKey: const ValueKey<String>('player-quality-sheet-list'),
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
        );
      },
    );
  }

  /// 关闭播放器后把详情页压入根 Navigator。
  ///
  /// 播放器和详情页都在根 navigator，使用 push 保留来源页面的返回栈。
  void _goToDetail(String location) {
    Navigator.of(context).pop();
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

  /// 弹出歌手选择面板，选择后关闭播放器并导航到歌手详情。
  void _openArtistSelectionAndGo({
    required String platformId,
    required List<SongInfoArtistInfo> artists,
  }) {
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
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _buildConstrainedPlayerSheetList(
          context: sheetContext,
          listKey: const ValueKey<String>('player-artist-selection-sheet-list'),
          maxHeightFactor: LayoutTokens.artistSelectionSheetMaxHeightFactor,
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

Widget _buildConstrainedPlayerSheetList({
  required BuildContext context,
  required List<Widget> children,
  Key? listKey,
  EdgeInsetsGeometry? padding,
  double maxHeightFactor = LayoutTokens.actionSheetMaxHeightFactor,
}) {
  final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;
  return SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        key: listKey,
        shrinkWrap: true,
        padding: padding,
        children: children,
      ),
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
    AppPlayerStageKind.classic => classicPlayerScenePaletteFromBackdrop(
      backdropColors,
    ),
    AppPlayerStageKind.cassette => CassettePlayerPalette.fromBackdrop(
      backdropColors,
    ),
    _ => null,
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

    if (stageKind == AppPlayerStageKind.artistPhoto) {
      return Stack(
        key: const ValueKey<String>('player-mobile-landscape-layout'),
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        key: const ValueKey<String>(
                          'player-mobile-landscape-artist-photo-content',
                        ),
                        width: constraints.maxWidth * 0.64,
                        child: Column(
                          children: <Widget>[
                            trackHeader,
                            SizedBox(height: gap),
                            Expanded(child: lyrics),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: gap),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: _PlayerProgressSection(onSeek: onSeek),
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: controls),
                  ],
                ),
              ),
            ],
          ),
          Align(alignment: Alignment.topLeft, child: exitRail),
        ],
      );
    }

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
        compactLayout: !layoutSpec.isDesktop,
        onOpenQueue: onOpenQueue,
      ),
    ];

    if (layoutSpec.isDesktop) {
      return Column(
        key: const ValueKey<String>('player-main-fixed-layout'),
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: gap),
              child: PlayerStyleStage(
                stageKind: stageKind,
                track: track,
                maxWidth: stageMaxWidth,
                cassetteLabel: cassetteLabel,
              ),
            ),
          ),
          SizedBox(height: gap),
          if (!usesCassetteLabel) ...<Widget>[
            trackHeader,
            SizedBox(height: gap),
          ],
          ...controls,
        ],
      );
    }

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
                      : PlayerTrackHeader.layoutHeight + gap);
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
      height: 40,
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
      return const SizedBox(width: 40, height: 40);
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
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: color, size: 22),
        ),
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
