import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' as model;
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../helpers/lyric_highlight_color_helper.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/lyric_candidate.dart';
import '../../domain/entities/raw_lyric_bundle.dart';
import '../../domain/usecases/parse_lrc.dart';

final lyricPreviewPositionProvider = Provider.autoDispose
    .family<Duration?, PlayerTrack>((ref, target) {
      return ref.watch(
        playerControllerProvider.select((state) {
          final current = state.currentTrack;
          if (current == null ||
              current.id != target.id ||
              current.platform != target.platform ||
              current.path != target.path) {
            return null;
          }
          return state.position;
        }),
      );
    });

class LyricCandidatePreview extends StatefulWidget {
  const LyricCandidatePreview({
    required this.candidate,
    required this.target,
    required this.loadBundle,
    required this.onSelect,
    required this.selecting,
    super.key,
  });

  final LyricCandidate candidate;
  final PlayerTrack target;
  final Future<RawLyricBundle> Function() loadBundle;
  final VoidCallback? onSelect;
  final bool selecting;

  @override
  State<LyricCandidatePreview> createState() => _LyricCandidatePreviewState();
}

class _LyricCandidatePreviewState extends State<LyricCandidatePreview> {
  late Future<RawLyricBundle> _bundle = widget.loadBundle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = widget.candidate;
    final seconds = candidate.duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            candidate.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            candidate.artistNames
                .where((name) => name.trim().isNotEmpty)
                .join(' / '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            seconds > 0
                ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                : '—',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .7),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<RawLyricBundle>(
              future: _bundle,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _bundle = widget.loadBundle();
                      }),
                      child: const Text('歌词加载失败，重试'),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: Text('正在加载歌词…'));
                }
                return _SynchronizedLyric(
                  key: ObjectKey(data),
                  bundle: data,
                  target: widget.target,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              textStyle: theme.textTheme.labelLarge,
            ),
            onPressed: widget.onSelect,
            child: widget.selecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('使用此歌词'),
          ),
        ],
      ),
    );
  }
}

class _SynchronizedLyric extends ConsumerStatefulWidget {
  const _SynchronizedLyric({
    required this.bundle,
    required this.target,
    super.key,
  });
  final RawLyricBundle bundle;
  final PlayerTrack target;

  @override
  ConsumerState<_SynchronizedLyric> createState() => _SynchronizedLyricState();
}

class _SynchronizedLyricState extends ConsumerState<_SynchronizedLyric> {
  final _controller = fl.LyricController();
  late final _parts = splitLocalLyrics(widget.bundle.lyric);
  late final _document = parseLyricDocument(
    lyric: _parts.lyric,
    translation: widget.bundle.translation.trim().isEmpty
        ? _parts.translation
        : widget.bundle.translation,
    romanization: widget.bundle.romanization.trim().isEmpty
        ? _parts.romanization
        : widget.bundle.romanization,
  );

  @override
  void initState() {
    super.initState();
    _controller.loadLyricModel(
      model.LyricModel(
        tags: {'offset': _document.offset.toString()},
        lines: [
          for (final line in _document.lines)
            model.LyricLine(
              start: line.start,
              end: line.end,
              text: line.text,
              translation: [
                line.translation,
                line.romanization,
              ].where((text) => text.trim().isNotEmpty).join('\n'),
              words: line.tokens.isEmpty
                  ? null
                  : [
                      for (final token in line.tokens)
                        model.LyricWord(
                          text: token.text,
                          start: line.start + token.startOffset,
                          end: line.start + token.endOffset,
                        ),
                    ],
            ),
        ],
      ),
    );
    ref.listenManual(lyricPreviewPositionProvider(widget.target), (
      _,
      position,
    ) {
      _controller.setProgress(position ?? Duration.zero);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_document.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _parts.lyric.trim().isEmpty
                ? '暂无歌词'
                : [
                    _parts.lyric,
                    widget.bundle.translation,
                    widget.bundle.romanization,
                    _parts.translation,
                    _parts.romanization,
                  ].where((text) => text.trim().isNotEmpty).join('\n\n'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final scale = MediaQuery.textScalerOf(context);
    final highlight = ref.watch(
      appConfigProvider.select(
        (config) => (
          mode: config.lyricHighlightMode,
          preset: config.lyricHighlightPreset,
          customColor: config.lyricHighlightCustomColor,
        ),
      ),
    );
    final autoColor = highlight.mode == AppLyricHighlightMode.auto
        ? ref.watch(playerAutoLyricHighlightColorProvider).value
        : null;
    final highlightColor = resolveLyricHighlightColorValues(
      mode: highlight.mode,
      preset: highlight.preset,
      customColorValue: highlight.customColor,
      autoColor: autoColor,
    );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: scale.scale(15),
      color: theme.colorScheme.onSurfaceVariant,
    );
    return RepaintBoundary(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) => fl.LyricView(
            controller: _controller,
            style: fl.LyricStyles.default1.copyWith(
              anchorPosition: .42,
              activeAnchorPosition: .42,
              activeAlignment: MainAxisAlignment.center,
              fadeRange: fl.FadeRange(top: 20, bottom: 20),
              textAlign: TextAlign.center,
              contentAlignment: CrossAxisAlignment.center,
              // Allow the first and last lines to reach the shared visual anchor.
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: constraints.maxHeight,
              ),
              textStyle: textStyle,
              activeStyle: textStyle,
              translationStyle: theme.textTheme.bodySmall?.copyWith(
                fontSize: scale.scale(12),
                color: theme.colorScheme.onSurfaceVariant,
              ),
              translationActiveColor: theme.colorScheme.onSurfaceVariant,
              activeHighlightColor: highlightColor,
              selectedColor: highlightColor,
              selectedTranslationColor: theme.colorScheme.onSurfaceVariant,
              activeHighlightGradient: null,
              lineGap: 10,
              translationLineGap: 3,
            ),
          ),
        ),
      ),
    );
  }
}
