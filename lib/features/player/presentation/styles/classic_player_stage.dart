import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../domain/entities/player_track.dart';
import '../helpers/player_artwork_helper.dart';

/// 经典样式的专辑封套舞台，保持封面为唯一主视觉。
class ClassicPlayerStage extends StatelessWidget {
  const ClassicPlayerStage({required this.track, super.key});

  final PlayerTrack? track;

  @override
  Widget build(BuildContext context) {
    final palette =
        PlayerScenePalette.maybeOf(context) ??
        classicPlayerScenePaletteFallback;
    final imageProvider = artworkProvider(
      track?.artworkUrl,
      track?.artworkBytes,
    );

    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey<String>('classic-player-stage'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            final coverSize = side * 0.90;
            final radius = (coverSize * 0.075).clamp(18.0, 30.0);
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                Transform.rotate(
                  angle: -0.022,
                  child: Container(
                    key: const ValueKey<String>('classic-album-sleeve'),
                    width: coverSize * 0.98,
                    height: coverSize * 0.98,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          palette.surfaceRaised,
                          palette.surface,
                          palette.surfaceDeep,
                        ],
                      ),
                      border: Border.all(
                        color: palette.edge.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
                Container(
                  key: const ValueKey<String>('classic-album-cover'),
                  width: coverSize,
                  height: coverSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: palette.foreground.withValues(alpha: 0.12),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.surfaceDeep.withValues(alpha: 0.52),
                        blurRadius: math.max(18, coverSize * 0.09),
                        offset: Offset(0, coverSize * 0.035),
                      ),
                      BoxShadow(
                        color: palette.edge.withValues(alpha: 0.10),
                        blurRadius: math.max(12, coverSize * 0.055),
                      ),
                    ],
                  ),
                  child: imageProvider == null
                      ? _ClassicCoverPlaceholder(palette: palette)
                      : Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _ClassicCoverPlaceholder(palette: palette);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClassicCoverPlaceholder extends StatelessWidget {
  const _ClassicCoverPlaceholder({required this.palette});

  final PlayerScenePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surfaceRaised,
            palette.surface,
            palette.surfaceDeep,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 88,
          color: palette.foreground.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
