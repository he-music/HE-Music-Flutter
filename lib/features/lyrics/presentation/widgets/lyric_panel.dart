import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart' as domain;
import '../providers/lyrics_providers.dart';

@visibleForTesting
flm.LyricModel buildFlutterLyricModel(
  LyricDocument document, {
  required bool enableWordByWordLyric,
}) {
  return flm.LyricModel(
    tags: <String, String>{'offset': document.offset.toString()},
    lines: document.lines
        .map(
          (line) => _toFlutterLyricLine(
            line,
            enableWordByWordLyric: enableWordByWordLyric,
          ),
        )
        .toList(growable: false),
  );
}

@visibleForTesting
fl.LyricStyle buildLyricStyle({
  required bool compact,
  required AppLyricFontPreset fontPreset,
  required Color activeHighlightColor,
  bool center = false,
}) {
  final sizes = _resolveLyricFontSizes(fontPreset, compact: compact);
  if (compact) {
    return fl.LyricStyles.single.copyWith(
      textAlign: center ? TextAlign.center : TextAlign.left,
      textStyle: TextStyle(
        fontSize: sizes.inactive,
        color: Colors.white70,
        height: 1.0,
      ),
      activeStyle: TextStyle(
        fontSize: sizes.active,
        height: 1.0,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      translationStyle: TextStyle(
        fontSize: sizes.translation,
        color: Colors.white70,
      ),
      translationActiveColor: Colors.white,
      activeHighlightColor: activeHighlightColor,
      activeHighlightGradient: null,
    );
  }
  return fl.LyricStyles.default1.copyWith(
    textAlign: center ? TextAlign.center : TextAlign.left,
    contentAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    textStyle: TextStyle(fontSize: sizes.inactive, color: Colors.white60),
    activeStyle: TextStyle(
      fontSize: sizes.active,
      color: Colors.white,
      fontWeight: FontWeight.w500,
    ),
    translationStyle: TextStyle(
      fontSize: sizes.translation,
      color: Colors.white60,
    ),
    lineGap: 16,
    translationLineGap: 4,
    translationActiveColor: Colors.white,
    activeHighlightColor: activeHighlightColor,
    activeHighlightGradient: null,
  );
}

Color resolveLyricHighlightColor(AppConfigState config, {Color? autoColor}) {
  return switch (config.lyricHighlightMode) {
    AppLyricHighlightMode.auto => autoColor ?? AppLyricHighlightColor.sky.color,
    AppLyricHighlightMode.custom =>
      config.lyricHighlightCustomColor == null
          ? AppLyricHighlightColor.sky.color
          : Color(config.lyricHighlightCustomColor!),
    AppLyricHighlightMode.preset => config.lyricHighlightPreset.color,
  };
}

class LyricPanel extends ConsumerStatefulWidget {
  const LyricPanel({
    required this.emptyText,
    this.compact = false,
    this.center = false,
    this.onSeek,
    this.activeHighlightColorOverride,
    super.key,
  });

  final String emptyText;
  final bool compact;
  final bool center;
  final ValueChanged<Duration>? onSeek;
  final Color? activeHighlightColorOverride;

  @override
  ConsumerState<LyricPanel> createState() => _LyricPanelState();
}

class _LyricPanelState extends ConsumerState<LyricPanel> {
  late final fl.LyricController _controller = fl.LyricController();
  String? _loadedKey;
  DateTime? _lastTapSeekAt;
  Duration? _lastTapSeekPosition;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Duration>(lyricPositionProvider, (previous, next) {
      if (_disposed) {
        return;
      }
      // const Duration _kHighlightTransitionDuration = Duration(milliseconds: 200);
      _controller.setProgress(next + Duration(milliseconds: 200));
    });

    _bindTapToSeekIfNeeded();

    final request = ref.watch(currentLyricRequestProvider);
    final documentAsync = ref.watch(currentLyricDocumentProvider);
    final config = ref.watch(appConfigProvider);
    final position = ref.watch(lyricPositionProvider);

    return documentAsync.when(
      data: (document) {
        if (document.isEmpty) {
          return _buildFallback(context);
        }
        _loadDocumentIfNeeded(
          request?.cacheKey,
          document,
          enableWordByWordLyric: config.enableWordByWordLyric,
          position: position,
        );
        return fl.LyricView(
          controller: _controller,
          style: buildLyricStyle(
            compact: widget.compact,
            fontPreset: config.lyricFontPreset,
            center: widget.center,
            activeHighlightColor: resolveLyricHighlightColor(
              config,
              autoColor: widget.activeHighlightColorOverride,
            ),
          ),
          width: double.infinity,
          height: double.infinity,
        );
      },
      loading: () => widget.compact
          ? const SizedBox.shrink()
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, stackTrace) => widget.compact
          ? const SizedBox.shrink()
          : Center(
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.compact) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        widget.emptyText,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
        ),
      ),
    );
  }

  void _bindTapToSeekIfNeeded() {
    if (widget.compact || widget.onSeek == null) {
      _controller.cancelOnTapLineCallback();
      return;
    }
    _controller.setOnTapLineCallback(_onTapSeek);
  }

  void _onTapSeek(Duration position) {
    final onSeek = widget.onSeek;
    if (onSeek == null) {
      return;
    }
    final now = DateTime.now();
    final lastAt = _lastTapSeekAt;
    final lastPosition = _lastTapSeekPosition;

    // flutter_lyric 在某些布局下可能一次点击命中多行 rect，导致同一手势触发多次 tapLine。
    // 这里用短时间窗口做去重，保证一次点击只 seek 一次。
    if (lastAt != null &&
        now.difference(lastAt).inMilliseconds < 250 &&
        lastPosition == position) {
      return;
    }
    _lastTapSeekAt = now;
    _lastTapSeekPosition = position;
    onSeek(position);
  }

  void _loadDocumentIfNeeded(
    String? cacheKey,
    LyricDocument document, {
    required bool enableWordByWordLyric,
    required Duration position,
  }) {
    final key = buildLyricDocumentCacheKey(
      cacheKey,
      document,
      enableWordByWordLyric: enableWordByWordLyric,
    );
    if (_loadedKey == key) {
      return;
    }
    _loadedKey = key;
    _controller.loadLyricModel(
      buildFlutterLyricModel(
        document,
        enableWordByWordLyric: enableWordByWordLyric,
      ),
    );
    // 进入歌词页时立即同步当前播放进度，避免先从顶部渲染再跳到当前行。
    _controller.setProgress(position + const Duration(milliseconds: 200));
  }
}

