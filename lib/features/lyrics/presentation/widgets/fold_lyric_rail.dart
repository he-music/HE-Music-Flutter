import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/lyric_painter_owner.dart';
import '../helpers/lyric_position_smoother.dart';
import '../helpers/monet_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'fold_lyric_painter.dart';

class FoldLyricRail extends ConsumerStatefulWidget {
  const FoldLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    required this.onSeek,
    this.highlightColor,
    this.documentIdentity,
    this.seekListenable,
    this.debugOnStructureBuild,
    this.debugOnTextLayout,
    this.debugOnPaint,
    super.key,
  });

  final LyricDocument document;
  final AppLyricFontPreset fontPreset;
  final bool enableWordByWordLyric;
  final PlayerScenePalette palette;
  final ValueChanged<Duration>? onSeek;
  final Color? highlightColor;
  final String? documentIdentity;
  final Listenable? seekListenable;
  final VoidCallback? debugOnStructureBuild;
  final VoidCallback? debugOnTextLayout;
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<FoldLyricRail> createState() => _FoldLyricRailState();
}

class _FoldLyricRailState extends ConsumerState<FoldLyricRail>
    with TickerProviderStateMixin {
  final _owner = LyricPainterOwner();
  late MonetLyricLayoutEngine _engine;
  late MonetLyricPosition _resolved;
  late LyricPositionSmoother _position;
  late AnimationController _motion;
  late ProviderSubscription<Duration> _positionSubscription;
  late ProviderSubscription<bool> _playbackSubscription;
  bool _playing = false;
  bool _allowed = true;
  bool _snapNextPosition = false;
  bool _dragging = false;
  double _fromStep = 0;
  double _scrollDistance = 0;
  int? _manualAnchor;
  Timer? _resetTimer;
  Object? _layoutKey;
  List<FoldPaintRow> _rows = [];
  FoldLyricPainter? _painter;

  int get _anchor =>
      _manualAnchor ??
      _resolved.activeIndex ??
      _resolved.recentIndex ??
      _resolved.upcomingIndex ??
      0;

  @override
  void initState() {
    super.initState();
    _engine = MonetLyricLayoutEngine(widget.document);
    final position = ref.read(lyricPositionProvider);
    _resolved = _engine.resolvePosition(position);
    _position = LyricPositionSmoother(vsync: this, position: position);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
      value: 1,
    );
    _playbackSubscription = ref.listenManual(lyricPlaybackActiveProvider, (
      _,
      next,
    ) {
      _playing = next;
      _syncMotion();
    }, fireImmediately: true);
    _positionSubscription = ref.listenManual(
      lyricPositionProvider,
      (_, next) => _updatePosition(next),
    );
    widget.seekListenable?.addListener(_seek);
  }

  void _syncMotion() {
    _position.enabled = _playing && _allowed;
    if (!_playing || !_allowed) _motion.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant FoldLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seekListenable != oldWidget.seekListenable) {
      oldWidget.seekListenable?.removeListener(_seek);
      widget.seekListenable?.addListener(_seek);
    }
    if (!identical(widget.document, oldWidget.document) ||
        widget.documentIdentity != oldWidget.documentIdentity) {
      _engine = MonetLyricLayoutEngine(widget.document);
      _resolved = _engine.resolvePosition(ref.read(lyricPositionProvider));
      _position.snap(_resolved.playbackPosition);
      _resetTimer?.cancel();
      _manualAnchor = null;
      _scrollDistance = 0;
      _motion.value = 1;
      _layoutKey = null;
    }
  }

  // Samples repaint cached paragraphs; only line changes rebuild this rail.
  void _updatePosition(Duration next) {
    final previousAnchor = _anchor;
    final previousActive = _resolved.activeIndex;
    final previousFocus = _painter?.focus ?? previousAnchor.toDouble();
    final delta = next - _resolved.playbackPosition;
    final discontinuity =
        _snapNextPosition ||
        delta.isNegative ||
        delta > const Duration(milliseconds: 250);
    _snapNextPosition = false;
    _resolved = _engine.resolvePosition(next);
    _position.update(
      next,
      discontinuity: discontinuity || previousActive != _resolved.activeIndex,
    );
    if (previousAnchor != _anchor || previousActive != _resolved.activeIndex) {
      if (_playing &&
          _allowed &&
          !discontinuity &&
          (_anchor - previousAnchor).abs() == 1) {
        _fromStep = _anchor - previousFocus;
        _motion.forward(from: 0);
      } else {
        _motion.value = 1;
      }
      setState(() {});
    } else if (discontinuity) {
      _motion.value = 1;
    }
  }

  void _seek() {
    _snapNextPosition = true;
    _position.seek();
    _motion.value = 1;
    _resetBrowse();
  }

  void _resetBrowse() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _scrollDistance = 0;
    if (_manualAnchor != null && mounted) {
      _motion.value = 1;
      setState(() => _manualAnchor = null);
    }
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = _dragging
        ? null
        : Timer(const Duration(milliseconds: 2500), _resetBrowse);
  }

  void _scroll(double delta) {
    if (!delta.isFinite || delta == 0) return;
    if (_scrollDistance * delta < 0) _scrollDistance = 0;
    _scrollDistance += delta;
    final steps = (_scrollDistance / 70).truncate();
    _scrollDistance -= steps * 70;
    if (steps != 0 && _engine.lineCount > 0) {
      final next = (_anchor + steps.clamp(-5, 5)).clamp(
        0,
        _engine.lineCount - 1,
      );
      if (next != _anchor) {
        _motion.value = 1;
        setState(() => _manualAnchor = next);
      }
    }
    _scheduleReset();
  }

  void _endDrag() {
    _dragging = false;
    _scrollDistance = 0;
    _scheduleReset();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      widget.debugOnStructureBuild?.call();
      final screen = MediaQuery.sizeOf(context);
      final size = Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
        constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
      );
      if (size.isEmpty) return const SizedBox.shrink();
      final fontSize = switch (widget.fontPreset) {
        AppLyricFontPreset.small => 27.0,
        AppLyricFontPreset.medium => 32.0,
        AppLyricFontPreset.large => 37.0,
      };
      final style = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
          .copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0,
          );
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final locale = Localizations.maybeLocaleOf(context);
      final key = (
        size,
        style,
        direction,
        scaler,
        locale,
        _anchor,
        widget.palette,
        widget.highlightColor,
      );
      if (_layoutKey != key) {
        _layoutKey = key;
        final entries = _engine.buildVisibleWindow(
          position: _resolved,
          manualAnchorIndex: _anchor,
          before: 3,
          after: 3,
        );
        _rows = entries.map((entry) {
          TextPainter paragraph(
            String text,
            TextStyle textStyle,
            double heightFraction,
          ) => TextPainter(
            text: TextSpan(text: text, style: textStyle),
            textDirection: direction,
            textAlign: TextAlign.center,
            textScaler: scaler,
            locale: locale,
            maxLines:
                (size.height *
                        heightFraction /
                        scaler.scale(textStyle.fontSize! * 1.25))
                    .floor()
                    .clamp(1, 12),
            ellipsis: '…',
          )..layout(maxWidth: math.max(1, size.width - 64));
          final base = paragraph(
            entry.line.text,
            style.copyWith(
              color: widget.palette.foreground.withValues(alpha: 0.72),
            ),
            0.30,
          );
          final highlight = paragraph(
            entry.line.text,
            style.copyWith(
              color: widget.highlightColor ?? widget.palette.accent,
            ),
            0.30,
          );
          final auxiliary = entry.line.translation.trim().isNotEmpty
              ? entry.line.translation
              : entry.line.romanization;
          final subtitle = auxiliary.isEmpty
              ? null
              : paragraph(
                  auxiliary,
                  style.copyWith(
                    fontSize: fontSize * 0.48,
                    fontWeight: FontWeight.w400,
                    color: widget.palette.secondaryForeground,
                  ),
                  0.14,
                );
          final tokens = buildMonetDisplayTokens(entry.line);
          final row = FoldPaintRow(
            entry: entry,
            base: base,
            highlight: highlight,
            subtitle: subtitle,
            tokens: tokens,
            boxes: tokens
                .map(
                  (token) => base.getBoxesForSelection(
                    TextSelection(
                      baseOffset: token.startOffset,
                      extentOffset: token.endOffset,
                    ),
                  ),
                )
                .toList(),
          );
          _owner.own(row);
          widget.debugOnTextLayout?.call();
          return row;
        }).toList();
        _owner.retain(_rows);
      }
      final painter = FoldLyricPainter(
        rows: _rows,
        anchor: _anchor,
        activeIndex: _resolved.activeIndex,
        viewport: size,
        position: _position,
        motion: _motion,
        fromStep: _fromStep,
        documentOffset: widget.document.offset,
        wordHighlight: widget.enableWordByWordLyric,
        debugOnPaint: widget.debugOnPaint,
      );
      _painter = painter;
      final selected = _rows
          .where((row) => row.entry.index == _anchor)
          .firstOrNull;
      void seekRow(FoldPaintRow? row) {
        if (row == null || row.entry.isInterlude || widget.onSeek == null) {
          return;
        }
        final target =
            row.entry.line.start -
            Duration(milliseconds: widget.document.offset);
        _seek();
        widget.onSeek!(target.isNegative ? Duration.zero : target);
      }

      return RepaintBoundary(
        key: const ValueKey('fold-lyric-repaint-boundary'),
        child: Semantics(
          label: selected == null
              ? null
              : '${selected.entry.line.text}\n${selected.entry.line.translation}\n${selected.entry.line.romanization}',
          button: widget.onSeek != null,
          onTap: widget.onSeek == null ? null : () => seekRow(selected),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) _scroll(event.scrollDelta.dy);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                _dragging = true;
                _scrollDistance = 0;
                _resetTimer?.cancel();
              },
              onVerticalDragUpdate: (details) => _scroll(-details.delta.dy),
              onVerticalDragEnd: (_) => _endDrag(),
              onVerticalDragCancel: _endDrag,
              onTapUp: widget.onSeek == null
                  ? null
                  : (details) => seekRow(painter.rowAt(details.localPosition)),
              child: CustomPaint(
                key: const ValueKey('fold-lyric-painter'),
                size: size,
                painter: painter,
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _resetTimer?.cancel();
    widget.seekListenable?.removeListener(_seek);
    _positionSubscription.close();
    _playbackSubscription.close();
    _position.dispose();
    _motion.dispose();
    _owner.dispose();
    super.dispose();
  }
}
