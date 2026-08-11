import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/app_message_service.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../domain/entities/player_play_mode.dart';
import '../../domain/entities/player_playback_state.dart';
import '../../domain/entities/player_track.dart';
import '../providers/player_providers.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'player_queue_sheet.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({
    required this.onOpenFullPlayer,
    this.bottomSafeArea = false,
    super.key,
  });

  final VoidCallback onOpenFullPlayer;
  final bool bottomSafeArea;

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> {
  final _selectionProjector = _MiniPlayerSelectionProjector();

  @override
  Widget build(BuildContext context) {
    ref.listen(
      playerControllerProvider.select((state) => state.playbackFailure),
      (previous, next) {
        if (next == null ||
            next.transitionId == previous?.transitionId ||
            next.message.trim().isEmpty) {
          return;
        }
        AppMessageService.showError(
          next.message,
          actionLabel: next.retryable
              ? AppI18n.tByLocaleCode(
                  ref.read(appConfigProvider).localeCode,
                  'common.retry',
                )
              : null,
          onAction: next.retryable
              ? () => unawaited(
                  ref
                      .read(playerControllerProvider.notifier)
                      .retryCurrentPlayback()
                      .catchError((_) {}),
                )
              : null,
        );
      },
    );
    final player = ref.watch(
      playerControllerProvider.select(_selectionProjector.project),
    );
    final localeCode = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    final controller = ref.read(playerControllerProvider.notifier);
    final track = player.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }
    final bar = LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: AppSkinSurface(
            role: AppSkinSurfaceRole.miniPlayer,
            child: SizedBox(
              height: 52,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onOpenFullPlayer,
                    child: _CoverImage(
                      url: track.artworkUrl,
                      bytes: track.artworkBytes,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TrackPageView(
                      track: track,
                      queue: player.queue,
                      currentIndex: player.currentIndex,
                      previousTrack: _previewTrackAt(
                        queue: player.queue,
                        currentIndex: player.currentIndex,
                        previewIndex: player.previousPreviewIndex,
                        isPrevious: true,
                        allowLinearFallback:
                            player.playMode != PlayerPlayMode.shuffle,
                      ),
                      nextTrack: _previewTrackAt(
                        queue: player.queue,
                        currentIndex: player.currentIndex,
                        previewIndex: player.nextPreviewIndex,
                        isPrevious: false,
                        allowLinearFallback:
                            player.playMode != PlayerPlayMode.shuffle,
                      ),
                      usesLinearOrder:
                          player.playMode != PlayerPlayMode.shuffle,
                      isRadioMode: player.isRadioMode,
                      onTap: widget.onOpenFullPlayer,
                      onPrevious: controller.playPrevious,
                      onNext: controller.playNext,
                    ),
                  ),
                  IconButton(
                    onPressed: controller.togglePlayPause,
                    icon: AppSkinIcon(
                      role: player.isPlaying
                          ? AppSkinIconRole.miniPlayerPause
                          : AppSkinIconRole.miniPlayerPlay,
                    ),
                    tooltip: AppI18n.tByLocaleCode(localeCode, 'player.full'),
                  ),
                  if (!player.isRadioMode)
                    IconButton(
                      onPressed: () => _openQueueSheet(context),
                      icon: const AppSkinIcon(
                        role: AppSkinIconRole.miniPlayerQueue,
                      ),
                      tooltip: AppI18n.tByLocaleCode(
                        localeCode,
                        'player.queue',
                      ),
                    ),
                  const SizedBox(width: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!widget.bottomSafeArea) {
      return bar;
    }
    return SafeArea(top: false, child: bar);
  }

  _MiniPlayerTrack? _previewTrackAt({
    required List<_MiniPlayerTrack> queue,
    required int currentIndex,
    required int? previewIndex,
    required bool isPrevious,
    required bool allowLinearFallback,
  }) {
    if (queue.length < 2) {
      return null;
    }
    if (previewIndex != null &&
        previewIndex >= 0 &&
        previewIndex < queue.length &&
        previewIndex != currentIndex) {
      return queue[previewIndex];
    }
    if (!allowLinearFallback) {
      return null;
    }
    final fallbackIndex = isPrevious
        ? (currentIndex - 1 + queue.length) % queue.length
        : (currentIndex + 1) % queue.length;
    return fallbackIndex == currentIndex ? null : queue[fallbackIndex];
  }

  void _openQueueSheet(BuildContext context) {
    showAppThemedBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }
}

class _TrackPageView extends StatefulWidget {
  const _TrackPageView({
    required this.track,
    required this.queue,
    required this.currentIndex,
    required this.previousTrack,
    required this.nextTrack,
    required this.usesLinearOrder,
    required this.isRadioMode,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final _MiniPlayerTrack track;
  final List<_MiniPlayerTrack> queue;
  final int currentIndex;
  final _MiniPlayerTrack? previousTrack;
  final _MiniPlayerTrack? nextTrack;
  final bool usesLinearOrder;
  final bool isRadioMode;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_TrackPageView> createState() => _TrackPageViewState();
}

class _TrackPageViewState extends State<_TrackPageView> {
  static const int _initialPage = 10000;

  late final PageController _controller;
  int _anchorPage = _initialPage;
  int _settledPage = _initialPage;
  int _pendingPage = _initialPage;
  bool _returningToAnchor = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _TrackPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_trackKey(oldWidget.track) == _trackKey(widget.track)) {
      return;
    }
    final currentPage = _currentControllerPage();
    _anchorPage = currentPage;
    _settledPage = currentPage;
    _pendingPage = currentPage;
    _returningToAnchor = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _handleScrollEnd,
        child: PageView.builder(
          controller: _controller,
          physics: widget.previousTrack == null && widget.nextTrack == null
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            final pageTrack = _trackForPage(index);
            return _TrackPage(
              track: pageTrack.track,
              isRadioMode: pageTrack.isCurrent && widget.isRadioMode,
              onTap: widget.onTap,
            );
          },
        ),
      ),
    );
  }

  void _handlePageChanged(int page) {
    // PageView 越过中线就会回调；先只更新预览，抬手并停稳后再切歌。
    _pendingPage = page;
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_returningToAnchor) {
      if (_pendingPage == _anchorPage) {
        _returningToAnchor = false;
        _settledPage = _anchorPage;
      }
      return false;
    }
    final delta = _pendingPage - _settledPage;
    if (delta == 0) {
      return false;
    }
    if (delta > 0) {
      if (widget.nextTrack == null) {
        _returnToAnchor();
        return false;
      }
      for (var index = 0; index < delta; index += 1) {
        widget.onNext();
      }
    } else {
      if (widget.previousTrack == null) {
        _returnToAnchor();
        return false;
      }
      for (var index = 0; index < -delta; index += 1) {
        widget.onPrevious();
      }
    }
    _settledPage = _pendingPage;
    return false;
  }

  ({_MiniPlayerTrack? track, bool isCurrent}) _trackForPage(int page) {
    final delta = page - _anchorPage;
    if (delta == 0) {
      return (track: widget.track, isCurrent: true);
    }
    if (widget.usesLinearOrder && widget.queue.isNotEmpty) {
      final index = (widget.currentIndex + delta) % widget.queue.length;
      return (track: widget.queue[index], isCurrent: false);
    }
    if (delta < 0) {
      return (track: widget.previousTrack, isCurrent: false);
    }
    return (track: widget.nextTrack, isCurrent: false);
  }

  int _currentControllerPage() {
    if (!_controller.hasClients) {
      return _settledPage;
    }
    return (_controller.page ?? _settledPage.toDouble()).round();
  }

  void _returnToAnchor() {
    if (!_controller.hasClients) {
      return;
    }
    _returningToAnchor = true;
    _controller.animateToPage(
      _anchorPage,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  String _trackKey(_MiniPlayerTrack track) {
    return '${track.platform}-${track.id}';
  }
}

class _TrackPage extends StatelessWidget {
  const _TrackPage({
    required this.track,
    required this.isRadioMode,
    required this.onTap,
  });

  final _MiniPlayerTrack? track;
  final bool isRadioMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = track;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: item == null
            ? const SizedBox.shrink()
            : _TrackText(track: item, isRadioMode: isRadioMode),
      ),
    );
  }
}

