import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../online/presentation/pages/online_comments_page.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_link.dart';
import '../../domain/entities/video_detail_request.dart';
import '../../playback/controllers/video_playback_controller.dart';
import '../../playback/entities/video_playback_surface.dart';
import '../../playback/providers/video_playback_surface_provider.dart';
import '../providers/video_detail_providers.dart';
import '../providers/video_feed_providers.dart';

void _debugVideoDetail(String message) {
  if (!kDebugMode) return;
  debugPrint('[VideoDetail] $message');
}

/// 抖音式 MV 详情页：全屏沉浸，上下滑动切换视频。
class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage>
    with WidgetsBindingObserver {
  static const SystemUiOverlayStyle _videoOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );
  static const double _commentsExpandedVideoFraction = 0.38;
  static const Duration _commentsTransitionDuration = Duration(
    milliseconds: 320,
  );
  static const Duration _orientationRestoreTimeout = Duration(
    milliseconds: 300,
  );

  late final PageController _pageController;

  /// 每个索引对应的视频详情（包含播放链接）。
  final Map<int, VideoDetailContent> _details = {};

  /// 列表级视频播放控制器，页面只负责把交互意图转交给它。
  late final VideoPlaybackController _playbackController;

  /// 每个索引的详情加载状态。
  final Map<int, _ItemLoadState> _itemStates = {};

  /// 已完成首帧渲染的页索引。首帧前用封面承接黑屏等待。
  final Set<int> _firstFrameRenderedIndexes = <int>{};

  int _currentIndex = 0;
  bool _controlsVisible = true;
  bool _showingComments = false;
  bool _commentsFullscreen = false;
  MvInfo? _commentVideo;
  Timer? _controlsTimer;
  Future<void>? _pendingPlaybackPageChange;

  // 全屏手势相关
  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;
  double? _initialApplicationBrightness;
  double? _currentApplicationBrightness;

  static const Duration _controlsAutoHideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _playbackController = VideoPlaybackController(
      surfaceFactory: ref.read(videoPlaybackSurfaceFactoryProvider),
      uriBuilder: _buildVideoUri,
    )..addListener(_handlePlaybackChanged);
    // 暂停音乐播放器，加载首个视频详情
    Future.microtask(() async {
      final playerState = ref.read(playerControllerProvider);
      if (playerState.isPlaying) {
        await ref.read(playerControllerProvider.notifier).togglePlayPause();
      }
      await _initializeFirstVideo();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _pageController.dispose();
    _playbackController.removeListener(_handlePlaybackChanged);
    _playbackController.dispose();
    unawaited(_restoreWindowModeAndBrightness());
    super.dispose();
  }

  void _handlePlaybackChanged() {
    if (mounted) setState(() {});
  }

  @override
  Future<bool> didPopRoute() {
    return _handleSystemBack();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _debugVideoDetail('metrics changed ${_windowSizeLabel()}');
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(videoFeedControllerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _videoOverlayStyle,
      child: PopScope(
        canPop: !_showingComments,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          unawaited(_handleSystemBack());
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildContent(feedState),
        ),
      ),
    );
  }

  Widget _buildContent(dynamic feedState) {
    // feed 列表为空时，根据首个视频的加载状态决定显示
    if (feedState.videos.isEmpty) {
      final firstState = _itemStates[0];
      final body = firstState == _ItemLoadState.error
          ? _buildErrorView(
              AppI18n.t(ref.read(appConfigProvider), 'video.feed.load_failed'),
            )
          : _buildLoadingView();
      // feed 为空时也需要返回按钮，避免加载失败后无法退出
      return ColoredBox(
        key: const ValueKey<String>('video-detail-exclusive-media-surface'),
        color: Colors.black,
        child: Stack(
          children: <Widget>[
            body,
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: _BackButton(onTap: _handleBack),
            ),
          ],
        ),
      );
    }
    return _buildPageView(feedState);
  }

  Widget _buildPageView(dynamic feedState) {
    final videos = feedState.videos as List<MvInfo>;
    final screenSize = MediaQuery.sizeOf(context);
    final videoHeight = _showingComments
        ? (_commentsFullscreen
              ? 0.0
              : screenSize.height * _commentsExpandedVideoFraction)
        : screenSize.height;
    final commentsHeight = screenSize.height - videoHeight;

    return Stack(
      children: <Widget>[
        // 视频区域：评论展开时联动收缩到上半屏，而不是额外盖一层假缩略图。
        AnimatedPositioned(
          key: const ValueKey<String>('video-detail-page-view'),
          duration: _commentsTransitionDuration,
          curve: Curves.easeOutCubic,
          top: 0,
          left: 0,
          right: 0,
          height: videoHeight,
          child: IgnorePointer(
            ignoring: _showingComments,
            child: ClipRect(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: _showingComments
                    ? const NeverScrollableScrollPhysics()
                    : null,
                itemCount: videos.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _buildVideoPage(index, videos[index]);
                },
              ),
            ),
          ),
        ),
        if (_showingComments && !_commentsFullscreen)
          Positioned(
            key: const ValueKey<String>('video-detail-comments-hit-area'),
            top: 0,
            left: 0,
            right: 0,
            height: videoHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideComments,
            ),
          ),
        // 顶部返回按钮（评论时由评论面板自己的控制栏提供）
        if (!_showingComments)
          Positioned(
            key: const ValueKey<String>('video-detail-back-button'),
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: _BackButton(onTap: _handleBack),
          ),
        // 加载更多指示器
        if (feedState.loadingMore)
          const Positioned(
            key: ValueKey<String>('video-detail-loading-more'),
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        // 评论面板：仅占下半屏，和顶部真实视频区域联动展开。
        if (_commentVideo != null)
          Positioned(
            key: const ValueKey<String>('video-detail-comments-panel'),
            left: 0,
            right: 0,
            bottom: 0,
            height: commentsHeight,
            child: AnimatedSlide(
              offset: _showingComments ? Offset.zero : const Offset(0, 1),
              duration: _commentsTransitionDuration,
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !_showingComments,
                child: _buildCommentsPanel(),
              ),
            ),
          ),
      ],
    );
  }

  /// 评论面板：承接在底部半屏，顶部视频由真实 PageView 联动收缩。
  Widget _buildCommentsPanel() {
    final topRadius = _commentsFullscreen
        ? Radius.zero
        : const Radius.circular(20);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: topRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: topRadius),
        child: OnlineCommentsPage(
          resourceId: _commentVideo!.id,
          resourceType: 'mv',
          platform: _commentVideo!.platform,
          title: _commentVideo!.name,
          embedMode: true,
          commentsFullscreen: _commentsFullscreen,
          onClose: _hideComments,
          onToggleFullscreen: _toggleCommentsFullscreen,
        ),
      ),
    );
  }

  Widget _buildVideoPage(int index, MvInfo video) {
    final detail = _details[index];
    final player = _playbackController.surfaceForPage(index);
    final itemState = _itemStates[index] ?? _ItemLoadState.idle;
    final isCurrentPage = index == _currentIndex;
    final coverUrl = (detail?.info.cover ?? video.cover).trim();
    final showCoverPoster =
        coverUrl.isNotEmpty && !_firstFrameRenderedIndexes.contains(index);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildVideoSurface(player: player, isCurrentPage: isCurrentPage),
        if (showCoverPoster)
          _VideoCoverPoster(
            url: coverUrl,
            aspectRatio: player?.state.aspectRatio,
          ),
        // 加载中
        if (itemState == _ItemLoadState.loading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        // 加载失败
        if (itemState == _ItemLoadState.error)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  AppI18n.t(
                    ref.read(appConfigProvider),
                    'video.feed.load_failed',
                  ),
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _loadDetailForIndex(index),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: Text(
                    AppI18n.tByLocaleCode(
                      Localizations.localeOf(context).languageCode,
                      'common.retry',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        if (isCurrentPage && !_showingComments)
          _buildOverlay(video, detail, player),
        // 居中播放/暂停按钮
        if (isCurrentPage &&
            !_showingComments &&
            player != null &&
            player.state.isInitialized)
          _buildCenterPlayPause(player),
      ],
    );
  }

  /// 底部视频信息 + 右侧操作按钮。
  Widget _buildVideoSurface({
    required VideoPlaybackSurface? player,
    required bool isCurrentPage,
  }) {
    final view = _VideoPlayerView(
      player: player,
      controls: _surfaceControlsForContext(),
      materialControlsTheme: _materialControlsThemeFor(
        player,
        title: _currentVideoTitle(),
      ),
    );
    return GestureDetector(
      onTap: isCurrentPage ? _handleVideoTap : null,
      child: view,
    );
  }

  /// 底部视频信息 + 右侧操作按钮。
  Widget _buildOverlay(
    MvInfo video,
    VideoDetailContent? detail,
    VideoPlaybackSurface? player,
  ) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _controlsVisible ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                // 左侧：标题、作者、进度条
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        video.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: <Shadow>[
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      if (video.creator.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          video.creator.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            shadows: const <Shadow>[
                              Shadow(blurRadius: 6, color: Colors.black45),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (player != null && player.state.isInitialized)
                        _VideoProgressBar(
                          player: player,
                          onSeek: (position) => unawaited(
                            _playbackController.seekCurrent(position),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 右侧操作栏
                _buildActionButtons(video, detail),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 居中播放/暂停按钮，点击切换播放状态。
  Widget _buildCenterPlayPause(VideoPlaybackSurface player) {
    // 仅在暂停时显示居中播放按钮
    final show = _controlsVisible && !player.state.isPlaying;
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: show ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !show,
          child: GestureDetector(
            onTap: _resumeFromCenterButton,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                player.state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 右侧竖排操作按钮。
  Widget _buildActionButtons(MvInfo video, VideoDetailContent? detail) {
    final config = ref.read(appConfigProvider);
    final selectedLink = _selectedLink(detail);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 音质切换
        if (detail != null && detail.links.length > 1)
          _ActionButton(
            icon: Icons.high_quality_rounded,
            label: selectedLink?.qualityLabel ?? '',
            onTap: () => _showQualitySheet(detail),
          ),
        if (detail != null && detail.links.length > 1)
          const SizedBox(height: 20),
        // 评论
        _ActionButton(
          icon: Icons.comment_outlined,
          label: AppI18n.t(config, 'video.feed.comment'),
          onTap: () => _showComments(video),
        ),
        const SizedBox(height: 20),
        // 全屏
        _ActionButton(
          icon: Icons.fullscreen_rounded,
          label: '',
          onTap: _toggleFullscreen,
        ),
      ],
    );
  }

  VideoSurfaceControls _surfaceControlsForContext() {
    return VideoSurfaceControls.materialFullscreenOnly;
  }

  MaterialVideoControlsThemeData? _materialControlsThemeFor(
    VideoPlaybackSurface? player, {
    required String title,
  }) {
    if (player == null) {
      return null;
    }
    return MaterialVideoControlsThemeData().copyWith(
      brightnessGesture: true,
      volumeGesture: true,
      seekGesture: true,
      seekOnDoubleTap: true,
      visibleOnMount: true,
      initialBrightness: _currentApplicationBrightness ?? 0.5,
      onBrightnessChanged: (value) {
        _currentApplicationBrightness = value;
        unawaited(_screenBrightness.setApplicationScreenBrightness(value));
      },
      onBrightnessReset: () => unawaited(_restoreApplicationBrightness()),
      initialVolume: (player.state.volume / 100).clamp(0.0, 1.0).toDouble(),
      onVolumeChanged: (value) {
        unawaited(player.setVolume((value * 100).clamp(0.0, 100.0)));
      },
      topButtonBarMargin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      topButtonBar: <Widget>[
        Builder(
          builder: (buttonContext) {
            return AppBackButton(
              key: const ValueKey<String>(
                'video-detail-fullscreen-back-button',
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              iconColor: Colors.white,
              iconSize: 20,
              onPressed: () async {
                await exitFullscreen(buttonContext);
                unawaited(_restoreWindowModeAndBrightness());
              },
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              shadows: <Shadow>[Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }

  String _currentVideoTitle() {
    final feedState = ref.read(videoFeedControllerProvider);
    final videos = feedState.videos;
    if (_currentIndex >= 0 && _currentIndex < videos.length) {
      final title = videos[_currentIndex].name.trim();
      if (title.isNotEmpty) return title;
    }
    return widget.title.trim();
  }

  // ────────────── 页面切换 & 视频生命周期 ──────────────

  /// 初始化流程：先调 Detail 播放当前 MV，再根据平台 flag 加载 feed 追加。
  Future<void> _initializeFirstVideo() async {
    setState(() => _itemStates[0] = _ItemLoadState.loading);
    try {
      final request = VideoDetailRequest(
        id: widget.id,
        platform: widget.platform,
        title: widget.title,
      );
      final content = await ref
          .read(videoDetailRepositoryProvider)
          .fetchDetail(request);
      if (!mounted) return;

      _details[0] = content;
      _itemStates[0] = _ItemLoadState.loaded;
      _firstFrameRenderedIndexes.remove(0);

      // 用 detail 构造 MvInfo 放入 feed 列表作为第一项
      final mvInfo = content.info;
      ref.read(videoFeedControllerProvider.notifier).setInitialVideo(mvInfo);

      await _playbackController.initialize(
        contents: <VideoDetailContent>[content],
        initialIndex: 0,
      );
      _trackFirstFrame(0);
      unawaited(_loadDetailForIndex(1));

      // 平台支持 feed 则异步加载更多（不阻塞当前播放）
      if (ref.read(videoFeedControllerProvider.notifier).supportsFeed) {
        unawaited(ref.read(videoFeedControllerProvider.notifier).loadFeed());
      }
    } catch (e) {
      if (!mounted) return;
      _itemStates[0] = _ItemLoadState.error;
      setState(() {});
    }
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    _pendingPlaybackPageChange = _handlePlaybackPageChanged(index);
    // 预加载相邻页详情
    _loadDetailForIndex(index);
    _loadDetailForIndex(index + 1);
    _loadDetailForIndex(index - 1);
    ref.read(videoFeedControllerProvider.notifier).onPageChanged(index);
    _showControlsTemporarily();
  }

  Future<void> _handlePlaybackPageChanged(int index) async {
    try {
      await _playbackController.onPageChanged(index);
    } catch (_) {
      if (!mounted) return;
      setState(() => _itemStates[index] = _ItemLoadState.error);
    }
  }

  Future<void> _loadDetailForIndex(int index) async {
    if (index < 0 ||
        _details.containsKey(index) ||
        _itemStates[index] == _ItemLoadState.loading) {
      return;
    }
    final feedState = ref.read(videoFeedControllerProvider);
    if (index >= feedState.videos.length) return;

    final video = feedState.videos[index];
    setState(() => _itemStates[index] = _ItemLoadState.loading);

    try {
      // feed 已携带 links 时直接复用，省去一次 detail 请求
      VideoDetailContent content;
      if (video.links.isNotEmpty) {
        content = VideoDetailContent(info: video, links: video.links);
      } else {
        final request = VideoDetailRequest(
          id: video.id,
          platform: video.platform,
          title: video.name,
        );
        content = await ref
            .read(videoDetailRepositoryProvider)
            .fetchDetail(request);
      }
      if (!mounted) return;

      _details[index] = content;
      _itemStates[index] = _ItemLoadState.loaded;
      _firstFrameRenderedIndexes.remove(index);
      await _playbackController.updateContent(
        pageIndex: index,
        content: content,
        autoplay: index == _currentIndex,
      );
      _trackFirstFrame(index);

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      _itemStates[index] = _ItemLoadState.error;
      if (mounted) setState(() {});
    }
  }

  VideoDetailLink? _selectedLink(VideoDetailContent? content) {
    if (content == null || content.links.isEmpty) return null;
    final currentSlot = _playbackController.state.currentSlot;
    final selectedQualityKey = currentSlot?.contentId == content.id
        ? currentSlot?.selectedQualityKey
        : null;
    if (selectedQualityKey != null) {
      for (final link in content.links) {
        if (link.cacheKey == selectedQualityKey) return link;
      }
    }
    final sorted = <VideoDetailLink>[...content.links]
      ..sort((a, b) => b.quality.compareTo(a.quality));
    return sorted.first;
  }

  Uri _buildVideoUri(VideoDetailContent content, VideoDetailLink link) {
    if (link.url.trim().isNotEmpty) {
      return Uri.parse(link.url.trim());
    }
    final config = ref.read(appConfigProvider);
    final baseUri = Uri.parse(config.apiBaseUrl.trim());
    return baseUri.replace(
      path: '/v1/mv/url',
      queryParameters: <String, String>{
        'id': content.id,
        'platform': content.platform,
        'quality': '${link.quality}',
        'format': link.format.isEmpty ? 'mp4' : link.format,
        'redirect': 'true',
        'token': config.authToken ?? '',
      },
    );
  }

  void _trackFirstFrame(int index) {
    final player = _playbackController.surfaceForPage(index);
    if (player == null || _firstFrameRenderedIndexes.contains(index)) return;
    unawaited(
      player.waitUntilFirstFrameRendered.then((_) {
        if (!mounted) return;
        setState(() => _firstFrameRenderedIndexes.add(index));
      }),
    );
  }

  // ────────────── 播放控制 ──────────────

  /// 单击视频区域：播放中 → 暂停并显示控件；已暂停 → 恢复播放并隐藏。
  void _handleVideoTap() {
    final player = _playbackController.currentSurface;
    if (player == null || !player.state.isInitialized) return;
    if (player.state.isPlaying) {
      unawaited(_playbackController.pauseCurrent());
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      unawaited(_playbackController.playCurrent());
      _showControlsTemporarily();
    }
  }

  /// 居中按钮恢复播放，图标立即消失。
  void _resumeFromCenterButton() {
    final player = _playbackController.currentSurface;
    if (player == null || !player.state.isInitialized) return;
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = false);
    if (!player.state.isPlaying) {
      unawaited(_playbackController.playCurrent());
    }
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    final player = _playbackController.currentSurface;
    if (player?.state.isPlaying ?? false) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted) return;
      final player = _playbackController.currentSurface;
      if (player == null || !player.state.isPlaying) return;
      setState(() => _controlsVisible = false);
    });
  }

  // ────────────── 全屏 ──────────────

  Future<void> _toggleFullscreen() async {
    await _pendingPlaybackPageChange;
    if (!mounted) return;
    unawaited(_primeFullscreenGestureValues());
    await _playbackController.currentSurface?.enterFullscreen();
  }

  Future<void> _restoreWindowModeAndBrightness({
    bool restoreOrientation = true,
  }) async {
    await _restoreApplicationBrightness();
    if (!mounted) return;

    // 方向控制按平台判断，不能按横屏后的宽度断点判断，否则手机横屏会被误判为桌面端。
    if (_usesMobileVideoOrientationControls) {
      if (restoreOrientation) await _restoreOrientationBeforeFullscreen();
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  Future<void> _restoreOrientationBeforeFullscreen() async {
    if (!mounted || !_usesMobileVideoOrientationControls) {
      _debugVideoDetail(
        'skip orientation restore mounted=$mounted mobileOrientation=$_usesMobileVideoOrientationControls ${_windowSizeLabel()}',
      );
      return;
    }
    const orientations = <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];
    // 视频流第一版固定回到竖屏，避免退出后停留在横屏布局。
    _debugVideoDetail(
      'request restore orientation $orientations ${_windowSizeLabel()}',
    );
    await SystemChrome.setPreferredOrientations(
      orientations,
    ).timeout(_orientationRestoreTimeout, onTimeout: () {});
    _debugVideoDetail(
      'restore orientation request completed ${_windowSizeLabel()}',
    );
  }

  String _windowSizeLabel() {
    final view = View.maybeOf(context);
    if (view == null) return 'view=unavailable';
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    final orientation = logicalSize.width > logicalSize.height
        ? 'landscape'
        : 'portrait';
    return 'view=${logicalSize.width.toStringAsFixed(0)}x${logicalSize.height.toStringAsFixed(0)} $orientation';
  }

  bool get _usesMobileVideoOrientationControls =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _primeFullscreenGestureValues() async {
    try {
      final brightness = await _screenBrightness.application;
      _initialApplicationBrightness ??= brightness;
      _currentApplicationBrightness = brightness;
    } catch (_) {}
  }

  Future<void> _restoreApplicationBrightness() async {
    final initialBrightness = _initialApplicationBrightness;
    _initialApplicationBrightness = null;
    _currentApplicationBrightness = null;
    if (initialBrightness == null) return;
    try {
      await _screenBrightness.setApplicationScreenBrightness(initialBrightness);
    } catch (_) {}
  }

  // ────────────── 评论 & 音质 Sheet ──────────────

  void _showComments(MvInfo video) {
    setState(() {
      _showingComments = true;
      _commentsFullscreen = false;
      _commentVideo = video;
    });
  }

  void _hideComments() {
    setState(() {
      _showingComments = false;
      _commentsFullscreen = false;
      _commentVideo = null;
    });
  }

  void _toggleCommentsFullscreen() {
    setState(() {
      _commentsFullscreen = !_commentsFullscreen;
    });
  }

  void _showQualitySheet(VideoDetailContent content) {
    final selectedLink = _selectedLink(content);
    final config = ref.read(appConfigProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  AppI18n.t(config, 'video.detail.quality_switch'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final link in content.links)
                ListTile(
                  leading: Icon(
                    link.quality >= 1080
                        ? Icons.videocam_rounded
                        : Icons.videocam_outlined,
                    color: selectedLink?.cacheKey == link.cacheKey
                        ? Theme.of(sheetContext).colorScheme.primary
                        : null,
                  ),
                  title: Text(link.qualityLabel),
                  subtitle: link.format.trim().isNotEmpty
                      ? Text(link.format.trim().toUpperCase())
                      : null,
                  trailing: selectedLink?.cacheKey == link.cacheKey
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _switchQuality(link);
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchQuality(VideoDetailLink link) async {
    final index = _currentIndex;
    setState(() => _itemStates[index] = _ItemLoadState.loading);
    await _playbackController.switchQuality(link);
    if (mounted) {
      setState(() => _itemStates[index] = _ItemLoadState.loaded);
    }
  }

  // ────────────── 导航 ──────────────

  Future<void> _handleBack() async {
    if (await _handleSystemBack()) return;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<bool> _handleSystemBack() async {
    if (_showingComments) {
      _hideComments();
      return true;
    }
    return false;
  }

  // ────────────── 工具方法 ──────────────

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 12),
          Text(
            AppI18n.t(ref.read(appConfigProvider), 'video.feed.loading'),
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _initializeFirstVideo,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
              ),
              child: Text(
                AppI18n.tByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'common.retry',
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────── 视频播放器视图 ──────────────

class _VideoCoverPoster extends StatelessWidget {
  const _VideoCoverPoster({required this.url, required this.aspectRatio});

  final String url;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio ?? 16 / 9,
        child: AppNetworkImage(
          url: url,
          key: const ValueKey<String>('video-detail-cover'),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          fallback: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerView extends StatelessWidget {
  const _VideoPlayerView({
    required this.player,
    required this.controls,
    required this.materialControlsTheme,
  });

  final VideoPlaybackSurface? player;
  final VideoSurfaceControls controls;
  final MaterialVideoControlsThemeData? materialControlsTheme;

  @override
  Widget build(BuildContext context) {
    final isReady = player != null && player!.state.isInitialized;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (isReady)
            Center(
              child: AspectRatio(
                aspectRatio: player!.state.aspectRatio,
                child: player!.buildView(
                  controls: controls,
                  materialControlsTheme: materialControlsTheme,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────── 进度条 ──────────────

class _VideoProgressBar extends StatefulWidget {
  const _VideoProgressBar({required this.player, required this.onSeek});

  final VideoPlaybackSurface? player;
  final ValueChanged<Duration> onSeek;

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.player?.addListener(_listener!);
  }

  @override
  void didUpdateWidget(covariant _VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player == widget.player || _listener == null) return;
    oldWidget.player?.removeListener(_listener!);
    widget.player?.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) {
      widget.player?.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    if (player == null) {
      return const SizedBox.shrink();
    }
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (value) {
          final target = Duration(
            milliseconds: (value * duration.inMilliseconds).round(),
          );
          widget.onSeek(target);
        },
      ),
    );
  }
}

// ────────────── 操作按钮 ──────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                shadows: const <Shadow>[
                  Shadow(blurRadius: 4, color: Colors.black54),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────── 返回按钮 ──────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppBackButton(
      onPressed: onTap,
      iconColor: Colors.white,
      backgroundColor: Colors.black.withValues(alpha: 0.26),
      iconSize: 18,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
  }
}

// ────────────── 加载状态枚举 ──────────────

enum _ItemLoadState { idle, loading, loaded, error }
