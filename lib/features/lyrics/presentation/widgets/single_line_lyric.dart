import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lyric_line.dart';
import '../helpers/lyric_position_smoother.dart';
import '../helpers/monet_lyric_layout.dart';
import '../providers/lyrics_providers.dart';

/// A fixed-height preview that keeps the sung portion of a long line visible.
class SingleLineLyric extends ConsumerStatefulWidget {
  const SingleLineLyric({
    required this.line,
    required this.style,
    this.lineEnd,
    this.documentOffset = 0,
    this.highlightColor,
    super.key,
  });

  final LyricLine line;
  final Duration? lineEnd;
  final int documentOffset;
  final TextStyle style;

  /// Null disables word highlighting and preserves the normal text color.
  final Color? highlightColor;

  @override
  ConsumerState<SingleLineLyric> createState() => _SingleLineLyricState();
}

class _SingleLineLyricState extends ConsumerState<SingleLineLyric>
    with SingleTickerProviderStateMixin {
  late final LyricPositionSmoother _position;
  late final ProviderSubscription<Duration> _positionSubscription;
  late final ProviderSubscription<bool> _playbackSubscription;
  bool _playing = false;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  TextPainter? _base;
  TextPainter? _highlight;

  @override
  void initState() {
    super.initState();
    _position = LyricPositionSmoother(
      vsync: this,
      position: ref.read(lyricPositionProvider),
    );
    _playbackSubscription = ref.listenManual(lyricPlaybackActiveProvider, (
      _,
      next,
    ) {
      _playing = next;
      _syncMotion();
    }, fireImmediately: true);
    _positionSubscription = ref.listenManual(lyricPositionProvider, (_, next) {
      _position.update(next);
    });
  }

  void _syncMotion() {
    _position.enabled = _playing && !_reduceMotion && _tickerEnabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncMotion();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = buildSingleLineLyricTokens(widget.line, widget.lineEnd);
    final timed =
        widget.highlightColor != null && tokens.any((token) => token.hasTiming);
    TextPainter layout(Color? color) => TextPainter(
      text: TextSpan(
        text: widget.line.text.replaceAll('\n', ' ').replaceAll('\r', ' '),
        style: widget.style.copyWith(color: color),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();

    final oldBase = _base;
    final oldHighlight = _highlight;
    _base = layout(widget.style.color);
    _highlight = timed ? layout(widget.highlightColor) : null;
    // The old painter can still be attached until this build updates the render
    // object. Release paragraphs after paint, including outgoing switcher lines.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldBase?.dispose();
      oldHighlight?.dispose();
    });
    return Semantics(
      label: widget.line.text.trim(),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SingleLineLyricPainter(
            base: _base!,
            highlight: _highlight,
            tokens: tokens,
            position: _position,
            lineStart: widget.line.start,
            documentOffset: widget.documentOffset,
            reduceMotion: _reduceMotion,
          ),
          size: Size(double.infinity, _base!.height),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription.close();
    _playbackSubscription.close();
    _position.dispose();
    _base?.dispose();
    _highlight?.dispose();
    super.dispose();
  }
}

/// Some sources omit the line end even when all word intervals are supplied.
/// Preserve those intervals, while using the shared validation and fallback.
List<MonetDisplayToken> buildSingleLineLyricTokens(
  LyricLine line,
  Duration? lineEnd,
) {
  if (line.end != null || line.tokens.isEmpty) {
    return buildMonetDisplayTokens(line);
  }
  final tokenEnd = line.tokens.fold<Duration>(
    Duration.zero,
    (end, token) => token.endOffset > end ? token.endOffset : end,
  );
  return buildMonetDisplayTokens(
    LyricLine(
      start: line.start,
      end: lineEnd ?? line.start + tokenEnd,
      text: line.text,
      tokens: line.tokens,
    ),
  );
}

class SingleLineLyricPainter extends CustomPainter {
  SingleLineLyricPainter({
    required this.base,
    required this.highlight,
    required this.tokens,
    required this.position,
    required this.lineStart,
    required this.documentOffset,
    required this.reduceMotion,
  }) : _boxes = [
         for (final token in tokens)
           base.getBoxesForSelection(
             TextSelection(
               baseOffset: token.startOffset,
               extentOffset: token.endOffset,
             ),
           ),
       ],
       super(repaint: position);

  final TextPainter base;
  final TextPainter? highlight;
  final List<MonetDisplayToken> tokens;
  final ValueListenable<Duration> position;
  final Duration lineStart;
  final int documentOffset;
  final bool reduceMotion;
  final List<List<TextBox>> _boxes;

  Duration get _timeline =>
      position.value + Duration(milliseconds: documentOffset);

  /// Physical paragraph offset, clamped so neither end leaves empty space.
  double scrollOffset(double viewportWidth) {
    final overflow = math.max(0.0, base.width - viewportWidth);
    if (overflow == 0 || viewportWidth <= 0) return 0;
    final rtl = base.textDirection == TextDirection.rtl;
    if (highlight == null) {
      if (reduceMotion) return rtl ? overflow : 0;
      final elapsed = (_timeline - lineStart).inMilliseconds / 1000;
      final distance = ((elapsed - 0.8) * 26).clamp(0.0, overflow);
      return rtl ? overflow - distance : distance;
    }

    var focus = rtl ? base.width : 0.0;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!token.hasTiming || _timeline < token.start!) continue;
      final progress = reduceMotion
          ? 0.0
          : resolveMonetTokenProgress(
              timelinePosition: _timeline,
              token: token,
            );
      final boxes = _boxes[i];
      if (boxes.isEmpty) continue;
      final box = boxes.last;
      focus = box.direction == TextDirection.rtl
          ? box.right - box.toRect().width * progress
          : box.left + box.toRect().width * progress;
    }
    if (reduceMotion) {
      // Jump between windows only at word boundaries, without continuous motion.
      final window = math.max(1.0, viewportWidth - 24);
      return ((focus / window).floor() * window).clamp(0.0, overflow);
    }
    return (focus - viewportWidth * (rtl ? 0.4 : 0.6)).clamp(0.0, overflow);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final offset = scrollOffset(size.width);
    final overflow = math.max(0.0, base.width - size.width);
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    if (overflow > 0) canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.translate(-offset, (size.height - base.height) / 2);
    base.paint(canvas, Offset.zero);
    if (highlight case final active?) {
      final path = Path();
      for (var i = 0; i < tokens.length; i++) {
        final progress = resolveMonetTokenProgress(
          timelinePosition: _timeline,
          token: tokens[i],
        );
        if (progress <= 0) continue;
        for (final box in _boxes[i]) {
          final rect = box.toRect();
          path.addRect(
            Rect.fromLTRB(
              box.direction == TextDirection.rtl
                  ? rect.right - rect.width * progress
                  : rect.left,
              rect.top,
              box.direction == TextDirection.rtl
                  ? rect.right
                  : rect.left + rect.width * progress,
              rect.bottom,
            ),
          );
        }
      }
      canvas.save();
      canvas.clipPath(path);
      active.paint(canvas, Offset.zero);
      canvas.restore();
    }
    canvas.restore();
    if (overflow > 0) {
      final fade = math.min(12.0, size.width / 4) / size.width;
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            colors: [
              offset > 0 ? Colors.transparent : Colors.white,
              Colors.white,
              Colors.white,
              offset < overflow ? Colors.transparent : Colors.white,
            ],
            stops: [0, fade, 1 - fade, 1],
          ).createShader(bounds),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SingleLineLyricPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight ||
      oldDelegate.position != position ||
      oldDelegate.lineStart != lineStart ||
      oldDelegate.documentOffset != documentOffset ||
      oldDelegate.reduceMotion != reduceMotion;
}
