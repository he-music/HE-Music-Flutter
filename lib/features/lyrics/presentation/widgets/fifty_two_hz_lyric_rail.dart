import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ClipOp;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_line.dart';
import '../helpers/fifty_two_hz_field.dart';
import '../helpers/lyric_position_smoother.dart';
import '../helpers/monet_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'single_line_lyric.dart';

class FiftyTwoHzLyricRail extends ConsumerStatefulWidget {
  const FiftyTwoHzLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    this.highlightColor,
    this.onSeek,
    this.seekListenable,
    super.key,
  });

  final LyricDocument document;
  final AppLyricFontPreset fontPreset;
  final bool enableWordByWordLyric;
  final PlayerScenePalette palette;
  final Color? highlightColor;
  final ValueChanged<Duration>? onSeek;
  final Listenable? seekListenable;

  @override
  ConsumerState<FiftyTwoHzLyricRail> createState() =>
      _FiftyTwoHzLyricRailState();
}

class _FiftyTwoHzLyricRailState extends ConsumerState<FiftyTwoHzLyricRail>
    with SingleTickerProviderStateMixin {
  late MonetLyricLayoutEngine _engine;
  late LyricPositionSmoother _position;
  late ProviderSubscription<Duration> _positionSubscription;
  late ProviderSubscription<bool> _playbackSubscription;
  Duration _lastPosition = Duration.zero;
  MonetVisibleLyricLine? _line;
  bool _playing = false;
  bool _animate = false;
  bool _seekPending = false;
  Object? _geometryKey;
  _LineLayout? _layout;
  _LineLayout? _attemptedLayout;
  bool _fieldPending = false;
  _Ripple? _current;
  _Ripple? _outgoing;
  Duration? _outgoingStop;

  @override
  void initState() {
    super.initState();
    _engine = MonetLyricLayoutEngine(widget.document);
    _lastPosition = ref.read(lyricPositionProvider);
    _line = _resolveLine(_lastPosition);
    _position = LyricPositionSmoother(vsync: this, position: _lastPosition);
    _playbackSubscription = ref.listenManual(lyricPlaybackActiveProvider, (
      _,
      playing,
    ) {
      _playing = playing;
      _position.enabled = _playing && _animate;
    }, fireImmediately: true);
    _positionSubscription = ref.listenManual(
      lyricPositionProvider,
      (_, position) => _updatePosition(position),
    );
    widget.seekListenable?.addListener(_seek);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!animate && _animate) _clearFields();
    _animate = animate;
    _position.enabled = _playing && _animate;
  }

  @override
  void didUpdateWidget(covariant FiftyTwoHzLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekListenable != widget.seekListenable) {
      oldWidget.seekListenable?.removeListener(_seek);
      widget.seekListenable?.addListener(_seek);
    }
    if (!identical(oldWidget.document, widget.document)) {
      _engine = MonetLyricLayoutEngine(widget.document);
      _lastPosition = ref.read(lyricPositionProvider);
      _line = null;
      _line = _resolveLine(_lastPosition);
      _position.snap(_lastPosition);
      _geometryKey = null;
      _clearFields();
    }
  }

  Duration get _offset => Duration(milliseconds: widget.document.offset);

  MonetVisibleLyricLine? _resolveLine(Duration position) {
    final resolved = _engine.resolvePosition(position);
    final index =
        resolved.activeIndex ?? resolved.recentIndex ?? resolved.upcomingIndex;
    if (index == null) return null;
    if (index == _line?.index) return _line;
    return _engine
        .buildVisibleWindow(
          position: resolved,
          manualAnchorIndex: index,
          before: 0,
          after: 0,
        )
        .single;
  }

  void _updatePosition(Duration position) {
    final next = _resolveLine(position);
    final delta = position - _lastPosition;
    final jump =
        _seekPending ||
        delta.isNegative ||
        delta > const Duration(milliseconds: 250);
    _seekPending = false;
    _lastPosition = position;
    final lineChanged = next?.index != _line?.index;
    if (lineChanged || jump) {
      setState(() {
        if (jump) {
          _dropOutgoing();
          if (lineChanged) {
            _current?.field.dispose();
            _current = null;
          }
        } else if (_current case final current?) {
          _dropOutgoing();
          _outgoing = current;
          _outgoingStop = next == null ? position : next.line.start - _offset;
          _current = null;
        }
        _line = next;
      });
    }
    _position.update(position, discontinuity: lineChanged || jump);
  }

  void _seek() {
    _seekPending = true;
    _position.seek();
    if (_outgoing != null) setState(_dropOutgoing);
  }

  void _dropOutgoing() {
    _outgoing?.field.dispose();
    _outgoing = null;
    _outgoingStop = null;
  }

  void _clearFields() {
    _dropOutgoing();
    _current?.field.dispose();
    _current = null;
    _attemptedLayout = null;
  }

  void _prepareField() {
    final layout = _layout;
    if (!_animate ||
        _fieldPending ||
        layout == null ||
        identical(layout, _attemptedLayout)) {
      return;
    }
    _attemptedLayout = layout;
    _fieldPending = true;
    unawaited(_loadField(layout));
  }

  Future<void> _loadField(_LineLayout layout) async {
    try {
      final field = await FiftyTwoHzField.rasterize(
        bounds: layout.rippleBounds,
        reach: layout.reach,
        glyphGap: layout.glyphGap,
        paintMask: layout.paintMask,
      );
      if (field == null) return;
      if (!mounted ||
          !_animate ||
          !identical(layout, _layout) ||
          !identical(layout.line, _line?.line)) {
        field.dispose();
        return;
      }
      setState(
        () => _current = _Ripple(field, layout.reach, layout.start - _offset),
      );
    } catch (error) {
      debugPrint('52Hz glyph field unavailable: $error');
    } finally {
      _fieldPending = false;
      if (mounted) _prepareField();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.hasBoundedHeight ? constraints.maxHeight : 300,
      );
      if (size.isEmpty || !size.isFinite) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final style = (theme.textTheme.headlineMedium ?? const TextStyle())
          .copyWith(
            fontSize: _fontSize(widget.fontPreset, size),
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: 0,
            color: widget.palette.foreground,
          );
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      final accent = widget.highlightColor ?? widget.palette.accent;
      final geometry = (
        size,
        style,
        scaler,
        direction,
        locale,
        accent,
        widget.enableWordByWordLyric,
        widget.palette.secondaryForeground,
      );
      final line = _line?.line;
      if (geometry != _geometryKey ||
          !identical(line, _layout?.line) ||
          _layout == null) {
        if (geometry != _geometryKey) _clearFields();
        _geometryKey = geometry;
        final oldLayout = _layout;
        _layout = _LineLayout.create(
          size,
          line,
          style,
          scaler,
          direction,
          locale,
          accent,
          widget.enableWordByWordLyric,
          widget.palette.secondaryForeground,
        );
        if (oldLayout != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => oldLayout.dispose(),
          );
        }
      }
      _prepareField();
      final seek = widget.onSeek;
      final tap = line == null || seek == null
          ? null
          : () {
              final target = line.start - _offset;
              seek(target.isNegative ? Duration.zero : target);
            };
      return Semantics(
        label: [
          if (line != null) line.text,
          if (line?.translation.isNotEmpty ?? false) line!.translation,
          if (line?.romanization.isNotEmpty ?? false) line!.romanization,
        ].join('\n'),
        onTap: tap,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTapUp: tap == null
              ? null
              : (event) {
                  if (_layout?.textBounds
                          .inflate(12)
                          .contains(event.localPosition) ??
                      false) {
                    tap();
                  }
                },
          excludeFromSemantics: true,
          child: RepaintBoundary(
            child: CustomPaint(
              key: _current == null
                  ? null
                  : const ValueKey('52hz-ripples-ready'),
              size: size,
              painter: _FiftyTwoHzPainter(
                layout: _layout!,
                position: _position,
                offset: _offset,
                current: _current,
                previous: _outgoing,
                previousStop: _outgoingStop,
                accent: Color.lerp(accent, widget.palette.foreground, .38)!,
                animate: _animate,
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    widget.seekListenable?.removeListener(_seek);
    _positionSubscription.close();
    _playbackSubscription.close();
    _position.dispose();
    _clearFields();
    _layout?.dispose();
    super.dispose();
  }
}

double _fontSize(AppLyricFontPreset preset, Size size) {
  final scale = switch (preset) {
    AppLyricFontPreset.small => .86,
    AppLyricFontPreset.medium => 1.0,
    AppLyricFontPreset.large => 1.18,
  };
  return (math.min(size.width * .086, size.height * .135).clamp(26.0, 70.0)) *
      scale;
}

class _LineLayout {
  const _LineLayout({
    required this.line,
    required this.start,
    required this.textBounds,
    required this.rippleBounds,
    required this.reach,
    required this.glyphGap,
    this.text,
    this.highlight,
    this.auxiliary,
    this.tokens = const [],
    this.boxes = const [],
  });

  final LyricLine? line;
  final Duration start;
  final Rect textBounds;
  final Rect rippleBounds;
  final double reach;
  final double glyphGap;
  final TextPainter? text;
  final TextPainter? highlight;
  final TextPainter? auxiliary;
  final List<MonetDisplayToken> tokens;
  final List<List<TextBox>> boxes;

  static _LineLayout create(
    Size size,
    LyricLine? line,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    Locale? locale,
    Color accent,
    bool timed,
    Color secondary,
  ) {
    final center = size.center(Offset.zero);
    final reach = (size.longestSide * .30).clamp(110.0, 360.0);
    final width = size.width * .82;
    TextPainter layout(String value, TextStyle textStyle, {int maxLines = 3}) =>
        TextPainter(
          text: TextSpan(text: value, style: textStyle),
          textAlign: TextAlign.center,
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
          maxLines: maxLines,
          ellipsis: '…',
        )..layout(maxWidth: width);
    final tokens = timed && line != null
        ? buildSingleLineLyricTokens(line, null)
        : const <MonetDisplayToken>[];
    final hasTimings = tokens.any((token) => token.hasTiming);
    final text = line == null
        ? null
        : layout(
            line.text,
            style.copyWith(
              color: hasTimings
                  ? style.color?.withValues(alpha: .70)
                  : style.color,
            ),
          );
    final highlight = !hasTimings
        ? null
        : layout(line!.text, style.copyWith(color: accent));
    final details = [
      if (line?.translation.isNotEmpty ?? false) line!.translation,
      if (line?.romanization.isNotEmpty ?? false) line!.romanization,
    ].join('\n');
    final auxiliary = details.isEmpty
        ? null
        : layout(
            details,
            style.copyWith(
              fontSize: (style.fontSize! * .45).clamp(13.0, 24.0),
              color: secondary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
          );
    final bounds = Rect.fromCenter(
      center: center.translate(0, -(auxiliary?.height ?? 0) * .35),
      width: text?.width ?? 7,
      height: text?.height ?? 7,
    );
    final glyphGap = text == null ? 0.0 : scaler.scale(style.fontSize!) * .55;
    final rippleBounds = bounds
        .inflate(reach + glyphGap + 4)
        .intersect(Offset.zero & size);
    return _LineLayout(
      line: line,
      start: line?.start ?? Duration.zero,
      textBounds: bounds,
      rippleBounds: rippleBounds,
      reach: reach,
      glyphGap: glyphGap,
      text: text,
      highlight: highlight,
      auxiliary: auxiliary,
      tokens: tokens,
      boxes: hasTimings
          ? [
              for (final token in tokens)
                text!.getBoxesForSelection(
                  TextSelection(
                    baseOffset: token.startOffset,
                    extentOffset: token.endOffset,
                  ),
                ),
            ]
          : const [],
    );
  }

  void paintMask(Canvas canvas) {
    if (text case final paragraph?) {
      paragraph.paint(canvas, textBounds.topLeft);
    } else {
      canvas.drawOval(textBounds, Paint()..color = Colors.white);
    }
  }

  void dispose() {
    text?.dispose();
    highlight?.dispose();
    auxiliary?.dispose();
  }
}

class _Ripple {
  const _Ripple(this.field, this.reach, this.start);
  final FiftyTwoHzField field;
  final double reach;
  final Duration start;

  void paint(Canvas canvas, Color color, Duration time, {Duration? stop}) {
    final radii = fiftyTwoHzRadii(
      position: time,
      start: start,
      stop: stop,
      reach: reach,
    );
    if (radii != null) field.paint(canvas, color, reach, radii);
  }
}

class _FiftyTwoHzPainter extends CustomPainter {
  _FiftyTwoHzPainter({
    required this.layout,
    required this.position,
    required this.offset,
    required this.current,
    required this.previous,
    required this.previousStop,
    required this.accent,
    required this.animate,
  }) : super(repaint: position);

  final _LineLayout layout;
  final ValueListenable<Duration> position;
  final Duration offset;
  final _Ripple? current;
  final _Ripple? previous;
  final Duration? previousStop;
  final Color accent;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final time = position.value + offset;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (animate) {
      if (previous case final outgoing?) {
        canvas.save();
        canvas.clipRect(
          layout.textBounds.inflate(6),
          clipOp: ClipOp.difference,
        );
        outgoing.paint(canvas, accent, position.value, stop: previousStop);
        canvas.restore();
      }
      current?.paint(canvas, accent, position.value);
    }
    layout.text?.paint(canvas, layout.textBounds.topLeft);
    if (layout.highlight case final highlight?) {
      final path = Path();
      final origin = layout.textBounds.topLeft;
      for (var i = 0; i < layout.tokens.length; i++) {
        final progress = resolveMonetTokenProgress(
          timelinePosition: time,
          token: layout.tokens[i],
        );
        if (progress <= 0) continue;
        for (final box in layout.boxes[i]) {
          final rect = box.toRect().shift(origin);
          final width = rect.width * progress;
          final left = box.direction == TextDirection.rtl
              ? rect.right - width
              : rect.left;
          path.addRect(Rect.fromLTWH(left, rect.top, width, rect.height));
        }
      }
      canvas.save();
      canvas.clipPath(path);
      highlight.paint(canvas, origin);
      canvas.restore();
    }
    if (layout.auxiliary case final text?) {
      text.paint(
        canvas,
        Offset((size.width - text.width) / 2, layout.textBounds.bottom + 12),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FiftyTwoHzPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      current != oldDelegate.current ||
      previous != oldDelegate.previous ||
      previousStop != oldDelegate.previousStop ||
      accent != oldDelegate.accent ||
      offset != oldDelegate.offset ||
      animate != oldDelegate.animate;
}
