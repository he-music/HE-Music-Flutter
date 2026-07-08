import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../controllers/player_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';
import 'player_control_bar.dart';
import 'player_progress_bar.dart';

/// 全屏歌词模式下的底部控制栏
class PlayerFullscreenLyricsBar extends ConsumerWidget {
  const PlayerFullscreenLyricsBar({
    super.key,
    required this.controller,
    required this.noTrackText,
    required this.onOpenMore,
    required this.onOpenQueue,
  });

  final PlayerController controller;
  final String noTrackText;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final config = ref.watch(appConfigProvider);
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final playMode = ref.watch(
      playerControllerProvider.select((state) => state.playMode),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    final position = ref.watch(
      playerControllerProvider.select((state) => state.position),
    );
    final duration = ref.watch(
      playerControllerProvider.select((state) => state.duration),
    );
    final title = track?.title ?? noTrackText;
    final artist = track?.artist ?? '';
    final imageProvider = artworkProvider(
      track?.artworkUrl,
      track?.artworkBytes,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlayerProgressBar(
            position: position,
            duration: duration,
            onSeek: controller.seek,
          ),
          Row(
            children: <Widget>[
              _buildCoverImage(context, imageProvider),
              const SizedBox(width: 10),
              Expanded(child: _buildTrackInfo(context, title, artist)),
              PlayerControlBar(
                config: config,
                compact: true,
                isPlaying: isPlaying,
                playMode: playMode,
                showPlayModeButton: !isRadioMode,
                showQueueButton: !isRadioMode,
                onOpenQueue: onOpenQueue,
                onCyclePlayMode: controller.cyclePlayMode,
                onPrevious: controller.playPrevious,
                onPlayPause: controller.togglePlayPause,
                onNext: controller.playNext,
              ),
              _PlayerUtilityButton(
                icon: Icons.more_horiz_rounded,
                color: Colors.white.withValues(alpha: 0.82),
                onTap: onOpenMore,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(
    BuildContext context,
    ImageProvider<Object>? imageProvider,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: imageProvider != null
            ? Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              )
            : Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext context, String title, String artist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (artist.isNotEmpty)
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

class _PlayerUtilityButton extends StatelessWidget {
  const _PlayerUtilityButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
