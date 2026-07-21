import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marquee/marquee.dart';

import '../../domain/entities/player_quality_option.dart';
import '../providers/player_providers.dart';

class PlayerTrackHeader extends ConsumerWidget {
  const PlayerTrackHeader({
    required this.noTrackText,
    required this.artistSlotWidth,
    required this.onOpenQuality,
    required this.onOpenSpeed,
    super.key,
  });

  final String noTrackText;
  final double artistSlotWidth;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  /// 共享播放器布局用于预留固定歌曲信息槽位的高度。
  static const double layoutHeight = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final qualities = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentAvailableQualities,
      ),
    );
    final qualityName = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentSelectedQualityName,
      ),
    );
    final speed = ref.watch(
      playerControllerProvider.select((state) => state.speed),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    final quality = _findQualityByName(qualities, qualityName);
    final title = track?.title.trim().isNotEmpty == true
        ? track!.title.trim()
        : noTrackText;
    final artist = track?.artist?.trim().isNotEmpty == true
        ? track!.artist!.trim()
        : '-';
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

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
                  child: _OverflowMarquee(text: artist),
                ),
                const SizedBox(width: 8),
                if (quality != null) ...<Widget>[
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

class _OverflowMarquee extends StatelessWidget {
  const _OverflowMarquee({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );
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
            key: const ValueKey<String>('player-artist-static'),
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: style,
            ),
          );
        }
        return Marquee(
          key: const ValueKey<String>('player-artist-marquee'),
          text: text,
          style: style,
          blankSpace: 28,
          velocity: 24,
          pauseAfterRound: const Duration(seconds: 1),
          startAfter: const Duration(milliseconds: 600),
          fadingEdgeStartFraction: 0.04,
          fadingEdgeEndFraction: 0.04,
        );
      },
    );
  }
}

class _PlayerMetadataBadge extends StatelessWidget {
  const _PlayerMetadataBadge({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.7,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              fontSize: 10,
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
