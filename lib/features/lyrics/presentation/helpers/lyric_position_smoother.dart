import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Interpolates only between received samples; never predicts playback time.
class LyricPositionSmoother extends ValueNotifier<Duration> {
  LyricPositionSmoother({
    required TickerProvider vsync,
    required Duration position,
  }) : _source = position,
       _start = position,
       super(position) {
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 33),
    )..addListener(_tick);
  }

  late final AnimationController _controller;
  Duration _source;
  Duration _start;
  bool _enabled = true;
  bool _snapNext = false;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) snap(_source);
  }

  void update(Duration position, {bool discontinuity = false}) {
    final delta = position - _source;
    if (!_enabled ||
        _snapNext ||
        discontinuity ||
        delta <= Duration.zero ||
        delta > const Duration(milliseconds: 100)) {
      _snapNext = false;
      snap(position);
      return;
    }
    _start = value;
    _source = position;
    _controller.forward(from: 0);
  }

  void snap(Duration position) {
    _controller.stop();
    _source = position;
    _start = position;
    value = position;
  }

  void seek() {
    snap(_source);
    _snapNext = true;
  }

  void _tick() {
    value = Duration(
      microseconds:
          _start.inMicroseconds +
          ((_source - _start).inMicroseconds * _controller.value).round(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
