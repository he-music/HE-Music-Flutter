import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../domain/entities/player_play_mode.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    required this.localeCode,
    required this.isPlaying,
    required this.playMode,
    this.showPlayModeButton = true,
    this.playModeLocked = false,
    this.isTrackTransitioning = false,
    this.showQueueButton = true,
    this.compact = false,
    required this.onOpenQueue,
    required this.onCyclePlayMode,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    super.key,
  });

  final String localeCode;
  final bool isPlaying;
  final PlayerPlayMode playMode;
  final bool showPlayModeButton;
  final bool playModeLocked;
  final bool isTrackTransitioning;
  final bool showQueueButton;
  final bool compact;
  final VoidCallback onOpenQueue;
  final VoidCallback onCyclePlayMode;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 272;
      final useCompact = compact || constraints.maxWidth < 340;
      final modeButton = _SideControlButton(
        onPressed: playModeLocked || isTrackTransitioning
            ? null
            : onCyclePlayMode,
        tooltip: _modeTooltip(playMode),
        icon: _modeIcon(playMode),
        compact: useCompact,
      );
      final queueButton = _SideControlButton(
        onPressed: onOpenQueue,
        tooltip: AppI18n.tByLocaleCode(localeCode, 'player.queue.open'),
        icon: Icons.queue_music_rounded,
        compact: useCompact,
      );
      final mainControls = Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: useCompact ? 8 : 14,
        runSpacing: 8,
        children: [
          _RoundControlButton(
            onPressed: onPrevious,
            tooltip: AppI18n.tByLocaleCode(localeCode, 'player.previous'),
            icon: Icons.skip_previous_rounded,
            size: useCompact ? LayoutTokens.controlMinExtent : 58,
            iconSize: useCompact ? 28 : 34,
          ),
          _PrimaryControlButton(
            onPressed: isTrackTransitioning ? null : onPlayPause,
            tooltip: AppI18n.tByLocaleCode(
              localeCode,
              isPlaying ? 'player.pause' : 'player.play',
            ),
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            compact: useCompact,
            isTrackTransitioning: isTrackTransitioning,
            preparingLabel: AppI18n.tByLocaleCode(
              localeCode,
              'player.transition.preparing',
            ),
          ),
          _RoundControlButton(
            onPressed: onNext,
            tooltip: AppI18n.tByLocaleCode(localeCode, 'player.next'),
            icon: Icons.skip_next_rounded,
            size: useCompact ? LayoutTokens.controlMinExtent : 58,
            iconSize: useCompact ? 28 : 34,
          ),
        ],
      );
      if (narrow) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mainControls,
            if (showPlayModeButton || showQueueButton)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showPlayModeButton)
                    modeButton
                  else
                    const SizedBox(width: LayoutTokens.controlMinExtent),
                  if (showQueueButton)
                    queueButton
                  else
                    const SizedBox(width: LayoutTokens.controlMinExtent),
                ],
              ),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showPlayModeButton) ...[
            modeButton,
            SizedBox(width: useCompact ? 4 : 8),
          ],
          mainControls,
          if (showQueueButton) ...[
            SizedBox(width: useCompact ? 4 : 8),
            queueButton,
          ],
        ],
      );
    },
  );

  IconData _modeIcon(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => Icons.repeat_rounded,
      PlayerPlayMode.shuffle => Icons.shuffle_rounded,
      PlayerPlayMode.single => Icons.repeat_one_rounded,
    };
  }

  String _modeTooltip(PlayerPlayMode mode) {
    return switch (mode) {
      PlayerPlayMode.sequence => AppI18n.tByLocaleCode(
        localeCode,
        'player.mode.sequence',
      ),
      PlayerPlayMode.shuffle => AppI18n.tByLocaleCode(
        localeCode,
        'player.mode.shuffle',
      ),
      PlayerPlayMode.single => AppI18n.tByLocaleCode(
        localeCode,
        'player.mode.single',
      ),
    };
  }
}

class _PrimaryControlButton extends StatelessWidget {
  const _PrimaryControlButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.compact,
    required this.isTrackTransitioning,
    required this.preparingLabel,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final bool compact;
  final bool isTrackTransitioning;
  final String preparingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = PlayerScenePalette.maybeOf(context);
    final background = palette?.foreground ?? Colors.white;
    final foreground = palette?.surfaceDeep ?? Colors.black87;
    return IconButton(
      onPressed: onPressed,
      tooltip: isTrackTransitioning ? preparingLabel : tooltip,
      icon: isTrackTransitioning
          ? Semantics(
              label: preparingLabel,
              child: SizedBox.square(
                dimension: compact ? 34 : 42,
                child: Center(
                  child: SizedBox.square(
                    key: const ValueKey<String>(
                      'player-control-preparing-indicator',
                    ),
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            )
          : Icon(icon, size: compact ? 34 : 42),
      color: foreground,
      style: IconButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.65),
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        shape: const CircleBorder(),
        shadowColor: Colors.transparent,
        padding: EdgeInsets.all(compact ? 8 : 12),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize),
      color: PlayerScenePalette.maybeOf(context)?.foreground ?? Colors.white,
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
      color:
          PlayerScenePalette.maybeOf(context)?.secondaryForeground ??
          Colors.white.withValues(alpha: 0.72),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        minimumSize: const Size.square(LayoutTokens.controlMinExtent),
        padding: EdgeInsets.all(compact ? 6 : 10),
      ),
    );
  }
}
