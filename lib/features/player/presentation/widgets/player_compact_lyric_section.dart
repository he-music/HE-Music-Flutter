import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../../lyrics/domain/entities/lyric_line.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../providers/player_providers.dart';

/// 紧凑模式下的歌词预览区域
class PlayerCompactLyricSection extends ConsumerWidget {
  const PlayerCompactLyricSection({super.key, required this.onTap});

  static const double _compactLyricHeight = 40;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack != null),
    );
    if (!hasTrack) {
      return const SizedBox(height: _compactLyricHeight);
    }
    final position = ref.watch(lyricPositionProvider);
    final documentAsync = ref.watch(currentLyricDocumentProvider);
    final text = documentAsync.when(
      data: (document) => _resolveCompactLyricText(document, position),
      loading: () => '',
      error: (_, _) => '',
    );
    final theme = Theme.of(context);
    return SizedBox(
      height: _compactLyricHeight,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(
                      alpha: text.isEmpty ? 0.56 : 0.92,
                    ),
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveCompactLyricText(LyricDocument document, Duration position) {
    if (document.lines.isEmpty) {
      return '';
    }
    final index = _findCurrentLineIndex(document.lines, position);
    if (index < 0 || index >= document.lines.length) {
      return '';
    }
    return document.lines[index].text.trim();
  }

  int _findCurrentLineIndex(List<LyricLine> lines, Duration position) {
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      if (position < line.start) {
        continue;
      }
      final nextStart = index + 1 < lines.length
          ? lines[index + 1].start
          : null;
      final lineEnd = line.end ?? nextStart;
      if (lineEnd == null || position < lineEnd) {
        return index;
      }
    }
    return -1;
  }
}
