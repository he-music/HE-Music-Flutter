import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_style_models.dart';
import '../../domain/entities/player_track.dart';
import 'cassette_player_stage.dart';
import 'classic_player_stage.dart';
import 'radial_spectrum_player_stage.dart';
import 'vinyl_player_stage.dart';

const double cassettePlayerStageAspectRatio = 1.60;

class PlayerStyleStage extends StatelessWidget {
  const PlayerStyleStage({
    required this.stageKind,
    required this.track,
    required this.maxWidth,
    this.cassetteLabel,
    super.key,
  });

  final AppPlayerStageKind stageKind;
  final PlayerTrack? track;
  final double maxWidth;
  final Widget? cassetteLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCassette = stageKind == AppPlayerStageKind.cassette;
        final aspectRatio = isCassette ? cassettePlayerStageAspectRatio : 1.0;
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
            child: switch (stageKind) {
              AppPlayerStageKind.classic => ClassicPlayerStage(track: track),
              AppPlayerStageKind.vinyl => VinylPlayerStage(track: track),
              AppPlayerStageKind.cassette => CassettePlayerStage(
                track: track,
                label: cassetteLabel,
                clipHorizontalOverflow: width < maxWidth,
              ),
              AppPlayerStageKind.radialSpectrum => RadialSpectrumPlayerStage(
                track: track,
              ),
            },
          ),
        );
      },
    );
  }
}