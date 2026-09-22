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
import 'star_tunnel_lyric_painter.dart';

class StarTunnelLyricRail extends ConsumerStatefulWidget {
  const StarTunnelLyricRail({
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
  ConsumerState<StarTunnelLyricRail> createState() =>
      _StarTunnelLyricRailState();
}

class _StarTunnelLyricRailState extends ConsumerState<StarTunnelLyricRail>
    with TickerProviderStateMixin {
  final _owner = LyricPainterOwner();
  late MonetLyricLayoutEngine _engine;
  late LyricPositionSmoother _position;
  late AnimationController _motion;
  late ProviderSubscription<Duration> _positionSubscription;
  late ProviderSubscription<bool> _playbackSubscription;
  late MonetLyricPosition _resolved;
  Timer? _resetTimer;
  int? _manualAnchor;
  bool _playing = false;
  bool _allowed = true;
  bool _snapNextPosition = false;
  bool _dragging = false;
  double _browseDistance = 0;
  double _fromDepth = 0;
  Object? _layoutKey;
  List<StarTunnelPaintRow> _rows = [];
  StarTunnelLyricPainter? _painter;

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
  void didUpdateWidget(covariant StarTunnelLyricRail oldWidget) {
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
      _browseDistance = 0;
      _dragging = false;
      _snapNextPosition = false;
      _motion.value = 1;
      _layoutKey = null;
    }
  }

  void _updatePosition(Duration next) {
    final oldAnchor = _anchor;
    final oldActive = _resolved.activeIndex;
    final delta = next - _resolved.playbackPosition;
    final discontinuity =
        _snapNextPosition ||
        delta.isNegative ||
        delta > const Duration(milliseconds: 250);
    _snapNextPosition = false;
    _resolved = _engine.resolvePosition(next);
    _position.update(
      next,
      discontinuity: discontinuity || oldActive != _resolved.activeIndex,
    );
    if (oldAnchor != _anchor || oldActive != _resolved.activeIndex) {
      if (_playing && _allowed && !discontinuity && _anchor - oldAnchor == 1) {
        _fromDepth = 1 + (_painter?.depthOffset ?? 0);
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
    _browseDistance = 0;
    if (_manualAnchor != null && mounted) setState(() => _manualAnchor = null);
  }

  void _browse(double delta, {double threshold = 70}) {
    if (!delta.isFinite || delta == 0 || _engine.lineCount == 0) return;
    if (_browseDistance * delta < 0) _browseDistance = 0;
    _browseDistance += delta;
    final steps = (_browseDistance / threshold).truncate();
    _browseDistance -= steps * threshold;
    final next = (_anchor + steps.clamp(-5, 5)).clamp(0, _engine.lineCount - 1);
    if (next != _anchor) {
      _motion.value = 1;
      setState(() => _manualAnchor = next);
    }
    _scheduleReset();
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = _dragging
        ? null
        : Timer(const Duration(milliseconds: 2500), _resetBrowse);
  }

  void _endDrag() {
    _dragging = false;
    _browseDistance = 0;
    _scheduleReset();
  }

  void _seekRow(StarTunnelPaintRow? row) {
    if (row == null || row.entry.isInterlude || widget.onSeek == null) return;
    final target =
        row.entry.line.start - Duration(milliseconds: widget.document.offset);
    _seek();
    widget.onSeek!(target.isNegative ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      widget.debugOnStructureBuild?.call();
      final size = Size(
        constraints.maxWidth,
        constraints.hasBoundedHeight ? constraints.maxHeight : 300,
      );
      if (size.isEmpty) return const SizedBox.shrink();
      final fontSize = switch (widget.fontPreset) {
        AppLyricFontPreset.small => 24.0,
        AppLyricFontPreset.medium => 28.0,
        AppLyricFontPreset.large => 32.0,
      };
      final style = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
          .copyWith(
            fontSize: fontSize,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          );
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final locale = Localizations.maybeLocaleOf(context);
      final key = (
        size,
        style,
        scaler,
        direction,
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
          before: 1,
          after: 4,
        );
        _rows = entries.map((entry) {
          TextPainter paragraph(
            String text,
            TextStyle textStyle,
            double heightFraction,
          ) =>
              TextPainter(
                text: TextSpan(text: text, style: textStyle),
                textAlign: TextAlign.center,
                textDirection: direction,
                textScaler: scaler,
                locale: locale,
                maxLines:
                    (size.height *
                            heightFraction /
                            scaler.scale(textStyle.fontSize! * 1.25))
                        .floor()
                        .clamp(1, 12),
                ellipsis: '…',
              )..layout(
                minWidth: math.max(1, size.width * 0.84),
                maxWidth: math.max(1, size.width * 0.84),
              );
          final base = paragraph(
            entry.line.text,
            style.copyWith(color: widget.palette.foreground),
            0.20,
          );
          final highlight = paragraph(
            entry.line.text,
            style.copyWith(
              color: widget.highlightColor ?? widget.palette.accent,
            ),
            0.20,
          );
          final auxiliary = entry.line.translation.trim().isNotEmpty
              ? entry.line.translation
              : entry.line.romanization;
          final tokens = buildMonetDisplayTokens(entry.line);
          final row = StarTunnelPaintRow(
            entry: entry,
            base: base,
            highlight: highlight,
            subtitle: auxiliary.isEmpty
                ? null
                : paragraph(
                    auxiliary,
                    style.copyWith(
                      fontSize: fontSize * 0.5,
                      fontWeight: FontWeight.w400,
                      color: widget.palette.secondaryForeground,
                    ),
                    0.17,
                  ),
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
      final painter = StarTunnelLyricPainter(
        rows: _rows,
        anchor: _anchor,
        activeIndex: _resolved.activeIndex,
        positionListenable: _position,
        motion: _motion,
        fromDepth: _fromDepth,
        documentOffset: widget.document.offset,
        wordHighlight: widget.enableWordByWordLyric,
        color: widget.palette.accent,
        debugOnPaint: widget.debugOnPaint,
      );
      _painter = painter;
      final selected = _rows
          .where((row) => row.entry.index == _anchor)
          .firstOrNull;
      return RepaintBoundary(
        key: const ValueKey('star-tunnel-lyric-repaint-boundary'),
        child: Semantics(
          label: selected == null
              ? null
              : '${selected.entry.line.text}\n${selected.entry.line.translation}\n${selected.entry.line.romanization}',
          button: widget.onSeek != null,
          onTap: widget.onSeek == null ? null : () => _seekRow(selected),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _browse(event.scrollDelta.dy, threshold: 90);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                _dragging = true;
                _browseDistance = 0;
                _resetTimer?.cancel();
              },
              onVerticalDragUpdate: (details) => _browse(-details.delta.dy),
              onVerticalDragEnd: (_) => _endDrag(),
              onVerticalDragCancel: _endDrag,
              onTapUp: widget.onSeek == null
                  ? null
                  : (details) =>
                        _seekRow(painter.rowAt(details.localPosition, size)),
              child: CustomPaint(
                key: const ValueKey('star-tunnel-lyric-painter'),
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
