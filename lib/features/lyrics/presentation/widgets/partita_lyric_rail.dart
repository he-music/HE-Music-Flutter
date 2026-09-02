import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/partita_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'partita_lyric_painter.dart';

class PartitaLyricRail extends ConsumerStatefulWidget {
  const PartitaLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    required this.onSeek,
    this.highlightColor,
    this.documentIdentity,
    this.breathingEnabled = true,
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
  final bool breathingEnabled;
  final Listenable? seekListenable;

  @visibleForTesting
  final VoidCallback? debugOnStructureBuild;
  @visibleForTesting
  final VoidCallback? debugOnTextLayout;
  @visibleForTesting
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<PartitaLyricRail> createState() => _PartitaLyricRailState();
}

class _PartitaLyricRailState extends ConsumerState<PartitaLyricRail>
    with TickerProviderStateMixin {
  static const _manualResetDelay = Duration(milliseconds: 1800);
  static const _transitionDuration = Duration(milliseconds: 300);
  static const _breathingDuration = Duration(milliseconds: 7000);
  static const _wheelStep = 64.0;
  static const _dragStep = 48.0;
  static const _preheatMinimumLead = Duration(milliseconds: 180);
  static const _preheatMaximumLead = Duration(milliseconds: 1200);

  late PartitaLyricLayoutEngine _engine;
  late PartitaLyricPosition _structurePosition;
  late final ValueNotifier<Duration> _positionNotifier;
  late final AnimationController _transitionController;
  late final AnimationController _breathingController;
  late final ProviderSubscription<Duration> _positionSubscription;
  final PartitaLyricLayoutCache _layoutCache = PartitaLyricLayoutCache();

  Timer? _manualResetTimer;
  PartitaLyricRenderData? _renderData;
  PartitaLyricRenderData? _previousRenderData;
  PartitaLyricLayoutOptions? _lastLayoutOptions;
  int? _renderSignature;
  int? _manualAnchorIndex;
  double _wheelAccumulator = 0;
  int _wheelDirection = 0;
  double _dragAccumulator = 0;
  int _dragDirection = 0;
  bool _dragMoved = false;
  bool _transitionScheduled = false;
  bool _animationsAllowed = true;

  @override
  void initState() {
    super.initState();
    _engine = PartitaLyricLayoutEngine.fromDocument(widget.document);
    final initialPosition = ref.read(lyricPositionProvider);
    _positionNotifier = ValueNotifier<Duration>(initialPosition);
    _structurePosition = _engine.resolvePosition(initialPosition);
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    );
    _breathingController = AnimationController(
      vsync: this,
      duration: _breathingDuration,
    );
    _positionSubscription = ref.listenManual<Duration>(
      lyricPositionProvider,
      (previous, next) => _handlePosition(next),
      fireImmediately: false,
    );
    widget.seekListenable?.addListener(_handleSeek);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsAllowed =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant PartitaLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekListenable != widget.seekListenable) {
      oldWidget.seekListenable?.removeListener(_handleSeek);
      widget.seekListenable?.addListener(_handleSeek);
    }
    final nextEngine = PartitaLyricLayoutEngine.fromDocument(widget.document);
    if (oldWidget.documentIdentity != widget.documentIdentity ||
        nextEngine.documentSignature != _engine.documentSignature) {
      _manualResetTimer?.cancel();
      _manualResetTimer = null;
      _manualAnchorIndex = null;
      _resetInputAccumulators();
      _layoutCache.clear();
      _engine = nextEngine;
      _structurePosition = _engine.resolvePosition(_positionNotifier.value);
      _lastLayoutOptions = null;
      _resetRenderData();
    } else if (oldWidget.fontPreset != widget.fontPreset ||
        oldWidget.enableWordByWordLyric != widget.enableWordByWordLyric ||
        oldWidget.palette != widget.palette ||
        oldWidget.highlightColor != widget.highlightColor) {
      _layoutCache.clear();
      _lastLayoutOptions = null;
      _resetRenderData();
    }
    _syncBreathing();
  }

  void _resetRenderData() {
    _previousRenderData = null;
    _renderData = null;
    _renderSignature = null;
    _transitionController
      ..stop()
      ..value = 1;
  }

  @override
  void dispose() {
    _manualResetTimer?.cancel();
    widget.seekListenable?.removeListener(_handleSeek);
    _positionSubscription.close();
    _positionNotifier.dispose();
    _transitionController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handlePosition(Duration position) {
    if (!mounted) return;
    _positionNotifier.value = position;
    final next = _engine.resolvePosition(position);
    _preheatUpcoming(next);
    if (_hasSameStructurePosition(_structurePosition, next)) return;
    if (_manualAnchorIndex != null) {
      _structurePosition = next;
      return;
    }
    _beginStructureChange(() => _structurePosition = next);
  }

  void _preheatUpcoming(PartitaLyricPosition position) {
    final options = _lastLayoutOptions;
    final upcomingIndex = position.upcomingIndex;
    if (options == null || upcomingIndex == null) return;
    final upcoming = _engine.lineAt(upcomingIndex);
    if (upcoming == null) return;
    final lead = upcoming.start - position.timelinePosition;
    if (lead < _preheatMinimumLead || lead > _preheatMaximumLead) return;
    _engine.layoutLine(
      sourceLineIndex: upcomingIndex,
      options: options,
      cache: _layoutCache,
    );
  }

  void _handleSeek() {
    if (!mounted || _manualAnchorIndex == null) return;
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInputAccumulators();
    _beginStructureChange(() => _manualAnchorIndex = null);
  }

  bool _hasSameStructurePosition(
    PartitaLyricPosition first,
    PartitaLyricPosition second,
  ) {
    return first.activeIndex == second.activeIndex &&
        first.recentIndex == second.recentIndex &&
        first.upcomingIndex == second.upcomingIndex;
  }

  void _beginStructureChange(VoidCallback update, {bool animate = true}) {
    if (!mounted) return;
    setState(() {
      _previousRenderData = animate ? _renderData : null;
      _renderData = null;
      _renderSignature = null;
      update();
      final selectedIndex = _selectedSourceLineIndex;
      final selectedLine = selectedIndex == null
          ? null
          : _engine.lineAt(selectedIndex);
      _transitionController.duration = selectedLine == null
          ? _transitionDuration
          : resolvePartitaLineTransitionDuration(selectedLine);
      if (animate && _previousRenderData != null && _animationsAllowed) {
        _transitionController
          ..stop()
          ..value = 0;
      } else {
        _transitionController.value = 1;
      }
    });
    if (animate && _previousRenderData != null && _animationsAllowed) {
      _scheduleTransition();
    }
    _syncBreathing();
  }

  void _scheduleTransition() {
    if (_transitionScheduled) return;
    _transitionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transitionScheduled = false;
      if (!mounted || _renderData == null) return;
      _transitionController.forward();
    });
  }

  void _syncBreathing() {
    if (!mounted) return;
    final shouldRun =
        widget.breathingEnabled &&
        _animationsAllowed &&
        _manualAnchorIndex == null &&
        _structurePosition.activeIndex != null;
    if (shouldRun) {
      if (!_breathingController.isAnimating) {
        _breathingController.repeat();
      }
    } else {
      _breathingController
        ..stop()
        ..value = 0;
    }
  }

  int? get _selectedSourceLineIndex =>
      _manualAnchorIndex ?? _structurePosition.activeIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _resolveRailSize(context, constraints);
        if (size.isEmpty) return const SizedBox.shrink();
        final selectedLine = _selectedSourceLineIndex == null
            ? null
            : _engine.lineAt(_selectedSourceLineIndex!);
        final hasAuxiliary =
            selectedLine != null &&
            (selectedLine.translation.trim().isNotEmpty ||
                selectedLine.romanization.trim().isNotEmpty);
        final textScaleFactor = _resolveTextScaleFactor(context);
        final fontSpec = _resolveFontSpec(size, widget.fontPreset);
        final lyricTextStyle =
            Theme.of(context).textTheme.bodyLarge ??
            DefaultTextStyle.of(context).style;
        final reservedAuxiliaryHeight = hasAuxiliary
            ? math.min(
                fontSpec.auxiliary * 1.3 * textScaleFactor * 2 + 28,
                math.max(size.height - 1, 0),
              )
            : 0.0;
        final mainStageSize = Size(
          size.width,
          math.max(size.height - reservedAuxiliaryHeight, 1),
        );
        final options = PartitaLyricLayoutOptions(
          stageSize: mainStageSize,
          textStyle: lyricTextStyle.copyWith(
            fontSize: fontSpec.active,
            fontWeight: FontWeight.w700,
            height: 1.22,
            letterSpacing: 0,
          ),
          textDirection: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
          textScaleFactor: textScaleFactor,
          horizontalInset: fontSpec.horizontalInset,
          verticalInset: fontSpec.verticalInset,
          wordGap: fontSpec.wordGap,
          chunkMarginBottom: fontSpec.chunkMarginBottom,
          staggerMin: fontSpec.staggerMin,
          staggerMax: fontSpec.staggerMax,
          guideLength: fontSpec.guideLength,
          guideOverhang: fontSpec.guideOverhang,
        );
        _lastLayoutOptions = options;
        _preheatUpcoming(_structurePosition);
        final auxiliaryStyle = lyricTextStyle.copyWith(
          fontSize: fontSpec.auxiliary,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0,
        );
        final renderData = _resolveRenderData(
          size: size,
          options: options,
          auxiliaryStyle: auxiliaryStyle,
        );
        final selectedRenderIndex = _selectedSourceLineIndex;
        final selectedIsInterlude =
            selectedRenderIndex != null &&
            _engine.isInterludeAt(selectedRenderIndex);
        return RepaintBoundary(
          key: const ValueKey<String>('partita-lyric-repaint-boundary'),
          child: ClipRect(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onSeek == null || selectedIsInterlude
                    ? null
                    : _handleTapUp,
                onVerticalDragStart: _handleVerticalDragStart,
                onVerticalDragUpdate: _handleVerticalDragUpdate,
                onVerticalDragEnd: _handleVerticalDragEnd,
                onVerticalDragCancel: _handleVerticalDragCancel,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    CustomPaint(
                      key: const ValueKey<String>('partita-lyric-painter'),
                      painter: PartitaLyricPainter(
                        data: renderData,
                        previousData: _previousRenderData,
                        position: _positionNotifier,
                        transition: _transitionController,
                        breathing: _breathingController,
                        onPaint: widget.debugOnPaint,
                      ),
                    ),
                    if (renderData.layout != null && !selectedIsInterlude)
                      Positioned.fill(
                        child: Semantics(
                          container: true,
                          label: _semanticLabel(renderData),
                          button: widget.onSeek != null,
                          onTap: widget.onSeek == null
                              ? null
                              : _seekSelectedLine,
                          child: const SizedBox.expand(),
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

  Size _resolveRailSize(BuildContext context, BoxConstraints constraints) {
    final mediaSize = MediaQuery.sizeOf(context);
    return Size(
      (constraints.maxWidth.isFinite ? constraints.maxWidth : mediaSize.width)
          .clamp(0, double.infinity),
      (constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaSize.height)
          .clamp(0, double.infinity),
    );
  }

  double _resolveTextScaleFactor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return (scaler.scale(16) / 16).clamp(0.8, 1.6);
  }

  PartitaLyricRenderData _resolveRenderData({
    required Size size,
    required PartitaLyricLayoutOptions options,
    required TextStyle auxiliaryStyle,
  }) {
    final selectedIndex = _selectedSourceLineIndex;
    final palette = widget.highlightColor == null
        ? widget.palette
        : widget.palette.copyWith(accent: widget.highlightColor);
    final signature = Object.hashAll(<Object?>[
      _engine.documentSignature,
      widget.documentIdentity,
      selectedIndex,
      _manualAnchorIndex,
      options.stageSize,
      options.textStyle,
      auxiliaryStyle,
      options.textScaleFactor,
      options.textDirection,
      options.locale,
      widget.fontPreset,
      widget.enableWordByWordLyric,
      palette,
      size,
    ]);
    final cached = _renderData;
    if (cached != null && signature == _renderSignature) return cached;

    final layout = selectedIndex == null
        ? null
        : _engine.layoutLine(
            sourceLineIndex: selectedIndex,
            options: options,
            cache: _layoutCache,
          );
    final next = buildPartitaLyricRenderData(
      size: size,
      layout: layout,
      options: options,
      auxiliaryTextStyle: auxiliaryStyle,
      palette: palette,
      enableWordByWordLyric: widget.enableWordByWordLyric,
      forceLineActive: _manualAnchorIndex != null,
      timelineOffset: Duration(milliseconds: widget.document.offset),
      debugOnTextLayout: widget.debugOnTextLayout,
    );
    _renderData = next;
    _renderSignature = signature;
    widget.debugOnStructureBuild?.call();
    return next;
  }

  String _semanticLabel(PartitaLyricRenderData data) {
    final layout = data.layout;
    if (layout == null) return '';
    final auxiliary = layout.auxiliaryText;
    return auxiliary == null
        ? layout.sourceLine.text
        : '${layout.sourceLine.text}\n$auxiliary';
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _engine.lineCount == 0) return;
    final delta = event.scrollDelta.dy;
    final direction = delta == 0 ? 0 : (delta > 0 ? 1 : -1);
    _enterManualMode();
    if (direction != 0 &&
        _wheelDirection != 0 &&
        direction != _wheelDirection) {
      _wheelAccumulator = 0;
    }
    if (direction != 0) _wheelDirection = direction;
    _wheelAccumulator += delta;
    final steps = (_wheelAccumulator / _wheelStep).truncate().clamp(-1, 1);
    if (steps != 0) {
      _wheelAccumulator = 0;
      _moveManualAnchor(steps);
    } else {
      _restartManualResetTimer();
    }
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_engine.lineCount == 0) return;
    _dragAccumulator = 0;
    _dragDirection = 0;
    _dragMoved = false;
    _enterManualMode();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_engine.lineCount == 0) return;
    final delta = -details.delta.dy;
    final direction = delta == 0 ? 0 : (delta > 0 ? 1 : -1);
    if (direction != 0 && _dragDirection != 0 && direction != _dragDirection) {
      _dragAccumulator = 0;
    }
    if (direction != 0) _dragDirection = direction;
    _dragAccumulator += delta;
    if (delta.abs() >= 1) _dragMoved = true;
    final steps = (_dragAccumulator / _dragStep).truncate().clamp(-1, 1);
    if (steps != 0) {
      _dragAccumulator = 0;
      _moveManualAnchor(steps);
    } else {
      _restartManualResetTimer();
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    _dragAccumulator = 0;
    _dragDirection = 0;
    _restartManualResetTimer();
  }

  void _handleVerticalDragCancel() {
    _dragAccumulator = 0;
    _dragDirection = 0;
    _restartManualResetTimer();
  }

  void _enterManualMode() {
    if (_manualAnchorIndex == null) {
      _beginStructureChange(
        () => _manualAnchorIndex = _automaticAnchorIndex(),
        animate: false,
      );
    }
    _restartManualResetTimer();
  }

  int _automaticAnchorIndex() {
    return (_structurePosition.activeIndex ??
            _structurePosition.upcomingIndex ??
            _structurePosition.recentIndex ??
            0)
        .clamp(0, _engine.lineCount - 1);
  }

  void _moveManualAnchor(int steps) {
    if (_engine.lineCount == 0) return;
    final current = _manualAnchorIndex ?? _automaticAnchorIndex();
    final next = (current + steps).clamp(0, _engine.lineCount - 1);
    if (next != current) {
      _beginStructureChange(() => _manualAnchorIndex = next);
    }
    _restartManualResetTimer();
  }

  void _restartManualResetTimer() {
    _manualResetTimer?.cancel();
    if (_manualAnchorIndex == null) return;
    _manualResetTimer = Timer(_manualResetDelay, () {
      if (!mounted || _manualAnchorIndex == null) return;
      _manualResetTimer = null;
      _resetInputAccumulators();
      _beginStructureChange(() => _manualAnchorIndex = null);
    });
  }

  void _resetInputAccumulators() {
    _wheelAccumulator = 0;
    _wheelDirection = 0;
    _dragAccumulator = 0;
    _dragDirection = 0;
    _dragMoved = false;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_dragMoved) {
      _dragMoved = false;
      return;
    }
    final data = _renderData;
    if (data == null) return;
    for (final chunk in data.chunks.reversed) {
      if (chunk.layout.hitRect.contains(details.localPosition)) {
        _seekSelectedLine();
        return;
      }
    }
  }

  void _seekSelectedLine() {
    final onSeek = widget.onSeek;
    final layout = _renderData?.layout;
    if (onSeek == null || layout == null) return;
    final selectedIndex = _selectedSourceLineIndex;
    if (selectedIndex == null || _engine.isInterludeAt(selectedIndex)) return;
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInputAccumulators();
    if (_manualAnchorIndex != null) {
      _beginStructureChange(() => _manualAnchorIndex = null);
    }
    final requested =
        layout.sourceLine.start -
        Duration(milliseconds: widget.document.offset);
    onSeek(requested.isNegative ? Duration.zero : requested);
  }
}

