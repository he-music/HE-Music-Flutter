import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/player_play_mode.dart';
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
  @override
  Widget build(BuildContext context) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final hasQueue = ref.watch(
      playerControllerProvider.select((state) => state.queue.isNotEmpty),
    );
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final queue = ref.watch(
      playerControllerProvider.select((state) => state.queue),
    );
    final currentIndex = ref.watch(
      playerControllerProvider.select((state) => state.currentIndex),
    );
    final previousPreviewIndex = ref.watch(
      playerControllerProvider.select((state) => state.previousPreviewIndex),
    );
    final nextPreviewIndex = ref.watch(
      playerControllerProvider.select((state) => state.nextPreviewIndex),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    if (!hasQueue || track == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final bar = LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 58,
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
                      previousTrack: _previewTrackAt(
                        queue: queue,
                        currentIndex: currentIndex,
                        previewIndex: previousPreviewIndex,
                        isPrevious: true,
                        allowLinearFallback: playMode != PlayerPlayMode.shuffle,
                      ),
                      nextTrack: _previewTrackAt(
                        queue: queue,
                        currentIndex: currentIndex,
                        previewIndex: nextPreviewIndex,
                        isPrevious: false,
                        allowLinearFallback: playMode != PlayerPlayMode.shuffle,
                      ),
                      isRadioMode: isRadioMode,
                      onTap: widget.onOpenFullPlayer,
                      onPrevious: controller.playPrevious,
                      onNext: controller.playNext,
                    ),
                  ),
                  IconButton(
                    onPressed: controller.togglePlayPause,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    tooltip: AppI18n.t(config, 'player.full'),
                  ),
                  if (!isRadioMode)
                    IconButton(
                      onPressed: () => _openQueueSheet(context),
                      icon: const Icon(Icons.queue_music_rounded),
                      tooltip: AppI18n.t(config, 'player.queue'),
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

  PlayerTrack? _previewTrackAt({
    required List<PlayerTrack> queue,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlayerQueueSheet(),
    );
  }
}

class _TrackPageView extends StatefulWidget {
  const _TrackPageView({
    required this.track,
    required this.previousTrack,
    required this.nextTrack,
    required this.isRadioMode,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayerTrack track;
  final PlayerTrack? previousTrack;
  final PlayerTrack? nextTrack;
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
  int _lastPage = _initialPage;
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
    _lastPage = currentPage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
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
    );
  }

  void _handlePageChanged(int page) {
    if (_returningToAnchor) {
      _returningToAnchor = false;
      _lastPage = page;
      return;
    }
    final delta = page - _lastPage;
    if (delta == 0) {
      return;
    }
    if (delta > 0) {
      if (widget.nextTrack == null) {
        _returnToAnchor();
        return;
      }
      for (var index = 0; index < delta; index += 1) {
        widget.onNext();
      }
    } else {
      if (widget.previousTrack == null) {
        _returnToAnchor();
        return;
      }
      for (var index = 0; index < -delta; index += 1) {
        widget.onPrevious();
      }
    }
    _lastPage = page;
  }

  ({PlayerTrack? track, bool isCurrent}) _trackForPage(int page) {
    final delta = page - _anchorPage;
    if (delta == 0) {
      return (track: widget.track, isCurrent: true);
    }
    if (delta < 0) {
      return (track: widget.previousTrack, isCurrent: false);
    }
    return (track: widget.nextTrack, isCurrent: false);
  }

  int _currentControllerPage() {
    if (!_controller.hasClients) {
      return _lastPage;
    }
    return (_controller.page ?? _lastPage.toDouble()).round();
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

  String _trackKey(PlayerTrack track) {
    return '${track.platform ?? ''}-${track.id}';
  }
}

class _TrackPage extends StatelessWidget {
  const _TrackPage({
    required this.track,
    required this.isRadioMode,
    required this.onTap,
  });

  final PlayerTrack? track;
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

  final PlayerTrack track;
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
          (track.artist ?? '-').trim().isEmpty ? '-' : (track.artist ?? '-'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
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
