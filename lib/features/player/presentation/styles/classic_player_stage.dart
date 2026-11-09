import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../domain/entities/player_track.dart';
import '../helpers/player_artwork_helper.dart';

/// A single softly lit album sleeve, with the artwork kept at its original ratio.
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
            final coverSize = side * 0.94;
            final radius = BorderRadius.circular(
              (coverSize * 0.065).clamp(16.0, 28.0),
            );
            return Center(
              child: Container(
                key: const ValueKey<String>('classic-album-sleeve'),
                width: coverSize,
                height: coverSize,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: math.max(20, coverSize * 0.10),
                      offset: Offset(0, coverSize * 0.045),
                    ),
                    BoxShadow(
                      color: palette.surfaceDeep.withValues(alpha: 0.18),
                      blurRadius: math.max(8, coverSize * 0.035),
                      offset: Offset(0, coverSize * 0.012),
                    ),
                  ],
                ),
                child: ClipRRect(
                  key: const ValueKey<String>('classic-album-cover'),
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(color: palette.surfaceRaised),
                      if (imageProvider == null)
                        _ClassicCoverPlaceholder(palette: palette)
                      else ...<Widget>[
                        // The soft fill gives wide/tall artwork a complete sleeve
                        // without cropping the foreground artwork.
                        ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 24,
                            sigmaY: 24,
                            tileMode: TileMode.clamp,
                          ),
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: palette.surfaceRaised),
                          ),
                        ),
                        ColoredBox(
                          color: palette.surface.withValues(alpha: 0.28),
                        ),
                        Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              _ClassicCoverPlaceholder(palette: palette),
                        ),
                      ],
                      // Paint the light edge above the image so it stays visible.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: palette.foreground.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
