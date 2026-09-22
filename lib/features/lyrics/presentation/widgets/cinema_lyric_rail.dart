import 'dart:async';

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
import 'cinema_lyric_painter.dart';

class CinemaLyricRail extends ConsumerStatefulWidget {
  const CinemaLyricRail({
    required this.document,
    required this.fontPreset,
    required this.enableWordByWordLyric,
    required this.palette,
    required this.onSeek,
    this.highlightColor,
    this.documentIdentity,
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
  final Color? highlightColor;
  final String? documentIdentity;
  final Listenable? seekListenable;

  @visibleForTesting
  final VoidCallback? debugOnStructureBuild;
  @visibleForTesting
  final VoidCallback? debugOnPaint;

  @override
  ConsumerState<CinemaLyricRail> createState() => _CinemaLyricRailState();
}

class _CinemaLyricRailState extends ConsumerState<CinemaLyricRail>
    with TickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 280);
  static const _manualResetDelay = Duration(milliseconds: 1800);
  static const _wheelStep = 64.0;
  static const _dragStep = 48.0;

  final _painterOwner = LyricPainterOwner();
  late MonetLyricLayoutEngine _engine;
  late MonetLyricPosition _structurePosition;
  late final LyricPositionSmoother _positionNotifier;
  late final ProviderSubscription<Duration> _positionSubscription;
  late final ProviderSubscription<bool> _playbackSubscription;
  late final AnimationController _transitionController;

  CinemaLyricRenderData? _renderData;
  CinemaLyricRenderData? _previousRenderData;
  int? _renderSignature;
  int? _manualAnchorIndex;
  Timer? _manualResetTimer;
  double _wheelAccumulator = 0;
  double _dragAccumulator = 0;
  bool _dragMoved = false;
  bool _transitionScheduled = false;
  bool _playbackActive = false;
  bool _animationsAllowed = true;

