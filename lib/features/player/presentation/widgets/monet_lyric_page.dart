import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/monet_lyric_rail.dart';

/// Transparent player host for the Monet lyric renderer.
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
      // PlayerBackdrop owns the full-page background.
      decoration: const BoxDecoration(),
      child: _MonetLyricDataHost(
        emptyText: emptyText,
        onSeek: onSeek,
        palette: effectivePalette,
      ),
    );
  }
}

class _MonetLyricDataHost extends ConsumerWidget {
  const _MonetLyricDataHost({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette palette;

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
          ? _MonetLyricFallback(
              key: const ValueKey<String>('monet-lyric-empty'),
              text: emptyText,
              palette: palette,
            )
          : MonetLyricRail(
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
            ),
      loading: () => Center(
        child: SizedBox.square(
          key: const ValueKey<String>('monet-lyric-loading'),
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: palette.accent,
          ),
        ),
      ),
      error: (error, stackTrace) => _MonetLyricFallback(
        key: const ValueKey<String>('monet-lyric-error'),
        text: emptyText,
        palette: palette,
      ),
    );
  }
}

class _MonetLyricFallback extends StatelessWidget {
  const _MonetLyricFallback({
    required this.text,
    required this.palette,
    super.key,
  });

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
