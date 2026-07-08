import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/player_play_mode.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    required this.config,
    required this.isPlaying,
    required this.playMode,
    this.showPlayModeButton = true,
    this.playModeLocked = false,
    this.showQueueButton = true,
    this.compact = false,
    required this.onOpenQueue,
    required this.onCyclePlayMode,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    super.key,
  });

  final AppConfigState config;
  final bool isPlaying;
  final PlayerPlayMode playMode;
  final bool showPlayModeButton;
  final bool playModeLocked;
  final bool showQueueButton;
  final bool compact;
  final VoidCallback onOpenQueue;
  final VoidCallback onCyclePlayMode;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (showPlayModeButton)
            _SideControlButton(
              onPressed: playModeLocked ? null : onCyclePlayMode,
              tooltip: _modeTooltip(playMode),
              icon: _modeIcon(playMode),
              compact: compact,
            ),
          if (showPlayModeButton) SizedBox(width: compact ? 4 : 8),
          _RoundControlButton(
            onPressed: onPrevious,
            icon: Icons.skip_previous_rounded,
            size: compact ? 46 : 58,
            iconSize: compact ? 28 : 34,
          ),
          SizedBox(width: compact ? 8 : 14),
          _PrimaryControlButton(
            onPressed: onPlayPause,
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            compact: compact,
          ),
          SizedBox(width: compact ? 8 : 14),
          _RoundControlButton(
            onPressed: onNext,
            icon: Icons.skip_next_rounded,
            size: compact ? 46 : 58,
            iconSize: compact ? 28 : 34,
          ),
          SizedBox(width: compact ? 4 : 8),
          if (showQueueButton)
            _SideControlButton(
              onPressed: onOpenQueue,
              tooltip: AppI18n.t(config, 'player.queue.open'),
              icon: Icons.queue_music_rounded,
              compact: compact,
            ),
        ],
      ),
    );
  }

  IconData _modeIcon(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => Icons.repeat_rounded,
      PlayerPlayMode.shuffle => Icons.shuffle_rounded,
      PlayerPlayMode.single => Icons.repeat_one_rounded,
    };
  }

  String _modeTooltip(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => AppI18n.t(config, 'player.mode.sequence'),
      PlayerPlayMode.shuffle => AppI18n.t(config, 'player.mode.shuffle'),
      PlayerPlayMode.single => AppI18n.t(config, 'player.mode.single'),
    };
  }
}

class _PrimaryControlButton extends StatelessWidget {
  const _PrimaryControlButton({
    required this.onPressed,
    required this.icon,
    required this.compact,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 34 : 42),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.all(compact ? 8 : 12),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.onPressed,
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        minimumSize: Size.square(size),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}

class _SideControlButton extends StatelessWidget {
  const _SideControlButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.compact,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: compact ? 18 : 22,
      color: Colors.white.withValues(alpha: 0.84),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        minimumSize: Size.square(compact ? 36 : 48),
        padding: EdgeInsets.all(compact ? 6 : 10),
      ),
    );
  }
}
