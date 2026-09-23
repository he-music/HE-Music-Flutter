import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/kinetic_lyric_layout.dart';
import '../helpers/lyric_painter_owner.dart';
import '../helpers/lyric_position_smoother.dart';
import '../helpers/monet_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'kinetic_lyric_painter.dart';

class KineticLyricRail extends ConsumerStatefulWidget {
  const KineticLyricRail({
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
  ConsumerState<KineticLyricRail> createState() => _KineticLyricRailState();
}

class _KineticLyricRailState extends ConsumerState<KineticLyricRail>
    with TickerProviderStateMixin {
  final _owner = LyricPainterOwner();
  late MonetLyricLayoutEngine _engine;
  late MonetLyricPosition _resolved;
  late LyricPositionSmoother _position;
  late ProviderSubscription<Duration> _positionSubscription;
  late ProviderSubscription<bool> _playbackSubscription;
  bool _playing = false;
  bool _allowed = true;
  bool _snapNext = false;
  int? _manualAnchor;
  Timer? _resetTimer;
  double _distance = 0;
  bool _dragging = false;
  Duration _trailStart = Duration.zero;
  Object? _layoutKey;
  Object? _layoutContext;
  List<KineticPaintLine> _rows = [];

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
    final initial = ref.read(lyricPositionProvider);
    _resolved = _engine.resolvePosition(initial);
    _position = LyricPositionSmoother(vsync: this, position: initial);
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
  void didUpdateWidget(covariant KineticLyricRail oldWidget) {
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
      _trailStart = _resolved.timelinePosition;
      _manualAnchor = null;
      _resetTimer?.cancel();
      _distance = 0;
      _layoutKey = null;
      _layoutContext = null;
    }
  }

  void _updatePosition(Duration next) {
    final oldAnchor = _anchor;
    final delta = next - _resolved.playbackPosition;
    final discontinuity =
        _snapNext ||
        delta.isNegative ||
        delta > const Duration(milliseconds: 250);
    _snapNext = false;
    _resolved = _engine.resolvePosition(next);
    _position.update(next, discontinuity: discontinuity);
    if (discontinuity) _trailStart = _resolved.timelinePosition;
    if (_anchor != oldAnchor || discontinuity) {
      // A boundary updates the visible window; the camera shares playback time.
      setState(() {});
    }
  }

  void _seek() {
    _snapNext = true;
    _position.seek();
    _trailStart = _resolved.timelinePosition;
    _resetBrowse();
    setState(() {});
  }

  void _resetBrowse() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _distance = 0;
    if (_manualAnchor != null && mounted) {
      setState(() => _manualAnchor = null);
    }
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    if (!_dragging) {
      _resetTimer = Timer(const Duration(milliseconds: 2500), _resetBrowse);
    }
  }

