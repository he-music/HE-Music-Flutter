import 'package:flutter/material.dart';

const _defaultSliderMax = 1.0;

class PlayerProgressBar extends StatelessWidget {
  const PlayerProgressBar({
    required this.position,
    this.bufferedPosition = Duration.zero,
    required this.duration,
    required this.onSeek,
    this.enabled = true,
    super.key,
  });

  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final maxMillis = _maxDurationMillis(duration);
    final currentMillis = _clampPosition(position, maxMillis);
    final bufferedMillis = _clampPosition(
      bufferedPosition > position ? bufferedPosition : position,
      maxMillis,
    );
    final theme = Theme.of(context);

    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: Colors.white,
            secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.32),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.14),
          ),
          child: Slider(
            key: const ValueKey<String>('player-progress-slider'),
            value: currentMillis.toDouble(),
            secondaryTrackValue: bufferedMillis.toDouble(),
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
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
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
