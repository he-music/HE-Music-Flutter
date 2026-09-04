import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/tilt_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'tilt_lyric_painter.dart';

class TiltLyricRail extends ConsumerStatefulWidget {
  const TiltLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    this.highlightColor,
    required this.onSeek,
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
  final Color? highlightColor;
  final ValueChanged<Duration>? onSeek;
  final String? documentIdentity;
  final Listenable? seekListenable;

  @visibleForTesting
  final VoidCallback? debugOnStructureBuild;
  @visibleForTesting
  final VoidCallback? debugOnTextLayout;
  @visibleForTesting
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<TiltLyricRail> createState() => _TiltLyricRailState();
}

class _TiltLyricRailState extends ConsumerState<TiltLyricRail> {
  static const _manualResetDelay = Duration(milliseconds: 1800);

  late TiltLyricLayoutEngine _engine;
  late final ValueNotifier<Duration> _positionNotifier;
  late final ProviderSubscription<Duration> _positionSubscription;
  Timer? _manualResetTimer;
  int? _activeIndex;
  int? _manualAnchorIndex;
  double _dragDistance = 0;
  TiltLyricRenderData? _renderData;
  int? _renderSignature;

  @override
  void initState() {
    super.initState();
    _engine = TiltLyricLayoutEngine.fromDocument(widget.document);
    final position = ref.read(lyricPositionProvider);
    _positionNotifier = ValueNotifier<Duration>(position);
    _activeIndex = _engine.resolvePosition(position).activeIndex;
    _positionSubscription = ref.listenManual<Duration>(
      lyricPositionProvider,
      (previous, next) => _handlePosition(next),
    );
    widget.seekListenable?.addListener(_resetManualBrowse);
  }

