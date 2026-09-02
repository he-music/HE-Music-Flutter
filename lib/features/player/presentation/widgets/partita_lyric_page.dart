import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../../lyrics/presentation/widgets/partita_lyric_rail.dart';
import '../providers/player_providers.dart';

/// Player host for the Folia Partita active-line visualizer.
class PartitaLyricPage extends ConsumerWidget {
  const PartitaLyricPage({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
    this.breathingEnabled,
    this.seekListenable,
    super.key,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette? palette;
  final bool? breathingEnabled;
  final Listenable? seekListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectivePalette =
        palette ??
        PlayerScenePalette.maybeOf(context) ??
        classicPlayerScenePaletteFallback;
    final bool effectiveBreathingEnabled =
        breathingEnabled ??
        ref.watch(
          playerControllerProvider.select(
            (state) => state.isPlaying && !state.isLoading,
          ),
        );
    return _PartitaLyricDataHost(
      key: const ValueKey<String>('partita-lyric-page'),
      emptyText: emptyText,
      onSeek: onSeek,
      palette: effectivePalette,
      breathingEnabled: effectiveBreathingEnabled,
      seekListenable: seekListenable,
    );
  }
}

class _PartitaLyricDataHost extends ConsumerWidget {
  const _PartitaLyricDataHost({
    required this.emptyText,
    required this.onSeek,
    required this.palette,
    required this.breathingEnabled,
    required this.seekListenable,
    super.key,
  });

  final String emptyText;
  final ValueChanged<Duration>? onSeek;
  final PlayerScenePalette palette;
  final bool breathingEnabled;
  final Listenable? seekListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (
          fontPreset: state.lyricFontPreset,
          enableWordByWordLyric: state.enableWordByWordLyric,
        ),
      ),
    );
    final documentAsync = ref.watch(currentLyricDocumentProvider);
    final request = ref.watch(currentLyricRequestProvider);
    return documentAsync.when(
      data: (document) => document.isEmpty
          ? _PartitaLyricFallback(
              key: const ValueKey<String>('partita-lyric-empty'),
              text: emptyText,
              palette: palette,
            )
          : PartitaLyricRail(
              document: document,
              documentIdentity: request?.cacheKey,
              fontPreset: config.fontPreset,
              enableWordByWordLyric: config.enableWordByWordLyric,
              palette: palette,
              onSeek: onSeek,
              breathingEnabled: breathingEnabled,
              seekListenable: seekListenable,
            ),
      loading: () => Center(
        child: SizedBox.square(
          key: const ValueKey<String>('partita-lyric-loading'),
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: palette.accent,
          ),
        ),
      ),
      error: (error, stackTrace) => _PartitaLyricFallback(
        key: const ValueKey<String>('partita-lyric-error'),
        text: emptyText,
        palette: palette,
      ),
    );
  }
}

class _PartitaLyricFallback extends StatelessWidget {
  const _PartitaLyricFallback({
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
