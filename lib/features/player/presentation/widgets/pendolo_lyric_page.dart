import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../providers/player_providers.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/pendolo_lyric_rail.dart';

/// Player host for the Folia Pendolo escapement wheel lyric visualizer.
class PendoloLyricPage extends ConsumerWidget {
  const PendoloLyricPage({
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
    return _PendoloLyricDataHost(
      key: const ValueKey<String>('pendolo-lyric-page'),
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

class _PendoloLyricDataHost extends ConsumerWidget {
  const _PendoloLyricDataHost({
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
    final autoColor = config.highlightMode == AppLyricHighlightMode.auto
        ? ref.watch(playerAutoLyricHighlightColorProvider).value
        : null;
    final documentAsync = ref.watch(displayedLyricDocumentProvider);
    final request = ref.watch(currentLyricRequestProvider);
    return documentAsync.when(
      data: (document) => document.isEmpty
          ? _PendoloLyricFallback(text: emptyText, palette: palette)
          : PendoloLyricRail(
              document: document,
              documentIdentity: request?.cacheKey,
              fontPreset: config.fontPreset,
              enableWordByWordLyric: config.enableWordByWordLyric,
              palette: palette,
              highlightColor: resolveLyricHighlightColorValues(
                mode: config.highlightMode,
                preset: config.highlightPreset,
                customColorValue: config.highlightCustomColor,
                autoColor: autoColor,
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
          _PendoloLyricFallback(text: emptyText, palette: palette),
    );
  }
}

class _PendoloLyricFallback extends StatelessWidget {
  const _PendoloLyricFallback({required this.text, required this.palette});

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