@visibleForTesting
String buildLyricDocumentCacheKey(
  String? cacheKey,
  LyricDocument document, {
  required bool enableWordByWordLyric,
}) {
  final firstLine = document.lines.isEmpty ? null : document.lines.first;
  final lastLine = document.lines.isEmpty ? null : document.lines.last;
  return <Object?>[
    cacheKey ?? 'current',
    enableWordByWordLyric,
    document.offset,
    document.lines.length,
    firstLine?.start.inMilliseconds,
    firstLine?.end?.inMilliseconds,
    firstLine?.text,
    lastLine?.start.inMilliseconds,
    lastLine?.end?.inMilliseconds,
    lastLine?.text,
  ].join(':');
}

_LyricFontSizes _resolveLyricFontSizes(
  AppLyricFontPreset preset, {
  required bool compact,
}) {
  if (compact) {
    return switch (preset) {
      AppLyricFontPreset.small => const _LyricFontSizes(11, 15, 8),
      AppLyricFontPreset.medium => const _LyricFontSizes(12, 16, 9),
      AppLyricFontPreset.large => const _LyricFontSizes(13, 18, 10),
    };
  }
  return switch (preset) {
    AppLyricFontPreset.small => const _LyricFontSizes(16, 20, 10),
    AppLyricFontPreset.medium => const _LyricFontSizes(20, 24, 14),
    AppLyricFontPreset.large => const _LyricFontSizes(22, 28, 16),
  };
}

flm.LyricLine _toFlutterLyricLine(
  domain.LyricLine line, {
  required bool enableWordByWordLyric,
}) {
  final translation = line.translation.trim();
  final romanization = line.romanization.trim();
  return flm.LyricLine(
    start: line.start,
    end: line.end,
    text: line.text,
    translation: translation.isNotEmpty
        ? translation
        : (romanization.isNotEmpty ? romanization : null),
    words: !enableWordByWordLyric || line.tokens.isEmpty
        ? null
        : line.tokens
              .map(
                (token) => flm.LyricWord(
                  text: token.text,
                  start: line.start + token.startOffset,
                  end: line.start + token.endOffset,
                ),
              )
              .toList(growable: false),
  );
}

class _LyricFontSizes {
  const _LyricFontSizes(this.inactive, this.active, this.translation);

  final double inactive;
  final double active;
  final double translation;
}
