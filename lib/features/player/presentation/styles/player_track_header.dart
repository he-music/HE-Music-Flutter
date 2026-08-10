import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marquee/marquee.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/styles/cassette_player_palette.dart';
import '../../domain/entities/player_quality_option.dart';
import '../providers/player_providers.dart';

enum PlayerTrackHeaderLayout { standard, mobileLandscape, cassetteLabel }

class PlayerTrackHeader extends ConsumerWidget {
  const PlayerTrackHeader({
    required this.noTrackText,
    required this.artistSlotWidth,
    required this.onOpenQuality,
    required this.onOpenSpeed,
    this.onOpenArtist,
    this.layout = PlayerTrackHeaderLayout.standard,
    this.showCassetteMetadataBadges = true,
    super.key,
  });

  final String noTrackText;
  final double artistSlotWidth;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;
  final VoidCallback? onOpenArtist;
  final PlayerTrackHeaderLayout layout;
  final bool showCassetteMetadataBadges;

  /// 共享播放器布局用于预留固定歌曲信息槽位的高度。
  static const double layoutHeight = 58;
  static const double mobileLandscapeLayoutHeight = 40;
  static const double mobileLandscapeContentInset = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ref.watch(
      playerControllerProvider.select(
        (state) => (
          displayTrack: state.displayTrack,
          isTrackTransitioning: state.isTrackTransitioning,
        ),
      ),
    );
    final track = presentation.displayTrack;
    final title = track?.title.trim().isNotEmpty == true
        ? track!.title.trim()
        : noTrackText;
    final artist = track?.artist?.trim().isNotEmpty == true
        ? track!.artist!.trim()
        : '-';
    final cassettePalette = CassettePlayerPalette.maybeOf(context);
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: cassettePalette?.foreground ?? Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    if (layout == PlayerTrackHeaderLayout.mobileLandscape) {
      return SizedBox(
        key: const ValueKey<String>('player-track-header'),
        height: mobileLandscapeLayoutHeight,
        child: Padding(
          key: const ValueKey<String>('player-landscape-track-content'),
          padding: const EdgeInsets.symmetric(
            horizontal: mobileLandscapeContentInset,
          ),
          child: _ArtistAction(
            onTap: onOpenArtist,
            child: _OverflowMarquee(
              text: '$title - $artist',
              style: titleStyle,
              staticKey: const ValueKey<String>(
                'player-landscape-track-static',
              ),
              marqueeKey: const ValueKey<String>(
                'player-landscape-track-marquee',
              ),
              startAfter: const Duration(seconds: 5),
              pauseAfterRound: const Duration(seconds: 5),
              pauseAtStart: true,
            ),
          ),
        ),
      );
    }

