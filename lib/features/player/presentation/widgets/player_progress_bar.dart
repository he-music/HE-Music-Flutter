import 'package:flutter/material.dart';

import '../../../../app/theme/player/styles/cassette_player_palette.dart';

const _defaultSliderMax = 1.0;

class PlayerProgressBar extends StatelessWidget {
  const PlayerProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.enabled = true,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final maxMillis = _maxDurationMillis(duration);
    final currentMillis = _clampPosition(position, maxMillis);
    final theme = Theme.of(context);
    final palette = CassettePlayerPalette.maybeOf(context);
    final activeColor = palette?.accent ?? Colors.white;
    final foreground = palette?.foreground ?? Colors.white;

    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: activeColor,
            inactiveTrackColor:
                palette?.edge.withValues(alpha: 0.22) ??
                Colors.white.withValues(alpha: 0.2),
            thumbColor: foreground,
            overlayColor: activeColor.withValues(alpha: 0.14),
          ),
          child: Slider(
            key: const ValueKey<String>('player-progress-slider'),
            value: currentMillis.toDouble(),
            max: maxMillis.toDouble(),
            onChanged: enabled
                ? (value) => onSeek(Duration(milliseconds: value.toInt()))
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              _formatDuration(position),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    palette?.secondaryForeground ??
                    Colors.white.withValues(alpha: 0.74),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    palette?.secondaryForeground ??
                    Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _maxDurationMillis(Duration input) {
    if (input <= Duration.zero) {
      return _defaultSliderMax.toInt();
    }
    return input.inMilliseconds;
  }

  int _clampPosition(Duration input, int maxMillis) {
    final current = input.inMilliseconds;
    if (current < 0) {
      return 0;
    }
    if (current > maxMillis) {
      return maxMillis;
    }
    return current;
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
    }
    return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }

  String _twoDigits(int value) {
    if (value >= 10) {
      return '$value';
    }
    return '0$value';
  }
}