@immutable
class _PartitaRailFontSpec {
  const _PartitaRailFontSpec({
    required this.active,
    required this.auxiliary,
    required this.horizontalInset,
    required this.verticalInset,
    required this.wordGap,
    required this.chunkMarginBottom,
    required this.staggerMin,
    required this.staggerMax,
    required this.guideLength,
    required this.guideOverhang,
  });

  final double active;
  final double auxiliary;
  final double horizontalInset;
  final double verticalInset;
  final double wordGap;
  final double chunkMarginBottom;
  final double staggerMin;
  final double staggerMax;
  final double guideLength;
  final double guideOverhang;
}

_PartitaRailFontSpec _resolveFontSpec(Size size, AppLyricFontPreset preset) {
  final compact = size.width < 340 || size.height < 280;
  final wide = size.width >= 620 && size.height >= 400;
  final active = switch ((preset, compact, wide)) {
    (AppLyricFontPreset.small, true, _) => 30.0,
    (AppLyricFontPreset.small, false, true) => 44.0,
    (AppLyricFontPreset.small, false, false) => 36.0,
    (AppLyricFontPreset.medium, true, _) => 34.0,
    (AppLyricFontPreset.medium, false, true) => 50.0,
    (AppLyricFontPreset.medium, false, false) => 42.0,
    (AppLyricFontPreset.large, true, _) => 38.0,
    (AppLyricFontPreset.large, false, true) => 58.0,
    (AppLyricFontPreset.large, false, false) => 48.0,
  };
  final auxiliary = switch (preset) {
    AppLyricFontPreset.small => compact ? 11.0 : (wide ? 14.0 : 12.0),
    AppLyricFontPreset.medium => compact ? 12.0 : (wide ? 16.0 : 14.0),
    AppLyricFontPreset.large => compact ? 13.0 : (wide ? 18.0 : 16.0),
  };
  return _PartitaRailFontSpec(
    active: active,
    auxiliary: auxiliary,
    horizontalInset: compact ? 20 : (wide ? 38 : 28),
    verticalInset: compact ? 16 : 28,
    wordGap: compact ? 7 : 12,
    chunkMarginBottom: compact ? 7 : 10,
    staggerMin: compact ? 14 : 20,
    staggerMax: compact ? 52 : (wide ? 100 : 72),
    guideLength: compact ? 24 : 32,
    guideOverhang: compact ? 12 : 18,
  );
}
