import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';

/// Host boundary for the Monet lyric renderer.
///
/// The renderer is intentionally supplied by a follow-up task. Keeping the
/// palette and seek contract here lets PlayerPage switch renderers without
/// changing the lyric data or playback boundaries.
class MonetLyricPage extends StatelessWidget {
  const MonetLyricPage({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
    super.key,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette? palette;

  @override
  Widget build(BuildContext context) {
    final effectivePalette =
        palette ??
        PlayerScenePalette.maybeOf(context) ??
        classicPlayerScenePaletteFallback;
    return DecoratedBox(
      key: const ValueKey<String>('monet-lyric-page'),
      // The player backdrop owns the full-page background; this host is transparent.
      decoration: const BoxDecoration(),
      child: Center(
        child: Icon(
          Icons.lyrics_rounded,
          color: effectivePalette.accent,
          size: 32,
        ),
      ),
    );
  }
}
