import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/fold_lyric_rail.dart';
import '../../../lyrics/presentation/widgets/lyric_search_empty.dart';
import '../providers/player_providers.dart';

class FoldLyricPage extends ConsumerWidget {
  const FoldLyricPage({
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
    final colors =
        palette ??
        PlayerScenePalette.maybeOf(context) ??
        classicPlayerScenePaletteFallback;
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (
          fontPreset: state.lyricFontPreset,
          wordHighlight: state.enableWordByWordLyric,
          mode: state.lyricHighlightMode,
          preset: state.lyricHighlightPreset,
          customColor: state.lyricHighlightCustomColor,
        ),
      ),
    );
    final autoColor = config.mode == AppLyricHighlightMode.auto
        ? ref.watch(playerAutoLyricHighlightColorProvider).value
        : null;
    final document = ref.watch(displayedLyricDocumentProvider);
    final identity = ref.watch(
      currentLyricRequestProvider.select((request) => request?.cacheKey),
    );
    return document.when(
      data: (value) => value.isEmpty
          ? LyricSearchEmpty(color: colors.secondaryForeground)
          : FoldLyricRail(
              key: const ValueKey('fold-lyric-page'),
              document: value,
              documentIdentity: identity,
              fontPreset: config.fontPreset,
              enableWordByWordLyric: config.wordHighlight,
              palette: colors,
              onSeek: onSeek,
              seekListenable: seekListenable,
              highlightColor: resolveLyricHighlightColorValues(
                mode: config.mode,
                preset: config.preset,
                customColorValue: config.customColor,
                autoColor: autoColor,
              ),
            ),
      loading: () => Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: colors.accent,
          ),
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colors.secondaryForeground),
        ),
      ),
    );
  }
}
