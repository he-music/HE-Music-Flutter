import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../../shared/widgets/app_activity_indicator.dart';
import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/fifty_two_hz_lyric_rail.dart';
import '../../../lyrics/presentation/widgets/lyric_search_empty.dart';
import '../providers/player_providers.dart';

class FiftyTwoHzLyricPage extends ConsumerWidget {
  const FiftyTwoHzLyricPage({
    this.palette,
    this.onSeek,
    this.seekListenable,
    super.key,
  });

  final PlayerScenePalette? palette;
  final ValueChanged<Duration>? onSeek;
  final Listenable? seekListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors =
        palette ??
        PlayerScenePalette.maybeOf(context) ??
        classicPlayerScenePaletteFallback;
    final config = ref.watch(
      appConfigProvider.select(
        (config) => (
          fontPreset: config.lyricFontPreset,
          wordByWord: config.enableWordByWordLyric,
          highlightMode: config.lyricHighlightMode,
          highlightPreset: config.lyricHighlightPreset,
          highlightCustomColor: config.lyricHighlightCustomColor,
        ),
      ),
    );
    final autoColor = config.highlightMode == AppLyricHighlightMode.auto
        ? ref.watch(playerAutoLyricHighlightColorProvider).value
        : null;
    final document = ref.watch(displayedLyricDocumentProvider);
    final request = ref.watch(currentLyricRequestProvider);
    if (document.isLoading && !document.hasValue) {
      return Center(
        child: AppActivityIndicator(size: 24, color: colors.accent),
      );
    }
    final lyrics = document.value ?? const LyricDocument.empty();
    return Stack(
      fit: StackFit.expand,
      children: [
        FiftyTwoHzLyricRail(
          key: ValueKey(request?.cacheKey),
          document: lyrics,
          fontPreset: config.fontPreset,
          enableWordByWordLyric: config.wordByWord,
          palette: colors,
          highlightColor: resolveLyricHighlightColorValues(
            mode: config.highlightMode,
            preset: config.highlightPreset,
            customColorValue: config.highlightCustomColor,
            autoColor: autoColor,
          ),
          onSeek: onSeek,
          seekListenable: seekListenable,
        ),
        if (lyrics.isEmpty)
          Align(
            alignment: const Alignment(0, .68),
            child: LyricSearchEmpty(color: colors.secondaryForeground),
          ),
      ],
    );
  }
}
