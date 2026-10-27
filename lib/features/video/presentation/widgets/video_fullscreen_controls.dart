import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_link.dart';
import '../../playback/controllers/video_picture_in_picture_controller.dart';
import '../../playback/controllers/video_playback_controller.dart';
import '../../playback/entities/video_playback_surface.dart';

/// Fullscreen chrome owns low-frequency control state. Playback timing is
/// consumed only by [_FullscreenProgress], never by the page or this widget.
class VideoFullscreenControls extends StatefulWidget {
  const VideoFullscreenControls({
    required this.playback,
    required this.surface,
    required this.content,
    required this.title,
    required this.gestureTheme,
    required this.pictureInPicture,
    required this.onExit,
    super.key,
  });

  final VideoPlaybackController playback;
  final VideoPlaybackSurface surface;
  final VideoDetailContent? content;
  final String title;
  final MaterialVideoControlsThemeData gestureTheme;
  final VideoPictureInPictureController pictureInPicture;
  final Future<void> Function() onExit;

  @override
  State<VideoFullscreenControls> createState() =>
      _VideoFullscreenControlsState();
}

class _VideoFullscreenControlsState extends State<VideoFullscreenControls> {
  Timer? _hideTimer;
  bool _visible = true;
  bool _locked = false;
  bool _choosing = false;
  BoxFit _fit = BoxFit.contain;
  String? _hud;
  Duration? _seekPreview;
  Offset? _dragOrigin;
  Duration _dragPosition = Duration.zero;
  double _dragVolume = 1;
  double _dragBrightness = 0.5;
  late double _brightness;
  late ({
    bool playing,
    bool buffering,
    double rate,
    String? quality,
    bool switching,
  })
  _state;

  String _label(String key) => AppI18n.tByLocaleCode(
    Localizations.localeOf(context).languageCode,
    'video.fullscreen.$key',
  );

  @override
  void initState() {
    super.initState();
    _brightness = widget.gestureTheme.initialBrightness ?? 0.5;
    _state = _readState();
    widget.playback.addListener(_onPlayback);
    widget.pictureInPicture.addListener(_onPip);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.playback.removeListener(_onPlayback);
    widget.pictureInPicture.removeListener(_onPip);
    // The fullscreen route and its underlying view share one fit notifier.
    scheduleMicrotask(() => widget.surface.setFit(BoxFit.contain));
    widget.gestureTheme.onBrightnessReset?.call();
    super.dispose();
  }

  ({bool playing, bool buffering, double rate, String? quality, bool switching})
  _readState() => (
    playing: widget.surface.state.isPlaying,
    buffering: widget.surface.state.isBuffering,
    rate: widget.surface.state.rate,
    quality: widget.playback.state.currentSlot?.selectedQualityKey,
    switching: widget.playback.state.isSwitchingQuality,
  );

  void _onPlayback() {
    final next = _readState();
    if (next == _state) return;
    final playingChanged = next.playing != _state.playing;
    setState(() => _state = next);
    if (playingChanged) _scheduleHide();
  }

