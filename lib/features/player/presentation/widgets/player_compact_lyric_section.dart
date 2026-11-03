import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../../lyrics/domain/entities/lyric_line.dart';
import '../../../lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import '../../../lyrics/presentation/widgets/single_line_lyric.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../providers/player_providers.dart';

typedef _CompactLyric = ({LyricLine line, Duration? end, int offset});

// Release cached dependencies while hidden so remounting during layout does not
// flush stale dependencies and schedule a provider refresh during widget build.
final _compactLyricProvider = Provider.autoDispose<_CompactLyric?>((ref) {
  final position = ref.watch(lyricPositionProvider);
  final documentAsync = ref.watch(currentLyricDocumentProvider);
  return documentAsync.when(
    data: (document) => _resolveCompactLyric(document, position),
    loading: () => null,
    error: (_, _) => null,
  );
});

/// 紧凑模式下的歌词预览区域
class PlayerCompactLyricSection extends ConsumerWidget {
  const PlayerCompactLyricSection({super.key, required this.onTap});

  /// 共享播放器布局用于预留歌词预览槽位的高度。
  static const double layoutHeight = 40;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack != null),
    );
    final isTrackTransitioning = ref.watch(
      playerControllerProvider.select((state) => state.isTrackTransitioning),
    );
    if (!hasTrack) {
      return const SizedBox(height: layoutHeight);
    }
    final lyric = ref.watch(_compactLyricProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final palette = PlayerScenePalette.maybeOf(context);
    return SizedBox(
      height: layoutHeight,
      width: double.infinity,
      child: Opacity(
        opacity: isTrackTransitioning ? 0.45 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey<String>('player-compact-lyric-tap'),
            onTap: isTrackTransitioning ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: lyric == null
                      ? const SizedBox.shrink()
                      : _CompactLyricContent(
                          key: ValueKey(lyric),
                          lyric: lyric,
                          color: (palette?.foreground ?? Colors.white)
                              .withValues(alpha: 0.92),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLyricContent extends ConsumerWidget {
  const _CompactLyricContent({
    required this.lyric,
    required this.color,
    super.key,
  });

  final _CompactLyric lyric;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (
          wordByWord: state.enableWordByWordLyric,
          mode: state.lyricHighlightMode,
          preset: state.lyricHighlightPreset,
          customColor: state.lyricHighlightCustomColor,
        ),
      ),
    );
    final timed =
        config.wordByWord &&
        buildSingleLineLyricTokens(
          lyric.line,
          lyric.end,
        ).any((token) => token.hasTiming);
    final autoColor = timed && config.mode == AppLyricHighlightMode.auto
        ? ref.watch(playerAutoLyricHighlightColorProvider).value
        : null;
    return SingleLineLyric(
      line: lyric.line,
      lineEnd: lyric.end,
      documentOffset: lyric.offset,
      highlightColor: timed
          ? resolveLyricHighlightColorValues(
              mode: config.mode,
              preset: config.preset,
              customColorValue: config.customColor,
              autoColor: autoColor,
            )
          : null,
      style: (Theme.of(context).textTheme.titleSmall ?? const TextStyle())
          .copyWith(
            color: color,
            fontWeight: FontWeight.w500,
            height: 1.0,
            fontSize: 16,
          ),
    );
  }
}

_CompactLyric? _resolveCompactLyric(LyricDocument document, Duration position) {
  final index = _findCurrentLineIndex(
    document.lines,
    position + Duration(milliseconds: document.offset),
  );
  if (index < 0) return null;
  return (
    line: document.lines[index],
    end:
        document.lines[index].end ??
        (index + 1 < document.lines.length
            ? document.lines[index + 1].start
            : null),
    offset: document.offset,
  );
}

int _findCurrentLineIndex(List<LyricLine> lines, Duration position) {
  var lower = 0;
  var upper = lines.length;
  while (lower < upper) {
    final middle = lower + (upper - lower) ~/ 2;
    if (lines[middle].start <= position) {
      lower = middle + 1;
    } else {
      upper = middle;
    }
  }
  final index = lower - 1;
  if (index < 0) {
    return -1;
  }
  final line = lines[index];
  final nextStart = index + 1 < lines.length ? lines[index + 1].start : null;
  final lineEnd = line.end ?? nextStart;
  if (lineEnd == null || position < lineEnd) {
    return index;
  }
  return -1;
}
