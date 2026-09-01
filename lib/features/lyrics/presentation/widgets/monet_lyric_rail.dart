import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../domain/entities/lyric_document.dart';
import '../helpers/monet_lyric_layout.dart';
import '../providers/lyrics_providers.dart';
import 'monet_lyric_painter.dart';

class MonetLyricRail extends ConsumerStatefulWidget {
  const MonetLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    required this.onSeek,
    this.debugOnStructureBuild,
    this.debugOnPaint,
    super.key,
  });

  final LyricDocument document;
  final AppLyricFontPreset fontPreset;
  final bool enableWordByWordLyric;
  final PlayerScenePalette palette;
  final ValueChanged<Duration>? onSeek;

  @visibleForTesting
  final VoidCallback? debugOnStructureBuild;

  @visibleForTesting
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<MonetLyricRail> createState() => _MonetLyricRailState();
}

class _MonetLyricRailState extends ConsumerState<MonetLyricRail>
    with SingleTickerProviderStateMixin {
  static const _manualResetDelay = Duration(milliseconds: 1800);
  static const _wheelStep = 64.0;
  static const _dragStep = 48.0;
  static const _transitionDuration = Duration(milliseconds: 360);

  late MonetLyricLayoutEngine _engine;
  late MonetLyricPosition _structurePosition;
  late final ValueNotifier<Duration> _positionNotifier;
  late final AnimationController _transitionController;
  late final ProviderSubscription<Duration> _positionSubscription;
  final MonetLyricMeasurementCache _measurementCache =
      MonetLyricMeasurementCache();

  Timer? _manualResetTimer;
  MonetLyricRenderData? _renderData;
  MonetLyricRenderData? _previousRenderData;
  String? _renderSignature;
  int? _manualAnchorIndex;
  double _wheelAccumulator = 0;
  int _wheelDirection = 0;
  double _dragAccumulator = 0;
  int _dragDirection = 0;
  bool _dragMoved = false;
  bool _transitionScheduled = false;

  @override
  void initState() {
    super.initState();
    _engine = MonetLyricLayoutEngine(widget.document);
    final initialPosition = ref.read(lyricPositionProvider);
    _positionNotifier = ValueNotifier<Duration>(initialPosition);
    _structurePosition = _engine.resolvePosition(initialPosition);
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    );
    _positionSubscription = ref.listenManual<Duration>(
      lyricPositionProvider,
      (previous, next) => _handlePosition(next),
      fireImmediately: false,
    );
  }

  @override
  void didUpdateWidget(covariant MonetLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextEngine = MonetLyricLayoutEngine(widget.document);
    if (nextEngine.documentSignature != _engine.documentSignature) {
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
      return;
    }
    if (oldWidget.fontPreset != widget.fontPreset ||
        oldWidget.enableWordByWordLyric != widget.enableWordByWordLyric ||
        oldWidget.palette != widget.palette) {
      _previousRenderData = null;
      _renderData = null;
      _renderSignature = null;
      _transitionController
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _manualResetTimer?.cancel();
    _positionSubscription.close();
    _positionNotifier.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _handlePosition(Duration position) {
    if (!mounted) {
      return;
    }
    _positionNotifier.value = position;
    final next = _engine.resolvePosition(position);
    if (_hasSameStructurePosition(_structurePosition, next)) {
      return;
    }
    _beginStructureChange(() {
      _structurePosition = next;
    });
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
    if (!mounted) {
      return;
    }
    setState(() {
      _previousRenderData = animate ? _renderData : null;
      _renderData = null;
      _renderSignature = null;
      update();
      if (animate && _previousRenderData != null) {
        _transitionController
          ..stop()
          ..value = 0;
      } else {
        _transitionController.value = 1;
      }
    });
    if (animate && _previousRenderData != null) {
      _scheduleTransition();
    }
  }

  void _scheduleTransition() {
    if (_transitionScheduled) {
      return;
    }
    _transitionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transitionScheduled = false;
      if (!mounted || _renderData == null) {
        return;
      }
      _transitionController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _resolveRailSize(context, constraints);
        if (size.isEmpty) {
          return const SizedBox.shrink();
        }
        final textDirection = Directionality.of(context);
        final textScaleFactor = _resolveTextScaleFactor(context);
        final fontSpec = _resolveFontSpec(size, widget.fontPreset);
        final options = MonetLyricLayoutOptions(
          railSize: size,
          activeTextStyle: TextStyle(
            fontSize: fontSpec.active,
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: 0,
          ),
          inactiveTextStyle: TextStyle(
            fontSize: fontSpec.inactive,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
          translationTextStyle: TextStyle(
            fontSize: fontSpec.translation,
            fontWeight: FontWeight.w500,
            height: 1.3,
            letterSpacing: 0,
          ),
          textDirection: textDirection,
          textAlign: TextAlign.left,
          textScaleFactor: textScaleFactor,
          inactiveMaxLines: fontSpec.inactiveMaxLines,
          horizontalPadding: fontSpec.horizontalPadding,
          verticalPadding: fontSpec.verticalPadding,
          translationGap: fontSpec.translationGap,
          activeGap: fontSpec.activeGap,
          inactiveGap: fontSpec.inactiveGap,
        );
        final renderData = _resolveRenderData(options);
        return RepaintBoundary(
          key: const ValueKey<String>('monet-lyric-repaint-boundary'),
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
                      key: const ValueKey<String>('monet-lyric-painter'),
                      painter: MonetLyricPainter(
                        data: renderData,
                        previousData: _previousRenderData,
                        position: _positionNotifier,
                        transition: _transitionController,
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
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : mediaSize.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : mediaSize.height;
    return Size(
      width.clamp(0.0, double.infinity),
      height.clamp(0.0, double.infinity),
    );
  }

  double _resolveTextScaleFactor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return (scaler.scale(16) / 16).clamp(0.8, 1.6);
  }

  MonetLyricRenderData _resolveRenderData(MonetLyricLayoutOptions options) {
    final signature = <Object?>[
      _engine.documentSignature,
      _structurePosition.activeIndex,
      _structurePosition.recentIndex,
      _structurePosition.upcomingIndex,
      _manualAnchorIndex,
      options.railSize.width,
      options.railSize.height,
      options.activeTextStyle.fontSize,
      options.inactiveTextStyle.fontSize,
      options.translationTextStyle.fontSize,
      options.textScaleFactor,
      options.textDirection,
      widget.fontPreset,
      widget.enableWordByWordLyric,
      widget.palette,
    ].join('|');
    final cached = _renderData;
    if (cached != null && signature == _renderSignature) {
      return cached;
    }

    final entries = _engine.buildVisibleWindow(
      position: _structurePosition,
      before: 4,
      after: 4,
      manualAnchorIndex: _manualAnchorIndex,
    );
    final positioned = layoutMonetLyricWindow(
      engine: _engine,
      entries: entries,
      options: options,
      cache: _measurementCache,
    );
    final next = buildMonetLyricRenderData(
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

  String _semanticLabel(MonetLyricPaintLine line) {
    final translation = line.positioned.measurement.translationText;
    return translation == null
        ? line.positioned.entry.line.text
        : '${line.positioned.entry.line.text}\n$translation';
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || widget.document.lines.isEmpty) {
      return;
    }
    final delta = event.scrollDelta.dy;
    final direction = delta == 0 ? 0 : (delta > 0 ? 1 : -1);
    _enterManualMode();
    if (direction != 0 &&
        _wheelDirection != 0 &&
        direction != _wheelDirection) {
      _wheelAccumulator = 0;
    }
    if (direction != 0) {
      _wheelDirection = direction;
    }
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
    if (widget.document.lines.isEmpty) {
      return;
    }
    _dragAccumulator = 0;
    _dragDirection = 0;
    _dragMoved = false;
    _enterManualMode();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.document.lines.isEmpty) {
      return;
    }
    final delta = -details.delta.dy;
    final direction = delta == 0 ? 0 : (delta > 0 ? 1 : -1);
    if (direction != 0 && _dragDirection != 0 && direction != _dragDirection) {
      _dragAccumulator = 0;
    }
    if (direction != 0) {
      _dragDirection = direction;
    }
    _dragAccumulator += delta;
    if (delta.abs() >= 1) {
      _dragMoved = true;
    }
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
      final anchor = _automaticAnchorIndex();
      _beginStructureChange(() {
        _manualAnchorIndex = anchor;
      }, animate: false);
    }
    _restartManualResetTimer();
  }

  int _automaticAnchorIndex() {
    return (_structurePosition.activeIndex ??
            _structurePosition.upcomingIndex ??
            _structurePosition.recentIndex ??
            0)
        .clamp(0, widget.document.lines.length - 1);
  }

  void _moveManualAnchor(int steps) {
    if (widget.document.lines.isEmpty) {
      return;
    }
    final current = _manualAnchorIndex ?? _automaticAnchorIndex();
    final next = (current + steps).clamp(0, widget.document.lines.length - 1);
    if (next != current) {
      _beginStructureChange(() {
        _manualAnchorIndex = next;
      });
    }
    _restartManualResetTimer();
  }

  void _restartManualResetTimer() {
    _manualResetTimer?.cancel();
    if (_manualAnchorIndex == null) {
      return;
    }
    _manualResetTimer = Timer(_manualResetDelay, () {
      if (!mounted || _manualAnchorIndex == null) {
        return;
      }
      _manualResetTimer = null;
      _resetInputAccumulators();
      _beginStructureChange(() {
        _manualAnchorIndex = null;
      });
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
    if (data == null) {
      return;
    }
    for (final line in data.lines.reversed) {
      final hitRect = line.positioned.hitRect;
      if (!hitRect.isEmpty && hitRect.contains(details.localPosition)) {
        _seekLine(line);
        return;
      }
    }
  }

  void _seekLine(MonetLyricPaintLine line) {
    final onSeek = widget.onSeek;
    if (onSeek == null || line.positioned.hitRect.isEmpty) {
      return;
    }
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInputAccumulators();
    if (_manualAnchorIndex != null) {
      _beginStructureChange(() {
        _manualAnchorIndex = null;
      });
    }
    final requested =
        line.positioned.entry.line.start -
        Duration(milliseconds: widget.document.offset);
    onSeek(requested.isNegative ? Duration.zero : requested);
  }
}

@immutable
class _MonetRailFontSpec {
  const _MonetRailFontSpec({
    required this.active,
    required this.inactive,
    required this.translation,
    required this.inactiveMaxLines,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.translationGap,
    required this.activeGap,
    required this.inactiveGap,
  });

  final double active;
  final double inactive;
  final double translation;
  final int inactiveMaxLines;
  final double horizontalPadding;
  final double verticalPadding;
  final double translationGap;
  final double activeGap;
  final double inactiveGap;
}

_MonetRailFontSpec _resolveFontSpec(Size size, AppLyricFontPreset preset) {
  final isCompact = size.width < 340 || size.height < 280;
  final isWide = size.width >= 720 && size.height >= 400;
  final active = switch ((preset, isCompact, isWide)) {
    (AppLyricFontPreset.small, true, _) => 24.0,
    (AppLyricFontPreset.small, false, true) => 36.0,
    (AppLyricFontPreset.small, false, false) => 30.0,
    (AppLyricFontPreset.medium, true, _) => 28.0,
    (AppLyricFontPreset.medium, false, true) => 42.0,
    (AppLyricFontPreset.medium, false, false) => 36.0,
    (AppLyricFontPreset.large, true, _) => 32.0,
    (AppLyricFontPreset.large, false, true) => 50.0,
    (AppLyricFontPreset.large, false, false) => 42.0,
  };
  final inactive = switch (preset) {
    AppLyricFontPreset.small => isCompact ? 15.0 : (isWide ? 21.0 : 18.0),
    AppLyricFontPreset.medium => isCompact ? 17.0 : (isWide ? 24.0 : 20.0),
    AppLyricFontPreset.large => isCompact ? 19.0 : (isWide ? 27.0 : 22.0),
  };
  final translation = switch (preset) {
    AppLyricFontPreset.small => isCompact ? 11.0 : (isWide ? 15.0 : 13.0),
    AppLyricFontPreset.medium => isCompact ? 12.0 : (isWide ? 17.0 : 15.0),
    AppLyricFontPreset.large => isCompact ? 13.0 : (isWide ? 19.0 : 17.0),
  };
  return _MonetRailFontSpec(
    active: active,
    inactive: inactive,
    translation: translation,
    inactiveMaxLines: isCompact ? 1 : 2,
    horizontalPadding: isCompact ? 12 : 20,
    verticalPadding: isCompact ? 6 : 10,
    translationGap: isCompact ? 4 : 7,
    activeGap: isCompact ? 12 : 20,
    inactiveGap: isCompact ? 8 : 14,
  );
}