    final needsFullMetadata =
        layout != PlayerTrackHeaderLayout.cassetteLabel ||
        showCassetteMetadataBadges;
    final qualities = needsFullMetadata
        ? ref.watch(
            playerControllerProvider.select(
              (state) => state.currentAvailableQualities,
            ),
          )
        : const <PlayerQualityOption>[];
    final qualityName = needsFullMetadata
        ? ref.watch(
            playerControllerProvider.select(
              (state) => state.currentSelectedQualityName,
            ),
          )
        : null;
    final speed = needsFullMetadata
        ? ref.watch(playerControllerProvider.select((state) => state.speed))
        : 1.0;
    final isRadioMode = needsFullMetadata
        ? ref.watch(
            playerControllerProvider.select((state) => state.isRadioMode),
          )
        : false;
    final quality = _findQualityByName(qualities, qualityName);
    if (layout == PlayerTrackHeaderLayout.cassetteLabel) {
      final palette = cassettePalette ?? CassettePlayerPalette.fallback;
      return LayoutBuilder(
        key: const ValueKey<String>('player-cassette-track-header'),
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 42;
          final titleHeight = showCassetteMetadataBadges
              ? (compact ? 15.0 : 18.0)
              : 13.0;
          final artistHeight = showCassetteMetadataBadges
              ? (compact ? 16.0 : 19.0)
              : 13.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: titleHeight,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        key: const ValueKey<String>('player-track-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.foreground,
                          fontSize: showCassetteMetadataBadges
                              ? (compact ? 10 : 12)
                              : 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (presentation.isTrackTransitioning)
                      Semantics(
                        liveRegion: true,
                        label: AppI18n.format(
                          ref.watch(appConfigProvider),
                          'player.transition.preparing_track',
                          <String, String>{'title': title},
                        ),
                        child: SizedBox.square(
                          key: const ValueKey<String>(
                            'player-track-preparing-indicator',
                          ),
                          dimension: compact ? 10 : 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: palette.edge,
                          ),
                        ),
                      ),
                    if (showCassetteMetadataBadges && isRadioMode) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.radio_rounded,
                        size: compact ? 10 : 12,
                        color: palette.edge,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                height: showCassetteMetadataBadges ? (compact ? 1 : 2) : 1,
              ),
              SizedBox(
                height: artistHeight,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _ArtistAction(
                        onTap: onOpenArtist,
                        child: Text(
                          artist,
                          key: const ValueKey<String>('player-cassette-artist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.secondaryForeground,
                            fontSize: showCassetteMetadataBadges
                                ? (compact ? 8 : 10)
                                : 8,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    if (showCassetteMetadataBadges) const SizedBox(width: 5),
                    if (showCassetteMetadataBadges &&
                        quality != null &&
                        !presentation.isTrackTransitioning) ...<Widget>[
                      _PlayerMetadataBadge(
                        key: const ValueKey<String>('player-quality-badge'),
                        label: quality.name,
                        onTap: onOpenQuality,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (showCassetteMetadataBadges)
                      _PlayerMetadataBadge(
                        key: const ValueKey<String>('player-speed-badge'),
                        label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
                        onTap: onOpenSpeed,
                        compact: true,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }
    return SizedBox(
      key: const ValueKey<String>('player-track-header'),
      height: layoutHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey<String>('player-track-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              SizedBox(
                key: const ValueKey<String>('player-track-preparing-slot'),
                width: 26,
                height: 18,
                child: presentation.isTrackTransitioning
                    ? Semantics(
                        liveRegion: true,
                        label: AppI18n.format(
                          ref.watch(appConfigProvider),
                          'player.transition.preparing_track',
                          <String, String>{'title': title},
                        ),
                        child: const Center(
                          child: SizedBox.square(
                            key: ValueKey<String>(
                              'player-track-preparing-indicator',
                            ),
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              if (isRadioMode) ...<Widget>[
                const SizedBox(width: 8),
                const _PlayerRadioModeIcon(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            child: Row(
              children: <Widget>[
                SizedBox(
                  key: const ValueKey<String>('player-artist-slot'),
                  width: artistSlotWidth,
                  child: _ArtistAction(
                    onTap: onOpenArtist,
                    child: _OverflowMarquee(
                      text: artist,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      staticKey: const ValueKey<String>('player-artist-static'),
                      marqueeKey: const ValueKey<String>(
                        'player-artist-marquee',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (quality != null &&
                    !presentation.isTrackTransitioning) ...<Widget>[
                  _PlayerMetadataBadge(
                    key: const ValueKey<String>('player-quality-badge'),
                    label: quality.name,
                    onTap: onOpenQuality,
                  ),
                  const SizedBox(width: 6),
                ],
                _PlayerMetadataBadge(
                  key: const ValueKey<String>('player-speed-badge'),
                  label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
                  onTap: onOpenSpeed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PlayerQualityOption? _findQualityByName(
    List<PlayerQualityOption> options,
    String? name,
  ) {
    for (final option in options) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }
}

class _ArtistAction extends StatelessWidget {
  const _ArtistAction({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }
    return InkWell(
      key: const ValueKey<String>('player-artist-action'),
      onTap: onTap,
      child: child,
    );
  }
}

class _OverflowMarquee extends StatelessWidget {
  const _OverflowMarquee({
    required this.text,
    required this.style,
    required this.staticKey,
    required this.marqueeKey,
    this.startAfter = const Duration(milliseconds: 600),
    this.pauseAfterRound = const Duration(seconds: 1),
    this.pauseAtStart = false,
  });

  final String text;
  final TextStyle? style;
  final Key staticKey;
  final Key marqueeKey;
  final Duration startAfter;
  final Duration pauseAfterRound;
  final bool pauseAtStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return Align(
            key: staticKey,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: style,
            ),
          );
        }
        const blankSpace = 28.0;
        const velocity = 24.0;
        if (pauseAtStart) {
          return _StartAlignedMarquee(
            key: marqueeKey,
            text: text,
            style: style,
            textWidth: painter.width.ceilToDouble(),
            textScaler: MediaQuery.textScalerOf(context),
            blankSpace: blankSpace,
            velocity: velocity,
            startAfter: startAfter,
            pauseAfterRound: pauseAfterRound,
          );
        }
        return Marquee(
          key: marqueeKey,
          text: text,
          style: style,
          blankSpace: blankSpace,
          velocity: velocity,
          pauseAfterRound: pauseAfterRound,
          startAfter: startAfter,
          fadingEdgeStartFraction: 0.04,
          fadingEdgeEndFraction: 0.04,
        );
      },
    );
  }
}

class _StartAlignedMarquee extends StatefulWidget {
  const _StartAlignedMarquee({
    required this.text,
    required this.style,
    required this.textWidth,
    required this.textScaler,
    required this.blankSpace,
    required this.velocity,
    required this.startAfter,
    required this.pauseAfterRound,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final double textWidth;
  final TextScaler textScaler;
  final double blankSpace;
  final double velocity;
  final Duration startAfter;
  final Duration pauseAfterRound;

  @override
  State<_StartAlignedMarquee> createState() => _StartAlignedMarqueeState();
}

class _StartAlignedMarqueeState extends State<_StartAlignedMarquee> {
  final ScrollController _controller = ScrollController();
  Timer? _pauseTimer;
  Completer<void>? _pauseCompleter;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _StartAlignedMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.textWidth != widget.textWidth ||
        oldWidget.textScaler != widget.textScaler ||
        oldWidget.blankSpace != widget.blankSpace ||
        oldWidget.velocity != widget.velocity ||
        oldWidget.startAfter != widget.startAfter ||
        oldWidget.pauseAfterRound != widget.pauseAfterRound) {
      _restart();
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancelPause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('player-landscape-track-scroll'),
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: <Widget>[
          _buildText(copyForSemantics: true),
          SizedBox(width: widget.blankSpace),
          ExcludeSemantics(child: _buildText(copyForSemantics: false)),
        ],
      ),
    );
  }

  Widget _buildText({required bool copyForSemantics}) {
    return SizedBox(
      width: widget.textWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: copyForSemantics
            ? Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: widget.style,
                textScaler: widget.textScaler,
              )
            : Text.rich(
                TextSpan(text: widget.text, style: widget.style),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textScaler: widget.textScaler,
              ),
      ),
    );
  }

  void _restart() {
    _cancelPause();
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrent(generation) || !_controller.hasClients) return;
      _controller.jumpTo(0);
      unawaited(_run(generation));
    });
  }

  Future<void> _run(int generation) async {
    var pause = widget.startAfter;
    while (_isCurrent(generation)) {
      if (pause > Duration.zero) {
        await _waitForPause(pause);
      }
      if (!_isCurrent(generation) || !_controller.hasClients) return;

      final target = math.min(
        widget.textWidth + widget.blankSpace,
        _controller.position.maxScrollExtent,
      );
      if (target <= 0) return;
      final duration = Duration(
        milliseconds: math.max(1, (target / widget.velocity * 1000).round()),
      );
      await _controller.animateTo(
        target,
        duration: duration,
        curve: Curves.linear,
      );
      if (!_isCurrent(generation) || !_controller.hasClients) return;

      // 第二份文本到达首位时立即归零，视觉位置不变，暂停点始终是完整标题开头。
      _controller.jumpTo(0);
      pause = widget.pauseAfterRound;
    }
  }

  Future<void> _waitForPause(Duration duration) {
    final completer = Completer<void>();
    _pauseCompleter = completer;
    _pauseTimer = Timer(duration, () {
      if (!identical(_pauseCompleter, completer)) return;
      _pauseTimer = null;
      _pauseCompleter = null;
      completer.complete();
    });
    return completer.future;
  }

  void _cancelPause() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final completer = _pauseCompleter;
    _pauseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;
}

class _PlayerMetadataBadge extends StatelessWidget {
  const _PlayerMetadataBadge({
    required this.label,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CassettePlayerPalette.maybeOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  palette?.edge.withValues(alpha: 0.46) ??
                  Colors.white.withValues(alpha: 0.22),
              width: 0.7,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  palette?.foreground.withValues(alpha: 0.92) ??
                  Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              fontSize: compact ? 8 : 10,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRadioModeIcon extends StatelessWidget {
  const _PlayerRadioModeIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.7,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.radio_rounded, size: 13, color: Colors.white),
      ),
    );
  }
}
