import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/tilt_lyric_rail.dart';

/// Player host for the Folia Tilt active-line lyric visualizer.
class TiltLyricPage extends ConsumerWidget {
  const TiltLyricPage({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
    this.seekListenable,
    super.key,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette? palette;
  final Listenable? seekListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TiltLyricDataHost(
      key: const ValueKey<String>('tilt-lyric-page'),
      emptyText: emptyText,
      onSeek: onSeek,
      palette:
          palette ??
          PlayerScenePalette.maybeOf(context) ??
          classicPlayerScenePaletteFallback,
      seekListenable: seekListenable,
    );
  }
}

class _TiltLyricDataHost extends ConsumerWidget {
  const _TiltLyricDataHost({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
    required this.seekListenable,
    super.key,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette palette;
  final Listenable? seekListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (
          fontPreset: state.lyricFontPreset,
          enableWordByWordLyric: state.enableWordByWordLyric,
          highlightMode: state.lyricHighlightMode,
          highlightPreset: state.lyricHighlightPreset,
          highlightCustomColor: state.lyricHighlightCustomColor,
        ),
      ),
    );
    final documentAsync = ref.watch(currentLyricDocumentProvider);
    final request = ref.watch(currentLyricRequestProvider);
    return documentAsync.when(
      data: (document) => document.isEmpty
          ? _TiltLyricFallback(text: emptyText, palette: palette)
          : TiltLyricRail(
              document: document,
              documentIdentity: request?.cacheKey,
              fontPreset: config.fontPreset,
              enableWordByWordLyric: config.enableWordByWordLyric,
              palette: palette,
              highlightColor: resolveLyricHighlightColorValues(
                mode: config.highlightMode,
                preset: config.highlightPreset,
                customColorValue: config.highlightCustomColor,
                autoColor: palette.accent,
              ),
              onSeek: onSeek,
              seekListenable: seekListenable,
            ),
      loading: () => Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: palette.accent,
          ),
        ),
      ),
      error: (error, stackTrace) =>
          _TiltLyricFallback(text: emptyText, palette: palette),
    );
  }
}

class _TiltLyricFallback extends StatelessWidget {
  const _TiltLyricFallback({required this.text, required this.palette});

  final String text;
  final PlayerScenePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: palette.secondaryForeground.withValues(alpha: 0.78),
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
