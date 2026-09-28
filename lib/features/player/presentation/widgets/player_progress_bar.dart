import 'dart:async';

import 'package:flutter/material.dart';

const _defaultSliderMax = 1.0;

class PlayerProgressBar extends StatefulWidget {
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
  final FutureOr<void> Function(Duration) onSeek;
  final bool enabled;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _dragMillis;
  int _seekRevision = 0;

  Future<void> _commitSeek(double value) async {
    final revision = ++_seekRevision;
    setState(() => _dragMillis = value);
    try {
      await widget.onSeek(Duration(milliseconds: value.round()));
    } finally {
      if (mounted && revision == _seekRevision) {
        setState(() => _dragMillis = null);
      }
    }
  }

  @override
  void didUpdateWidget(PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.duration != oldWidget.duration) {
      _seekRevision++;
      _dragMillis = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMillis = _maxDurationMillis(widget.duration);
    final previewPosition = _dragMillis == null
        ? widget.position
        : Duration(milliseconds: _dragMillis!.round());
    final currentMillis = _clampPosition(previewPosition, maxMillis);
    final bufferedMillis = _clampPosition(
      widget.bufferedPosition > previewPosition
          ? widget.bufferedPosition
          : previewPosition,
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
            onChangeStart: widget.enabled
                ? (value) {
                    _seekRevision++;
                    setState(() => _dragMillis = value);
                  }
                : null,
            onChanged: widget.enabled
                ? (value) => setState(() => _dragMillis = value)
                : null,
            onChangeEnd: widget.enabled ? _commitSeek : null,
            semanticFormatterCallback: (value) =>
                _formatDuration(Duration(milliseconds: value.round())),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              _formatDuration(previewPosition),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
            Text(
              _formatDuration(widget.duration),
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