class _TrackText extends StatelessWidget {
  const _TrackText({required this.track, required this.isRadioMode});

  final _MiniPlayerTrack track;
  final bool isRadioMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isRadioMode) ...<Widget>[
              const SizedBox(width: 6),
              _MiniRadioModeIcon(theme: theme),
            ],
          ],
        ),
        Text(
          track.artist.trim().isEmpty ? '-' : track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

typedef _MiniPlayerTrack = ({
  String id,
  String platform,
  String title,
  String artist,
  String? artworkUrl,
  Uint8List? artworkBytes,
});

// 只比较迷你播放器实际展示字段，忽略时长写回产生的新队列对象。
class _MiniPlayerSelection {
  const _MiniPlayerSelection({
    required this.queue,
    required this.currentIndex,
    required this.previousPreviewIndex,
    required this.nextPreviewIndex,
    required this.playMode,
    required this.isPlaying,
    required this.isRadioMode,
  });

  factory _MiniPlayerSelection.fromState(
    PlayerPlaybackState state,
    List<_MiniPlayerTrack> queue,
  ) {
    return _MiniPlayerSelection(
      queue: queue,
      currentIndex: state.currentIndex,
      previousPreviewIndex: state.previousPreviewIndex,
      nextPreviewIndex: state.nextPreviewIndex,
      playMode: state.playMode,
      isPlaying: state.isPlaying,
      isRadioMode: state.isRadioMode,
    );
  }

  final List<_MiniPlayerTrack> queue;
  final int currentIndex;
  final int? previousPreviewIndex;
  final int? nextPreviewIndex;
  final PlayerPlayMode playMode;
  final bool isPlaying;
  final bool isRadioMode;

  _MiniPlayerTrack? get currentTrack {
    if (currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }

  @override
  bool operator ==(Object other) {
    return other is _MiniPlayerSelection &&
        listEquals(queue, other.queue) &&
        currentIndex == other.currentIndex &&
        previousPreviewIndex == other.previousPreviewIndex &&
        nextPreviewIndex == other.nextPreviewIndex &&
        playMode == other.playMode &&
        isPlaying == other.isPlaying &&
        isRadioMode == other.isRadioMode;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(queue),
    currentIndex,
    previousPreviewIndex,
    nextPreviewIndex,
    playMode,
    isPlaying,
    isRadioMode,
  );
}

class _MiniPlayerSelectionProjector {
  List<PlayerTrack>? _sourceQueue;
  List<_MiniPlayerTrack> _projectedQueue = const <_MiniPlayerTrack>[];

  _MiniPlayerSelection project(PlayerPlaybackState state) {
    if (!identical(_sourceQueue, state.queue)) {
      _sourceQueue = state.queue;
      _projectedQueue = state.queue
          .map(_miniPlayerTrackOf)
          .toList(growable: false);
    }
    return _MiniPlayerSelection.fromState(state, _projectedQueue);
  }
}

_MiniPlayerTrack _miniPlayerTrackOf(PlayerTrack track) {
  return (
    id: track.id,
    platform: track.platform ?? '',
    title: track.title,
    artist: track.artist ?? '',
    artworkUrl: track.artworkUrl,
    artworkBytes: track.artworkBytes,
  );
}

class _MiniRadioModeIcon extends StatelessWidget {
  const _MiniRadioModeIcon({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          Icons.radio_rounded,
          size: 12,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.bytes});

  final String? url;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, error, stackTrace) => Container(
            width: 46,
            height: 46,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.music_note_rounded),
          ),
        ),
      );
    }
    if (url == null || url!.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: const Icon(Icons.music_note_rounded),
      );
    }
    // 本地缓存文件路径 vs 网络 URL
    final isLocalPath = url!.startsWith('/');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isLocalPath
          ? Image.file(
              File(url!),
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, error, stackTrace) => Container(
                width: 46,
                height: 46,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.music_note_rounded),
              ),
            )
          : AppNetworkImage(
              url: url!,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              cacheWidth: 128,
              fallback: Container(
                width: 46,
                height: 46,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.music_note_rounded),
              ),
            ),
    );
  }
}