  void _browse(double delta) {
    if (!delta.isFinite || _engine.lineCount == 0) return;
    if (_distance * delta < 0) _distance = 0;
    _distance += delta;
    final steps = (_distance / 70).truncate();
    _distance -= steps * 70;
    final next = (_anchor + steps.clamp(-5, 5)).clamp(0, _engine.lineCount - 1);
    if (next != _anchor) {
      setState(() => _manualAnchor = next);
    }
    _scheduleReset();
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
      final baseFontSize = switch (widget.fontPreset) {
        AppLyricFontPreset.small => 27.0,
        AppLyricFontPreset.medium => 33.0,
        AppLyricFontPreset.large => 39.0,
      };
      final fontSize =
          baseFontSize *
          math.min(
            (size.width / 390).clamp(.85, 1.9),
            (size.height / 340).clamp(.85, 1.9),
          );
      final color = widget.highlightColor ?? const Color(0xffffe6ba);
      final themeStyle =
          Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
      final style = themeStyle.copyWith(
        fontSize: fontSize,
        fontFamily: 'Songti SC',
        fontFamilyFallback: [
          'STSong',
          'Noto Serif CJK SC',
          if (themeStyle.fontFamily != null) themeStyle.fontFamily!,
          ...?themeStyle.fontFamilyFallback,
        ],
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: Color.lerp(widget.palette.foreground, color, .4),
        letterSpacing: 0,
      );
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      final wordHighlight =
          widget.enableWordByWordLyric && _manualAnchor == null;
      final key = (
        size,
        style,
        scaler,
        direction,
        locale,
        _anchor,
        wordHighlight,
        _allowed,
      );
      final contextKey = (size, style, scaler, direction, locale);
      if (_layoutKey != key) {
        final reusable = _layoutContext == contextKey
            ? {for (final row in _rows) row.entry.index: row}
            : <int, KineticPaintLine>{};
        _layoutKey = key;
        _layoutContext = contextKey;
        final gap = (scaler.scale(fontSize) * 1.15).clamp(28.0, 52.0);
        // Prepare one screen beyond either end of the active sentence. Rows
        // entering at the next boundary are already off-screen, never popped in.
        final capacity = (size.height / gap).ceil() + 2;
        final entries = _engine.buildVisibleWindow(
          position: _resolved,
          manualAnchorIndex: _anchor,
          before: capacity,
          after: capacity,
        );
        KineticPaintLine resolve(MonetVisibleLyricLine entry) {
          final cached = reusable[entry.index];
          if (cached != null) {
            cached.y = 0;
            return cached;
          }
          final row = layoutKineticLine(
            entry: entry,
            size: size,
            style: style,
            scaler: scaler,
            direction: direction,
            locale: locale,
          );
          _owner.own(row);
          widget.debugOnTextLayout?.call();
          return row;
        }

        ({double top, double bottom}) bounds(KineticPaintLine row) =>
            row.bounds(wordHighlight && _allowed && row.hasTiming);
        double step(KineticPaintLine previous, KineticPaintLine next) =>
            bounds(previous).bottom + gap - bounds(next).top;
        _rows = [];
        final focal = entries.indexWhere((entry) => entry.index == _anchor);
        if (focal >= 0) {
          final current = resolve(entries[focal]);
          _rows.add(current);
          final lowerLimit = bounds(current).bottom + size.height;
          for (var i = focal + 1; i < entries.length; i++) {
            final previous = _rows.last;
            final row = resolve(entries[i]);
            row.y = previous.y + step(previous, row);
            _rows.add(row);
            if (row.y + bounds(row).top > lowerLimit) break;
          }
          final earlier = <KineticPaintLine>[];
          var next = current;
          for (var i = focal - 1; i >= 0; i--) {
            final row = resolve(entries[i]);
            row.y = next.y - step(row, next);
            earlier.add(row);
            next = row;
            if (row.y + bounds(row).bottom < -size.height) break;
          }
          _rows = [...earlier.reversed, ..._rows];
        }
        _owner.retain(_rows);
      }
      final painter = KineticLyricPainter(
        rows: _rows,
        anchor: _anchor,
        position: _position,
        followPlayback: _manualAnchor == null,
        documentOffset: widget.document.offset,
        wordHighlight: wordHighlight,
        reducedMotion: !_allowed,
        color: style.color!,
        trailStart: _trailStart,
        debugOnPaint: widget.debugOnPaint,
      );
      final current = _rows.where((r) => r.entry.index == _anchor).firstOrNull;
      return RepaintBoundary(
        key: const ValueKey('kinetic-lyric-repaint-boundary'),
        child: Semantics(
          label: current?.entry.line.text,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(
                  event,
                  (_) => _browse(event.scrollDelta.dy),
                );
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                _dragging = true;
                _distance = 0;
                _resetTimer?.cancel();
              },
              onVerticalDragUpdate: (details) => _browse(-details.delta.dy),
              onVerticalDragEnd: (_) {
                _dragging = false;
                _scheduleReset();
              },
              onVerticalDragCancel: () {
                _dragging = false;
                _scheduleReset();
              },
              onTapUp: widget.onSeek == null
                  ? null
                  : (details) {
                      final row = painter.rowAt(details.localPosition, size);
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
                key: const ValueKey('kinetic-lyric-painter'),
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
    _owner.dispose();
    super.dispose();
  }
}
