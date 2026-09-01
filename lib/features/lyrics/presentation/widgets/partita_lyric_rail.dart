import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/monet_lyric_layout.dart';
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
    this.documentIdentity,
    this.breathingEnabled = true,
    this.seekListenable,
    this.debugOnStructureBuild,
    this.debugOnPaint,
    super.key,
  });

  final LyricDocument document;
  final AppLyricFontPreset fontPreset;
  final bool enableWordByWordLyric;
  final PlayerScenePalette palette;
  final ValueChanged<Duration>? onSeek;
  final String? documentIdentity;
  final bool breathingEnabled;
  final Listenable? seekListenable;

  @visibleForTesting
  final VoidCallback? debugOnStructureBuild;
  @visibleForTesting
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<PartitaLyricRail> createState() => _PartitaLyricRailState();
}

class _PartitaLyricRailState extends ConsumerState<PartitaLyricRail>
    with TickerProviderStateMixin {
  static const _manualResetDelay = Duration(milliseconds: 1800);
  static const _transitionDuration = Duration(milliseconds: 380);
  static const _breathingDuration = Duration(milliseconds: 3400);
  static const _wheelStep = 64.0;
  static const _dragStep = 48.0;

  late PartitaLyricLayoutEngine _engine;
  late MonetLyricPosition _structurePosition;
  late final ValueNotifier<Duration> _positionNotifier;
  late final AnimationController _transitionController;
  late final AnimationController _breathingController;
  late final ProviderSubscription<Duration> _positionSubscription;
  final PartitaLyricMeasurementCache _measurementCache =
      PartitaLyricMeasurementCache();

  Timer? _manualResetTimer;
  PartitaLyricRenderData? _renderData;
  PartitaLyricRenderData? _previousRenderData;
  String? _renderSignature;
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
      _measurementCache.clear();
      _engine = nextEngine;
      _structurePosition = _engine.resolvePosition(_positionNotifier.value);
      _previousRenderData = null;
      _renderData = null;
      _renderSignature = null;
      _transitionController
        ..stop()
        ..value = 1;
    } else if (oldWidget.fontPreset != widget.fontPreset ||
        oldWidget.enableWordByWordLyric != widget.enableWordByWordLyric ||
        oldWidget.palette != widget.palette) {
      _measurementCache.clear();
      _previousRenderData = null;
      _renderData = null;
      _renderSignature = null;
      _transitionController
        ..stop()
        ..value = 1;
    }
    _syncBreathing();
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
    if (_hasSameStructurePosition(_structurePosition, next)) return;
    _beginStructureChange(() => _structurePosition = next);
  }

  void _handleSeek() {
    if (!mounted || _manualAnchorIndex == null) return;
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInputAccumulators();
    _beginStructureChange(() => _manualAnchorIndex = null);
  }

  bool _hasSameStructurePosition(
    MonetLyricPosition first,
    MonetLyricPosition second,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _resolveRailSize(context, constraints);
        if (size.isEmpty) return const SizedBox.shrink();
        final textScaleFactor = _resolveTextScaleFactor(context);
        final fontSpec = _resolveFontSpec(size, widget.fontPreset);
        final lyricTextStyle =
            Theme.of(context).textTheme.bodyLarge ??
            DefaultTextStyle.of(context).style;
        final options = PartitaLyricLayoutOptions(
          railSize: size,
          activeTextStyle: lyricTextStyle.copyWith(
            fontSize: fontSpec.active,
            fontWeight: FontWeight.w700,
            height: 1.14,
            letterSpacing: 0,
          ),
          inactiveTextStyle: lyricTextStyle.copyWith(
            fontSize: fontSpec.inactive,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
          auxiliaryTextStyle: lyricTextStyle.copyWith(
            fontSize: fontSpec.auxiliary,
            fontWeight: FontWeight.w500,
            height: 1.28,
            letterSpacing: 0,
          ),
          textDirection: Directionality.of(context),
          textScaleFactor: textScaleFactor,
          horizontalPadding: fontSpec.horizontalPadding,
          verticalPadding: fontSpec.verticalPadding,
          auxiliaryGap: fontSpec.auxiliaryGap,
          activeGap: fontSpec.activeGap,
          inactiveGap: fontSpec.inactiveGap,
          guideReserve: fontSpec.guideReserve,
          inactiveMaxLines: fontSpec.inactiveMaxLines,
        );
        final renderData = _resolveRenderData(options);
        return RepaintBoundary(
          key: const ValueKey<String>('partita-lyric-repaint-boundary'),
          child: ClipRect(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onSeek == null ? null : _handleTapUp,
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
                    for (final line in renderData.lines)
                      if (!line.positioned.hitRect.isEmpty)
                        Positioned.fromRect(
                          rect: line.positioned.hitRect,
                          child: Semantics(
                            label: _semanticLabel(line),
                            button: widget.onSeek != null,
                            onTap: widget.onSeek == null
                                ? null
                                : () => _seekLine(line),
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

  PartitaLyricRenderData _resolveRenderData(PartitaLyricLayoutOptions options) {
    final signature = <Object?>[
      _engine.documentSignature,
      widget.documentIdentity,
      _structurePosition.activeIndex,
      _structurePosition.recentIndex,
      _structurePosition.upcomingIndex,
      _manualAnchorIndex,
      options.railSize,
      options.activeTextStyle.fontSize,
      options.inactiveTextStyle.fontSize,
      options.auxiliaryTextStyle.fontSize,
      options.textScaleFactor,
      options.textDirection,
      widget.fontPreset,
      widget.enableWordByWordLyric,
      widget.palette,
    ].join('|');
    final cached = _renderData;
    if (cached != null && signature == _renderSignature) return cached;

    final entries = _engine.buildVisibleWindow(
      position: _structurePosition,
      before: 4,
      after: 4,
      manualAnchorIndex: _manualAnchorIndex,
    );
    final positioned = layoutPartitaLyricWindow(
      engine: _engine,
      entries: entries,
      options: options,
      cache: _measurementCache,
    );
    final next = buildPartitaLyricRenderData(
      positionedLines: positioned,
      options: options,
      palette: widget.palette,
      enableWordByWordLyric: widget.enableWordByWordLyric,
      timelineOffset: Duration(milliseconds: widget.document.offset),
    );
    _renderData = next;
    _renderSignature = signature;
    widget.debugOnStructureBuild?.call();
    return next;
  }

  String _semanticLabel(PartitaLyricPaintLine line) {
    final auxiliary = line.positioned.measurement.auxiliaryText;
    return auxiliary == null
        ? line.positioned.entry.line.text
        : '${line.positioned.entry.line.text}\n$auxiliary';
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
      _beginStructureChange(() {
        _manualAnchorIndex = _automaticAnchorIndex();
      }, animate: false);
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
    for (final line in data.lines.reversed) {
      if (!line.positioned.hitRect.isEmpty &&
          line.positioned.hitRect.contains(details.localPosition)) {
        _seekLine(line);
        return;
      }
    }
  }

  void _seekLine(PartitaLyricPaintLine line) {
    final onSeek = widget.onSeek;
    if (onSeek == null ||
        line.positioned.hitRect.isEmpty ||
        line.positioned.entry.isInterlude) {
      return;
    }
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInputAccumulators();
    if (_manualAnchorIndex != null) {
      _beginStructureChange(() => _manualAnchorIndex = null);
    }
    final requested =
        line.positioned.entry.line.start -
        Duration(milliseconds: widget.document.offset);
    onSeek(requested.isNegative ? Duration.zero : requested);
  }
}

@immutable
class _PartitaRailFontSpec {
  const _PartitaRailFontSpec({
    required this.active,
    required this.inactive,
    required this.auxiliary,
    required this.inactiveMaxLines,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.auxiliaryGap,
    required this.activeGap,
    required this.inactiveGap,
    required this.guideReserve,
  });

  final double active;
  final double inactive;
  final double auxiliary;
  final int inactiveMaxLines;
  final double horizontalPadding;
  final double verticalPadding;
  final double auxiliaryGap;
  final double activeGap;
  final double inactiveGap;
  final double guideReserve;
}

_PartitaRailFontSpec _resolveFontSpec(Size size, AppLyricFontPreset preset) {
  final compact = size.width < 340 || size.height < 280;
  final wide = size.width >= 720 && size.height >= 400;
  final active = switch ((preset, compact, wide)) {
    (AppLyricFontPreset.small, true, _) => 23.0,
    (AppLyricFontPreset.small, false, true) => 34.0,
    (AppLyricFontPreset.small, false, false) => 29.0,
    (AppLyricFontPreset.medium, true, _) => 27.0,
    (AppLyricFontPreset.medium, false, true) => 40.0,
    (AppLyricFontPreset.medium, false, false) => 34.0,
    (AppLyricFontPreset.large, true, _) => 31.0,
    (AppLyricFontPreset.large, false, true) => 46.0,
    (AppLyricFontPreset.large, false, false) => 40.0,
  };
  final inactive = switch (preset) {
    AppLyricFontPreset.small => compact ? 17.0 : (wide ? 25.0 : 20.0),
    AppLyricFontPreset.medium => compact ? 20.0 : (wide ? 29.0 : 23.0),
    AppLyricFontPreset.large => compact ? 22.0 : (wide ? 33.0 : 27.0),
  };
  final auxiliary = switch (preset) {
    AppLyricFontPreset.small => compact ? 11.0 : (wide ? 14.0 : 12.0),
    AppLyricFontPreset.medium => compact ? 12.0 : (wide ? 16.0 : 14.0),
    AppLyricFontPreset.large => compact ? 13.0 : (wide ? 18.0 : 16.0),
  };
  return _PartitaRailFontSpec(
    active: active,
    inactive: inactive,
    auxiliary: auxiliary,
    inactiveMaxLines: compact ? 1 : 2,
    horizontalPadding: compact ? 8 : 14,
    verticalPadding: compact ? 5 : 8,
    auxiliaryGap: compact ? 4 : 6,
    activeGap: compact ? 11 : 18,
    inactiveGap: compact ? 8 : 12,
    guideReserve: compact ? 22 : 30,
  );
}
