import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_style_models.dart';
import '../../domain/entities/player_track.dart';
import '../widgets/player_cover_hero.dart';
import 'cassette_player_stage.dart';
import 'vinyl_player_stage.dart';

class PlayerStyleStage extends StatelessWidget {
  const PlayerStyleStage({
    required this.stageKind,
    required this.track,
    required this.maxWidth,
    super.key,
  });

  final AppPlayerStageKind stageKind;
  final PlayerTrack? track;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (stageKind == AppPlayerStageKind.artistPhoto) {
          return const SizedBox.expand(
            key: ValueKey<String>('player-stage-artist-photo-safe-area'),
          );
        }
        final isCassette = stageKind == AppPlayerStageKind.cassette;
        final aspectRatio = isCassette ? 1.48 : 1.0;
        final width = math.min(
          math.min(constraints.maxWidth, maxWidth),
          constraints.maxHeight * aspectRatio,
        );
        final height = width / aspectRatio;
        return Center(
          child: SizedBox(
            key: ValueKey<String>('player-stage-${stageKind.name}'),
            width: width,
            height: height,
            child: stageKind == AppPlayerStageKind.vinyl
                ? VinylPlayerStage(track: track)
                : isCassette
                ? CassettePlayerStage(track: track)
                : PlayerCoverHero(
                    artworkUrl: track?.artworkUrl,
                    artworkBytes: track?.artworkBytes,
                    size: width,
                  ),
          ),
        );
      },
    );
  }
}
