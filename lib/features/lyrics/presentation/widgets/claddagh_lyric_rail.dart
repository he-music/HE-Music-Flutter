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
import '../helpers/claddagh_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'claddagh_lyric_painter.dart';

// Player-owned resources and subscriptions stay local to the orbit rail.
class CladdaghLyricRail extends ConsumerStatefulWidget {
  const CladdaghLyricRail({
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
  ConsumerState<CladdaghLyricRail> createState() => _CladdaghLyricRailState();
}

class _CladdaghLyricRailState extends ConsumerState<CladdaghLyricRail>
    with TickerProviderStateMixin {
  final _owner = LyricPainterOwner();
  late MonetLyricLayoutEngine _engine;
  late LyricPositionSmoother _position;
  late AnimationController _motion;
  late ProviderSubscription<Duration> _positionSubscription;
  late ProviderSubscription<bool> _playbackSubscription;
  late MonetLyricPosition _resolved;
  int? _manualAnchor;
  Timer? _resetTimer;
  bool _playing = false;
  bool _snapNextPosition = false;
  bool _allowed = true;
  double _fromAngle = 0;
  double _drag = 0;
  double _wheelDistance = 0;
  bool _dragging = false;
  Object? _layoutKey;
  List<CladdaghPaintRow> _rows = [];
  List<double> _angles = [];
  CladdaghLyricPainter? _painter;

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
      duration: const Duration(milliseconds: 620),
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
  void didUpdateWidget(covariant CladdaghLyricRail oldWidget) {
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
      _wheelDistance = 0;
      _drag = 0;
      _dragging = false;
      _motion.value = 1;
      _layoutKey = null;
    }
  }

  /// Only line boundaries rebuild the small rail; samples and spring frames repaint.
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
      if (_playing &&
          _allowed &&
          !discontinuity &&
          (_anchor - oldAnchor).abs() == 1) {
        final target = _rows.indexWhere((row) => row.entry.index == _anchor);
        _fromAngle = target < 0
            ? 0
            : _angles[target] + (_painter?.angleOffset ?? 0);
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
    _wheelDistance = 0;
    _drag = 0;
    if (_manualAnchor != null && mounted) setState(() => _manualAnchor = null);
  }

  void _scheduleBrowseReset() {
    _resetTimer?.cancel();
    _resetTimer = _dragging
        ? null
        : Timer(const Duration(milliseconds: 2500), _resetBrowse);
  }

  /// Device event frequency must not determine the number of browsed lines.
  void _scroll(double delta) {
    if (!delta.isFinite || delta == 0) return;
    if (_wheelDistance * delta < 0) _wheelDistance = 0;
    _wheelDistance += delta;
    final steps = (_wheelDistance / 90).truncate();
    _wheelDistance -= steps * 90;
    _browse(steps.clamp(-5, 5));
    _scheduleBrowseReset();
  }

  void _browse(int steps) {
    if (_engine.lineCount == 0 || steps == 0) return;
    final next = (_anchor + steps).clamp(0, _engine.lineCount - 1);
    if (next == _anchor) return;
    _motion.value = 1;
    setState(() => _manualAnchor = next);
  }

  void _startDrag() {
    _dragging = true;
    _drag = 0;
    _wheelDistance = 0;
    _resetTimer?.cancel();
    _resetTimer = null;
  }

  void _updateDrag(double delta) {
    if (_drag * delta < 0) _drag = 0;
    _drag += delta;
    final steps = (_drag / 60).truncate();
    _drag -= steps * 60;
    _browse(steps.clamp(-5, 5));
  }

  void _endDrag() {
    _dragging = false;
    _drag = 0;
    _scheduleBrowseReset();
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
      final geometry = CladdaghOrbitGeometry(size);
      final fontSize = switch (widget.fontPreset) {
        AppLyricFontPreset.small => 23.0,
        AppLyricFontPreset.medium => 27.0,
        AppLyricFontPreset.large => 31.0,
      };
      final style = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
          .copyWith(
            fontSize: fontSize,
            height: 1.2,
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
          after: 2,
        );
        _rows = entries.map((entry) {
          final opacity = entry.index == _anchor
              ? 1.0
              : (0.65 - (entry.index - _anchor).abs() * 0.12).clamp(0.12, 0.65);
          TextPainter paragraph(String text, TextStyle textStyle) {
            final p = TextPainter(
              text: TextSpan(text: text, style: textStyle),
              textDirection: direction,
              textScaler: scaler,
              locale: locale,
              maxLines:
                  (size.height *
                          (textStyle.fontSize == fontSize ? 0.60 : 0.20) /
                          scaler.scale((textStyle.fontSize ?? fontSize) * 1.2))
                      .floor()
                      .clamp(1, 20),
              ellipsis: '…',
            )..layout(maxWidth: math.max(1, size.width - 48));
            return p;
          }

          final auxiliary = entry.line.translation.trim().isNotEmpty
              ? entry.line.translation
              : entry.line.romanization;
          final subtitle = auxiliary.isEmpty || entry.index != _anchor
              ? null
              : paragraph(
                  auxiliary,
                  style.copyWith(
                    fontSize: fontSize * 0.52,
                    fontWeight: FontWeight.w400,
                    color: widget.palette.secondaryForeground.withValues(
                      alpha: opacity,
                    ),
                  ),
                );
          final tokens = buildCladdaghGlyphs(entry.line);
          TextPainter glyph(String text, Color color) => TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(color: color),
            ),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
          )..layout();
          final glyphs = tokens
              .map(
                (t) => glyph(
                  t.text,
                  widget.palette.foreground.withValues(
                    alpha: entry.index == _anchor ? 1 : 0.32,
                  ),
                ),
              )
              .toList();
          final highlights = tokens
              .map(
                (t) => glyph(
                  t.text,
                  widget.highlightColor ?? widget.palette.accent,
                ),
              )
              .toList();
          final widths = glyphs
              .map((g) => (g.width + scaler.scale(fontSize) * 0.22) * 1.55)
              .toList();
          final total = widths.fold(0.0, (a, b) => a + b);
          final compression = math.min(
            1.0,
            geometry.radius * 4.25 / math.max(1, total),
          );
          var cursor = -total / 2;
          final glyphAngles = widths.map((width) {
            final angle = (cursor + width / 2) / geometry.radius * compression;
            cursor += width;
            return angle;
          }).toList();
          final row = CladdaghPaintRow(
            entry: entry,
            subtitle: subtitle,
            tokens: tokens,
            glyphs: glyphs,
            highlights: highlights,
            angles: glyphAngles,
            glyphScale: compression,
          );
          _owner.own(row);
          widget.debugOnTextLayout?.call();
          return row;
        }).toList();
        _owner.retain(_rows);
        _angles = _rows
            .map((row) => (row.entry.index - _anchor) * math.pi)
            .toList();
      }
      final painter = CladdaghLyricPainter(
        rows: _rows,
        anchor: _anchor,
        activeIndex: _resolved.activeIndex,
        geometry: geometry,
        angles: _angles,
        positionListenable: _position,
        motion: _motion,
        fromAngle: _fromAngle,
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
        key: const ValueKey('claddagh-lyric-repaint-boundary'),
        child: Semantics(
          label: selected == null
              ? null
              : '${selected.entry.line.text}\n${selected.entry.line.translation}\n${selected.entry.line.romanization}',
          button: widget.onSeek != null,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) _scroll(event.scrollDelta.dy);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _startDrag(),
              onVerticalDragUpdate: (details) => _updateDrag(-details.delta.dy),
              onVerticalDragEnd: (_) => _endDrag(),
              onVerticalDragCancel: _endDrag,
              onTapUp: widget.onSeek == null
                  ? null
                  : (details) {
                      final row = painter.rowAt(details.localPosition);
                      if (row == null || row.entry.isInterlude) return;
                      final target =
                          row.entry.line.start -
                          Duration(milliseconds: widget.document.offset);
                      _seek();
                      widget.onSeek!(
                        target.isNegative ? Duration.zero : target,
                      );
                    },
              child: CustomPaint(
                key: const ValueKey('claddagh-lyric-painter'),
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