  @override
  void initState() {
    super.initState();
    _engine = MonetLyricLayoutEngine(widget.document);
    final initialPosition = ref.read(lyricPositionProvider);
    _structurePosition = _engine.resolvePosition(initialPosition);
    _positionNotifier = LyricPositionSmoother(
      vsync: this,
      position: initialPosition,
    );
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    )..addStatusListener(_handleTransitionStatus);
    _playbackSubscription = ref.listenManual<bool>(
      lyricPlaybackActiveProvider,
      (previous, next) {
        _playbackActive = next;
        _positionNotifier.enabled = next && _animationsAllowed;
      },
      fireImmediately: true,
    );
    _positionSubscription = ref.listenManual<Duration>(
      lyricPositionProvider,
      (previous, next) => _handlePosition(next),
    );
    widget.seekListenable?.addListener(_handleSeek);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsAllowed =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _positionNotifier.enabled = _playbackActive && _animationsAllowed;
  }

  @override
  void didUpdateWidget(covariant CinemaLyricRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seekListenable != widget.seekListenable) {
      oldWidget.seekListenable?.removeListener(_handleSeek);
      widget.seekListenable?.addListener(_handleSeek);
    }
    final nextEngine = identical(oldWidget.document, widget.document)
        ? _engine
        : MonetLyricLayoutEngine(widget.document);
    if (oldWidget.documentIdentity != widget.documentIdentity ||
        nextEngine.documentSignature != _engine.documentSignature) {
      _engine = nextEngine;
      _positionNotifier.snap(ref.read(lyricPositionProvider));
      _structurePosition = _engine.resolvePosition(_positionNotifier.value);
      _manualResetTimer?.cancel();
      _manualAnchorIndex = null;
      _resetInput();
      _resetRenderData();
      return;
    }
    if (oldWidget.fontPreset != widget.fontPreset ||
        oldWidget.enableWordByWordLyric != widget.enableWordByWordLyric ||
        oldWidget.palette != widget.palette ||
        oldWidget.highlightColor != widget.highlightColor) {
      _resetRenderData();
    }
  }

  @override
  void dispose() {
    _manualResetTimer?.cancel();
    widget.seekListenable?.removeListener(_handleSeek);
    _positionSubscription.close();
    _playbackSubscription.close();
    _positionNotifier.dispose();
    _transitionController.dispose();
    _painterOwner.dispose();
    super.dispose();
  }

  void _resetRenderData() {
    _previousRenderData = null;
    _renderData = null;
    _renderSignature = null;
    _transitionController
      ..stop()
      ..value = 1;
  }

  void _handlePosition(Duration position) {
    if (!mounted) return;
    final next = _engine.resolvePosition(position);
    final structureChanged = !_samePosition(_structurePosition, next);
    _positionNotifier.update(position, discontinuity: structureChanged);
    if (!structureChanged) return;
    if (_manualAnchorIndex != null) {
      _structurePosition = next;
      return;
    }
    _beginStructureChange(() => _structurePosition = next);
  }

  bool _samePosition(MonetLyricPosition first, MonetLyricPosition second) {
    return first.activeIndex == second.activeIndex &&
        first.recentIndex == second.recentIndex &&
        first.upcomingIndex == second.upcomingIndex;
  }

  void _beginStructureChange(VoidCallback update, {bool animate = true}) {
    if (!mounted) return;
    final shouldAnimate = animate && _animationsAllowed;
    setState(() {
      _previousRenderData = shouldAnimate ? _renderData : null;
      _renderData = null;
      _renderSignature = null;
      update();
      _transitionController
        ..stop()
        ..value = shouldAnimate && _previousRenderData != null ? 0 : 1;
    });
    if (shouldAnimate && _previousRenderData != null) {
      _scheduleTransition();
    }
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

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _previousRenderData == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_transitionController.isCompleted) return;
      setState(() => _previousRenderData = null);
    });
  }

  void _handleSeek() {
    _positionNotifier.seek();
    _resetManualBrowse(animate: false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final size = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : mediaSize.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaSize.height,
        );
        if (size.isEmpty) return const SizedBox.shrink();
        final compact = size.width < 340 || size.height < 300;
        final fontSpec = _resolveFontSpec(
          widget.fontPreset,
          compact,
          size.width,
        );
        final baseTextStyle = Theme.of(context).textTheme.bodyLarge;
        final options = CinemaLyricLayoutOptions(
          size: size,
          activeStyle: TextStyle(
            fontFamily: baseTextStyle?.fontFamily,
            fontFamilyFallback: baseTextStyle?.fontFamilyFallback,
            fontSize: fontSpec.active,
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: 0,
          ),
          inactiveStyle: TextStyle(
            fontFamily: baseTextStyle?.fontFamily,
            fontFamilyFallback: baseTextStyle?.fontFamilyFallback,
            fontSize: fontSpec.inactive,
            fontWeight: FontWeight.w500,
            height: 1.22,
            letterSpacing: 0,
          ),
          translationStyle: TextStyle(
            fontFamily: baseTextStyle?.fontFamily,
            fontFamilyFallback: baseTextStyle?.fontFamilyFallback,
            fontSize: fontSpec.translation,
            fontWeight: FontWeight.w500,
            height: 1.25,
            letterSpacing: 0,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.5),
          locale: Localizations.maybeLocaleOf(context),
          horizontalPadding: compact ? 16 : 28,
          lineGap: compact ? 30 : 48,
        );
        final data = _resolveRenderData(options);
        return RepaintBoundary(
          key: const ValueKey<String>('cinema-lyric-repaint-boundary'),
          child: ClipRect(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onSeek == null ? null : _handleTapUp,
                onVerticalDragStart: _handleDragStart,
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: (_) => _restartManualResetTimer(),
                onVerticalDragCancel: _restartManualResetTimer,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      key: const ValueKey<String>('cinema-lyric-painter'),
                      painter: CinemaLyricPainter(
                        data: data,
                        previousData: _previousRenderData,
                        position: _positionNotifier,
                        transition: _transitionController,
                        onPaint: widget.debugOnPaint,
                      ),
                    ),
                    for (final line in data.lines)
                      if (!line.hitRect.isEmpty)
                        Positioned.fromRect(
                          rect: line.hitRect,
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

  CinemaLyricRenderData _resolveRenderData(CinemaLyricLayoutOptions options) {
    final palette = widget.highlightColor == null
        ? widget.palette
        : widget.palette.copyWith(accent: widget.highlightColor);
    final signature = Object.hashAll(<Object?>[
      _engine.documentSignature,
      widget.documentIdentity,
      _structurePosition.activeIndex,
      _structurePosition.recentIndex,
      _structurePosition.upcomingIndex,
      _manualAnchorIndex,
      options.size,
      options.activeStyle,
      options.inactiveStyle,
      options.translationStyle,
      options.textDirection,
      options.textScaler,
      options.locale,
      widget.enableWordByWordLyric,
      palette,
    ]);
    final cached = _renderData;
    if (cached != null && signature == _renderSignature) {
      _painterOwner.retain(<LyricPaintResources?>[cached, _previousRenderData]);
      return cached;
    }
    final entries = _engine.buildVisibleWindow(
      position: _structurePosition,
      before: 1,
      after: 1,
      manualAnchorIndex: _manualAnchorIndex,
    );
    final next = buildCinemaLyricRenderData(
      entries: entries,
      options: options,
      palette: palette,
      enableWordByWordLyric: widget.enableWordByWordLyric,
      timelineOffset: Duration(milliseconds: widget.document.offset),
    );
    _painterOwner.own(next);
    _renderData = next;
    _renderSignature = signature;
    widget.debugOnStructureBuild?.call();
    _painterOwner.retain(<LyricPaintResources?>[next, _previousRenderData]);
    return next;
  }

  String _semanticLabel(CinemaLyricPaintLine line) {
    final secondary = line.entry.line.translation.trim().isNotEmpty
        ? line.entry.line.translation.trim()
        : line.entry.line.romanization.trim();
    return secondary.isEmpty
        ? line.entry.line.text
        : '${line.entry.line.text}\n$secondary';
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _engine.lineCount == 0) return;
    _enterManualMode();
    _wheelAccumulator += event.scrollDelta.dy;
    final steps = (_wheelAccumulator / _wheelStep).truncate().clamp(-1, 1);
    if (steps != 0) {
      _wheelAccumulator = 0;
      _moveManualAnchor(steps);
    } else {
      _restartManualResetTimer();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _dragAccumulator = 0;
    _dragMoved = false;
    _enterManualMode();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_engine.lineCount == 0) return;
    _dragMoved = _dragMoved || details.delta.dy.abs() >= 1;
    _dragAccumulator -= details.delta.dy;
    final steps = (_dragAccumulator / _dragStep).truncate().clamp(-1, 1);
    if (steps != 0) {
      _dragAccumulator = 0;
      _moveManualAnchor(steps);
    } else {
      _restartManualResetTimer();
    }
  }

  void _enterManualMode() {
    if (_engine.lineCount == 0) return;
    if (_manualAnchorIndex == null) {
      final anchor = _automaticAnchorIndex();
      _beginStructureChange(() => _manualAnchorIndex = anchor, animate: false);
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
    if (current != next) {
      _beginStructureChange(() => _manualAnchorIndex = next);
    }
    _restartManualResetTimer();
  }

  void _restartManualResetTimer() {
    _manualResetTimer?.cancel();
    if (_manualAnchorIndex == null) return;
    _manualResetTimer = Timer(_manualResetDelay, _resetManualBrowse);
  }

  void _resetManualBrowse({bool animate = true}) {
    _manualResetTimer?.cancel();
    _manualResetTimer = null;
    _resetInput();
    if (_manualAnchorIndex != null && mounted) {
      _beginStructureChange(() => _manualAnchorIndex = null, animate: animate);
    }
  }

  void _resetInput() {
    _wheelAccumulator = 0;
    _dragAccumulator = 0;
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
      if (line.hitRect.contains(details.localPosition)) {
        _seekLine(line);
        return;
      }
    }
  }

  void _seekLine(CinemaLyricPaintLine line) {
    final onSeek = widget.onSeek;
    if (onSeek == null || line.entry.isInterlude) return;
    _resetManualBrowse(animate: false);
    final requested =
        line.entry.line.start - Duration(milliseconds: widget.document.offset);
    onSeek(requested.isNegative ? Duration.zero : requested);
  }
}

@immutable
class _CinemaFontSpec {
  const _CinemaFontSpec({
    required this.active,
    required this.inactive,
    required this.translation,
  });

  final double active;
  final double inactive;
  final double translation;
}

_CinemaFontSpec _resolveFontSpec(
  AppLyricFontPreset preset,
  bool compact,
  double width,
) {
  final wide = width >= 720;
  final active = switch ((preset, compact, wide)) {
    (AppLyricFontPreset.small, true, _) => 25.0,
    (AppLyricFontPreset.small, false, true) => 39.0,
    (AppLyricFontPreset.small, false, false) => 32.0,
    (AppLyricFontPreset.medium, true, _) => 29.0,
    (AppLyricFontPreset.medium, false, true) => 46.0,
    (AppLyricFontPreset.medium, false, false) => 38.0,
    (AppLyricFontPreset.large, true, _) => 33.0,
    (AppLyricFontPreset.large, false, true) => 54.0,
    (AppLyricFontPreset.large, false, false) => 44.0,
  };
  final inactive = switch (preset) {
    AppLyricFontPreset.small => compact ? 14.0 : (wide ? 19.0 : 16.0),
    AppLyricFontPreset.medium => compact ? 16.0 : (wide ? 22.0 : 18.0),
    AppLyricFontPreset.large => compact ? 18.0 : (wide ? 25.0 : 20.0),
  };
  final translation = switch (preset) {
    AppLyricFontPreset.small => compact ? 11.0 : (wide ? 15.0 : 13.0),
    AppLyricFontPreset.medium => compact ? 12.0 : (wide ? 17.0 : 15.0),
    AppLyricFontPreset.large => compact ? 13.0 : (wide ? 19.0 : 17.0),
  };
  return _CinemaFontSpec(
    active: active,
    inactive: inactive,
    translation: translation,
  );
}