  @override
  void didUpdateWidget(covariant TiltLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekListenable != widget.seekListenable) {
      oldWidget.seekListenable?.removeListener(_resetManualBrowse);
      widget.seekListenable?.addListener(_resetManualBrowse);
    }
    final nextEngine = TiltLyricLayoutEngine.fromDocument(widget.document);
    if (oldWidget.documentIdentity != widget.documentIdentity ||
        nextEngine.documentSignature != _engine.documentSignature) {
      _engine = nextEngine;
      _activeIndex = _engine
          .resolvePosition(_positionNotifier.value)
          .activeIndex;
      _manualAnchorIndex = null;
      _manualResetTimer?.cancel();
      _layoutCache.clear();
      _resetRenderData();
    } else if (oldWidget.palette != widget.palette ||
        oldWidget.highlightColor != widget.highlightColor ||
        oldWidget.fontPreset != widget.fontPreset) {
      _resetRenderData();
    }
  }

  void _resetRenderData() {
    _renderData = null;
    _renderSignature = null;
  }

  @override
  void dispose() {
    _manualResetTimer?.cancel();
    widget.seekListenable?.removeListener(_resetManualBrowse);
    _positionSubscription.close();
    _positionNotifier.dispose();
    super.dispose();
  }

  void _handlePosition(Duration position) {
    if (!mounted) return;
    _positionNotifier.value = position;
    final nextIndex = _engine.resolvePosition(position).activeIndex;
    if (_manualAnchorIndex == null && nextIndex != _activeIndex) {
      setState(() => _activeIndex = nextIndex);
    }
  }

  void _resetManualBrowse() {
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    if (_manualAnchorIndex != null && mounted) {
      setState(() => _manualAnchorIndex = null);
    }
  }

  int? get _selectedIndex => _manualAnchorIndex ?? _activeIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.hasBoundedHeight ? constraints.maxHeight : 240,
        );
        if (size.isEmpty) return const SizedBox.shrink();
        final index = _selectedIndex;
        final line = index == null ? null : _engine.lineAt(index);
        final compact = size.width < 340 || size.height < 280;
        final fontSize = _fontSize(widget.fontPreset, compact);
        final baseStyle =
            (Theme.of(context).textTheme.bodyLarge ??
                    const TextStyle(fontSize: 16))
                .copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  height: 1.15,
                );
        final tiltStyle = baseStyle.copyWith(
          fontStyle: FontStyle.italic,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        );
        final options = TiltLyricLayoutOptions(
          stageSize: Size(
            size.width,
            mathMax(
              size.height -
                  (line?.translation.trim().isNotEmpty == true ? 34 : 0),
              1,
            ),
          ),
          normalStyle: baseStyle,
          tiltStyle: tiltStyle,
          textDirection: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
          textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
          horizontalInset: compact ? 16 : 24,
          verticalInset: compact ? 12 : 20,
        );
        final layout = index == null
            ? null
            : _engine.layoutLine(
                sourceLineIndex: index,
                options: options,
                cache: _layoutCache,
              );
        final renderData = _resolveRenderData(
          layout: layout,
          normalStyle: baseStyle,
          tiltStyle: tiltStyle,
          options: options,
        );
        final auxiliary = line?.translation.trim().isNotEmpty == true
            ? line!.translation
            : line?.romanization.trim().isNotEmpty == true
            ? line!.romanization
            : null;
        return RepaintBoundary(
          key: const ValueKey<String>('tilt-lyric-repaint-boundary'),
          child: Semantics(
            container: true,
            button: widget.onSeek != null,
            label: line == null
                ? null
                : auxiliary == null
                ? line.text
                : '${line.text}\n$auxiliary',
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _moveManual(event.scrollDelta.dy);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: layout == null
                    ? null
                    : (details) => _handleTap(layout, details.localPosition),
                onVerticalDragStart: (_) => _dragDistance = 0,
                onVerticalDragUpdate: (details) {
                  _dragDistance += details.primaryDelta ?? 0;
                  if (_dragDistance.abs() >= 48) {
                    _moveManual(_dragDistance);
                    _dragDistance = 0;
                  }
                },
                onVerticalDragEnd: (_) => _restartManualResetTimer(),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      key: const ValueKey<String>('tilt-lyric-painter'),
                      painter: TiltLyricPainter(
                        data: renderData,
                        timelinePosition: _positionNotifier.value,
                        revealAnimation: widget.enableWordByWordLyric,
                        positionListenable: _positionNotifier,
                        onPaint: widget.debugOnPaint,
                      ),
                    ),
                    if (auxiliary != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 4,
                        child: Text(
                          auxiliary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: baseStyle.copyWith(
                            fontSize: fontSize * 0.34,
                            fontWeight: FontWeight.w500,
                            color: widget.palette.secondaryForeground
                                .withValues(alpha: 0.76),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TiltLyricRenderData _resolveRenderData({
    required TiltLyricLineLayout? layout,
    required TextStyle normalStyle,
    required TextStyle tiltStyle,
    required TiltLyricLayoutOptions options,
  }) {
    final signature = Object.hashAll(<Object?>[
      layout?.cacheKey,
      normalStyle,
      tiltStyle,
      widget.palette,
      widget.highlightColor,
      options.textDirection,
      options.locale,
      options.textScaleFactor,
    ]);
    final cached = _renderData;
    if (cached != null && signature == _renderSignature) return cached;

    final next = buildTiltLyricRenderData(
      layout: layout,
      normalStyle: normalStyle,
      tiltStyle: tiltStyle,
      palette: widget.palette,
      highlightColor: widget.highlightColor,
      textDirection: options.textDirection,
      locale: options.locale,
      textScaleFactor: options.textScaleFactor,
      debugOnTextLayout: widget.debugOnTextLayout,
    );
    _renderData = next;
    _renderSignature = signature;
    widget.debugOnStructureBuild?.call();
    return next;
  }

  final TiltLyricLayoutCache _layoutCache = TiltLyricLayoutCache();

  void _handleTap(TiltLyricLineLayout layout, Offset position) {
    if (_engine.isInterludeAt(layout.sourceLineIndex) ||
        layout.segments.every(
          (segment) => !segment.hitRect.contains(position),
        )) {
      return;
    }
    final onSeek = widget.onSeek;
    if (onSeek == null) return;
    final target = _engine.seekPositionFor(layout.sourceLineIndex);
    onSeek(target);
    _resetManualBrowse();
  }

  void _moveManual(double delta) {
    if (_engine.lineCount == 0) return;
    final current = _selectedIndex ?? 0;
    final direction = delta > 0 ? 1 : -1;
    final next = (current + direction).clamp(0, _engine.lineCount - 1);
    if (next == current) return;
    setState(() => _manualAnchorIndex = next);
    _restartManualResetTimer();
  }

  void _restartManualResetTimer() {
    _manualResetTimer?.cancel();
    if (_manualAnchorIndex == null) return;
    _manualResetTimer = Timer(_manualResetDelay, _resetManualBrowse);
  }

  double _fontSize(AppLyricFontPreset preset, bool compact) {
    switch (preset) {
      case AppLyricFontPreset.small:
        return compact ? 34 : 42;
      case AppLyricFontPreset.medium:
        return compact ? 40 : 48;
      case AppLyricFontPreset.large:
        return compact ? 46 : 56;
    }
  }

  double mathMax(double a, double b) => a > b ? a : b;
}