  void _onPip() {
    if (!widget.pictureInPicture.active && !widget.pictureInPicture.entering) {
      _locked = false;
      _visible = true;
      _scheduleHide();
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_state.playing || _choosing || !_visible) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_choosing) setState(() => _visible = false);
    });
  }

  void _showControls() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  Future<T?> _choose<T>(
    String title,
    List<Widget> Function(BuildContext) items,
  ) async {
    _hideTimer?.cancel();
    _choosing = true;
    try {
      return await showAppThemedBottomSheet<T>(
        context: context,
        heightFactor: 0.85,
        fitContent: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ...items(sheetContext),
            ],
          ),
        ),
      );
    } finally {
      _choosing = false;
      if (mounted) _showControls();
    }
  }

  Widget _option<T>(
    BuildContext context,
    String label,
    T value,
    bool selected, {
    String? subtitle,
  }) => ListTile(
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle),
    selected: selected,
    trailing: selected ? const Icon(Icons.check_rounded) : null,
    onTap: () => Navigator.of(context).pop(value),
  );

  VideoDetailLink? get _selectedQuality {
    final links = widget.content?.links ?? const <VideoDetailLink>[];
    for (final link in links) {
      if (link.cacheKey == _state.quality) return link;
    }
    return links.isEmpty ? null : links.first;
  }

  Future<void> _chooseQuality() async {
    final links = [...?widget.content?.links]
      ..sort((a, b) => b.quality.compareTo(a.quality));
    final link = await _choose<VideoDetailLink>(
      _label('quality'),
      (context) => [
        for (final link in links)
          _option(
            context,
            link.qualityLabel,
            link,
            link.cacheKey == _state.quality,
          ),
      ],
    );
    if (link == null || !mounted) return;
    final success = await widget.playback.switchQuality(
      link,
      preserveSurface: true,
    );
    if (!mounted) return;
    if (!success) _showMessage(_label('quality_failed'));
    _showControls();
  }

  Future<void> _chooseRate() async {
    final rate = await _choose<double>(
      _label('speed'),
      (context) => [
        for (final rate in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          _option(context, _rateLabel(rate), rate, rate == _state.rate),
      ],
    );
    if (rate == null || !mounted) return;
    try {
      await widget.surface.setRate(rate);
    } catch (_) {
      if (mounted) _showMessage(_label('setting_failed'));
    }
  }

  Future<void> _chooseFit() async {
    final fit = await _choose<BoxFit>(
      _label('fit'),
      (context) => [
        _option(
          context,
          _label('fit_contain'),
          BoxFit.contain,
          _fit == BoxFit.contain,
        ),
        _option(
          context,
          _label('fit_cover'),
          BoxFit.cover,
          _fit == BoxFit.cover,
          subtitle: _label('fit_cover_hint'),
        ),
        _option(
          context,
          _label('fit_fill'),
          BoxFit.fill,
          _fit == BoxFit.fill,
          subtitle: _label('fit_fill_hint'),
        ),
      ],
    );
    if (fit == null || !mounted) return;
    widget.surface.setFit(fit);
    setState(() => _fit = fit);
  }

  Future<void> _enterPip() async {
    final success = await widget.pictureInPicture.enter(
      aspectRatio: widget.surface.state.aspectRatio,
      playing: widget.surface.state.isPlaying,
    );
    if (!success && mounted) _showMessage(_label('pip_failed'));
  }

  void _showMessage(String message) {
    setState(() => _hud = message);
    _showControls();
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _visible = true;
      _hud = null;
    });
    _scheduleHide();
  }

  Future<void> _togglePlayback() async {
    if (_locked || _state.switching) return;
    await widget.playback.togglePlayPause();
    if (mounted) _showControls();
  }

  void _seekBy(int seconds) {
    if (_locked || _state.switching) return;
    final current = widget.surface.state;
    final target = (current.position + Duration(seconds: seconds))
        .inMilliseconds
        .clamp(0, current.duration.inMilliseconds);
    unawaited(widget.playback.seekCurrent(Duration(milliseconds: target)));
    _showControls();
  }

  void _startDrag(DragStartDetails details) {
    _hideTimer?.cancel();
    _dragOrigin = details.localPosition;
    _dragPosition = widget.surface.state.position;
    _dragVolume = (widget.surface.state.volume / 100).clamp(0.0, 1.0);
    _dragBrightness = _brightness;
  }

  void _horizontalDrag(DragUpdateDetails details) {
    final origin = _dragOrigin;
    if (origin == null) return;
    final duration = widget.surface.state.duration.inMilliseconds;
    final delta = (details.localPosition.dx - origin.dx) / 1000 * duration;
    final target = (_dragPosition.inMilliseconds + delta).round().clamp(
      0,
      duration,
    );
    setState(() {
      _seekPreview = Duration(milliseconds: target);
      _hud = _time(_seekPreview!);
    });
  }

  void _verticalDrag(DragUpdateDetails details, double width, double height) {
    final origin = _dragOrigin;
    if (origin == null || height <= 0) return;
    final delta = (origin.dy - details.localPosition.dy) / height;
    if (origin.dx < width / 2) {
      final value = (_dragBrightness + delta).clamp(0.0, 1.0);
      _brightness = value;
      widget.gestureTheme.onBrightnessChanged?.call(value);
      setState(
        () => _hud = '${_label('brightness')} ${(value * 100).round()}%',
      );
    } else {
      final value = (_dragVolume + delta).clamp(0.0, 1.0);
      widget.gestureTheme.onVolumeChanged?.call(value);
      setState(() => _hud = '${_label('volume')} ${(value * 100).round()}%');
    }
  }

  void _endDrag({bool commit = true}) {
    if (commit && _seekPreview != null) {
      unawaited(widget.playback.seekCurrent(_seekPreview!));
    }
    _dragOrigin = null;
    setState(() {
      _seekPreview = null;
      _hud = null;
    });
    _scheduleHide();
  }

  Widget _icon(
    String key,
    String tooltip,
    IconData icon,
    VoidCallback? onPressed,
  ) => IconButton(
    key: ValueKey('video-fullscreen-$key'),
    tooltip: tooltip,
    color: Colors.white,
    icon: Icon(icon),
    onPressed: onPressed,
  );

  Widget _textAction(
    String key,
    String tooltip,
    String text,
    VoidCallback? onPressed,
  ) => TextButton(
    key: ValueKey('video-fullscreen-$key'),
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    onPressed: onPressed,
    child: Tooltip(message: tooltip, child: Text(text)),
  );

  @override
  Widget build(BuildContext context) {
    final pip = widget.pictureInPicture;
    if (pip.active || pip.entering) return const SizedBox.expand();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_locked) {
            _toggleLock();
          } else {
            unawaited(widget.onExit());
          }
        },
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(_togglePlayback()),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(10),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                key: const ValueKey('video-fullscreen-gesture-area'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _visible = !_visible;
                    _hud = null;
                  });
                  _scheduleHide();
                },
                onDoubleTapDown: _locked
                    ? null
                    : (details) {
                        _dragOrigin = details.localPosition;
                      },
                onDoubleTap: _locked
                    ? null
                    : () {
                        final x = _dragOrigin?.dx ?? constraints.maxWidth / 2;
                        if (x < constraints.maxWidth / 3) {
                          _seekBy(-10);
                        } else if (x > constraints.maxWidth * 2 / 3) {
                          _seekBy(10);
                        } else {
                          unawaited(_togglePlayback());
                        }
                      },
                onHorizontalDragStart: _locked || _state.switching
                    ? null
                    : _startDrag,
                onHorizontalDragUpdate: _locked || _state.switching
                    ? null
                    : _horizontalDrag,
                onHorizontalDragEnd: _locked || _state.switching
                    ? null
                    : (_) => _endDrag(),
                onHorizontalDragCancel: _locked || _state.switching
                    ? null
                    : () => _endDrag(commit: false),
                onVerticalDragStart: _locked || _state.switching
                    ? null
                    : _startDrag,
                onVerticalDragUpdate: _locked || _state.switching
                    ? null
                    : (details) => _verticalDrag(
                        details,
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                onVerticalDragEnd: _locked || _state.switching
                    ? null
                    : (_) => _endDrag(),
                onVerticalDragCancel: _locked || _state.switching
                    ? null
                    : () => _endDrag(commit: false),
              ),
              if (_hud != null && !_locked)
                Center(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _hud!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              if ((_state.buffering || _state.switching) && !_locked)
                const Center(
                  child: IgnorePointer(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              IgnorePointer(
                ignoring: !_visible || _locked,
                child: ExcludeFocus(
                  excluding: !_visible || _locked,
                  child: ExcludeSemantics(
                    excluding: !_visible || _locked,
                    child: AnimatedOpacity(
                      opacity: _visible && !_locked ? 1 : 0,
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      _icon(
                                        'back',
                                        MaterialLocalizations.of(
                                          context,
                                        ).backButtonTooltip,
                                        Icons.arrow_back_rounded,
                                        () => unawaited(widget.onExit()),
                                      ),
                                      Expanded(
                                        child: Text(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (pip.available &&
                                          constraints.maxWidth >= 520)
                                        _icon(
                                          'pip',
                                          _label('pip'),
                                          Icons.picture_in_picture_alt_rounded,
                                          () => unawaited(_enterPip()),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: _icon(
                              'play-pause',
                              _label(_state.playing ? 'pause' : 'play'),
                              _state.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              _state.switching
                                  ? null
                                  : () => unawaited(_togglePlayback()),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: _FullscreenProgress(
                                    surface: widget.surface,
                                    enabled: !_state.switching && !_locked,
                                    onStart: () => _hideTimer?.cancel(),
                                    onEnd: _showControls,
                                    actions: [
                                      if (_selectedQuality != null)
                                        _textAction(
                                          'quality',
                                          _label('quality'),
                                          _selectedQuality!.qualityLabel,
                                          _state.switching ||
                                                  (widget
                                                              .content
                                                              ?.links
                                                              .length ??
                                                          0) <
                                                      2
                                              ? null
                                              : () =>
                                                    unawaited(_chooseQuality()),
                                        ),
                                      _textAction(
                                        'speed',
                                        _label('speed'),
                                        _rateLabel(_state.rate),
                                        _state.switching
                                            ? null
                                            : () => unawaited(_chooseRate()),
                                      ),
                                      if (constraints.maxWidth >= 520)
                                        _icon(
                                          'fit',
                                          _label('fit'),
                                          Icons.aspect_ratio_rounded,
                                          () => unawaited(_chooseFit()),
                                        )
                                      else
                                        PopupMenuButton<String>(
                                          key: const ValueKey(
                                            'video-fullscreen-more',
                                          ),
                                          tooltip: _label('more'),
                                          iconColor: Colors.white,
                                          onOpened: () {
                                            _choosing = true;
                                            _hideTimer?.cancel();
                                          },
                                          onCanceled: () {
                                            _choosing = false;
                                            _showControls();
                                          },
                                          onSelected: (value) {
                                            _choosing = false;
                                            if (value == 'fit') {
                                              unawaited(_chooseFit());
                                            } else {
                                              unawaited(_enterPip());
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'fit',
                                              child: Text(_label('fit')),
                                            ),
                                            if (pip.available)
                                              PopupMenuItem(
                                                value: 'pip',
                                                child: Text(_label('pip')),
                                              ),
                                          ],
                                        ),
                                      _icon(
                                        'exit',
                                        _label('exit'),
                                        Icons.fullscreen_exit_rounded,
                                        () => unawaited(widget.onExit()),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_visible)
                Positioned(
                  left: MediaQuery.paddingOf(context).left + 12,
                  top: constraints.maxHeight / 2 - 24,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                    child: _icon(
                      _locked ? 'unlock' : 'lock',
                      _label(_locked ? 'unlock' : 'lock'),
                      _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      _toggleLock,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rateLabel(double rate) =>
    '${rate.toStringAsFixed(rate * 10 == (rate * 10).roundToDouble() ? 1 : 2)}×';

String _time(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _FullscreenProgress extends StatefulWidget {
  const _FullscreenProgress({
    required this.surface,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
    required this.actions,
  });
  final VideoPlaybackSurface surface;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final List<Widget> actions;

  @override
  State<_FullscreenProgress> createState() => _FullscreenProgressState();
}

class _FullscreenProgressState extends State<_FullscreenProgress> {
  double? _drag;
  late ({Duration position, Duration duration}) _timing;

  @override
  void initState() {
    super.initState();
    _timing = _readTiming();
    widget.surface.addListener(_onTiming);
  }

  ({Duration position, Duration duration}) _readTiming() => (
    position: widget.surface.state.position,
    duration: widget.surface.state.duration,
  );

  void _onTiming() {
    final next = _readTiming();
    if (next != _timing) setState(() => _timing = next);
  }

  @override
  void dispose() {
    widget.surface.removeListener(_onTiming);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _timing.duration.inMilliseconds;
    final value =
        _drag ??
        (total > 0 ? _timing.position.inMilliseconds / total : 0.0).clamp(
          0.0,
          1.0,
        );
    final position = _drag == null
        ? _timing.position
        : Duration(milliseconds: (value * total).round());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white38,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            key: const ValueKey('video-fullscreen-progress'),
            value: value,
            onChangeStart: widget.enabled && total > 0
                ? (_) => widget.onStart()
                : null,
            onChanged: widget.enabled && total > 0
                ? (value) => setState(() => _drag = value)
                : null,
            onChangeEnd: widget.enabled && total > 0
                ? (value) async {
                    try {
                      await widget.surface.seekTo(
                        Duration(milliseconds: (value * total).round()),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _drag = null);
                        widget.onEnd();
                      }
                    }
                  }
                : null,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_time(position)} / ${_time(_timing.duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            ...widget.actions,
          ],
        ),
      ],
    );
  }
}
