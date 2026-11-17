import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 只驱动雾、近景枝叶和萤光的绘制，静态远景保持独立缓存。
/// 页面和播放状态不参与此动画，也不会在每帧重新 build。
class AppSkinWoodlandScene extends StatefulWidget {
  const AppSkinWoodlandScene({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  State<AppSkinWoodlandScene> createState() => _AppSkinWoodlandSceneState();
}

class _AppSkinWoodlandSceneState extends State<AppSkinWoodlandScene>
    with WidgetsBindingObserver {
  final _motion = _WoodlandClock();
  AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _synchronize();
  }

  @override
  void didUpdateWidget(covariant AppSkinWoodlandScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _synchronize();
  }

  void _synchronize() {
    final active =
        widget.enabled &&
        !_reduceMotion &&
        _tickerEnabled &&
        _lifecycle == AppLifecycleState.resumed;
    _motion.setActive(active);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey('woodland-scene'),
      child: ClipRect(
        child: CustomPaint(
          foregroundPainter: WoodlandAtmospherePainter(
            motion: _motion,
            dark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}

/// 环境按约 30 Hz 发起绘制请求，不使用随屏幕 90/120 Hz 唤醒的 ticker。
/// Timer 只修改场景绘制状态；Flutter 将请求合并到下一次 vsync。
class _WoodlandClock extends ValueNotifier<double> {
  _WoodlandClock() : super(0.25);

  static const _interval = Duration(microseconds: 33333);
  static const _cycleMicroseconds = 36000000;
  Timer? _timer;

  void setActive(bool active) {
    if (!active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    var previousTick = 0;
    _timer = Timer.periodic(_interval, (timer) {
      final ticks = timer.tick - previousTick;
      previousTick = timer.tick;
      value =
          (value + ticks * _interval.inMicroseconds / _cycleMicroseconds) % 1;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class WoodlandAtmospherePainter extends CustomPainter {
  WoodlandAtmospherePainter({required this.motion, required this.dark})
    : super(repaint: motion);

  final ValueListenable<double> motion;
  final bool dark;
  static const _lights = [
    Offset(.08, .34),
    Offset(.88, .27),
    Offset(.19, .71),
    Offset(.75, .61),
    Offset(.34, .82),
    Offset(.92, .78),
    Offset(.12, .53),
    Offset(.69, .39),
    Offset(.48, .68),
    Offset(.84, .87),
    Offset(.29, .46),
    Offset(.58, .91),
    Offset(.05, .87),
    Offset(.95, .46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = motion.value * math.pi * 2;
    final mist = dark ? const Color(0xFF8ABDA8) : const Color(0xFFFCF5D1);
    final paint = Paint();
    for (var band = 0; band < 2; band++) {
      final shift = math.sin(phase * 2 + band * 2) * size.width * .12;
      final rect = Rect.fromLTWH(
        -size.width * .25 + shift,
        size.height * (.41 + band * .24 + math.cos(phase * 2 + band) * .018),
        size.width * 1.5,
        size.height * .16,
      );
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mist.withValues(alpha: 0),
          mist.withValues(alpha: dark ? .13 : .15),
          mist.withValues(alpha: 0),
        ],
      ).createShader(rect);
      canvas.drawOval(rect, paint);
    }
    paint.shader = null;
    final lightColor = dark ? const Color(0xFFF5E6A0) : const Color(0xFFFFF4C9);
    final count = dark ? _lights.length : 7;
    for (var i = 0; i < count; i++) {
      final origin = _lights[i];
      final seed = i * 2.399;
      final center = Offset(
        origin.dx * size.width + math.sin(phase * 3 + seed) * 26,
        origin.dy * size.height + math.cos(phase * 2 + seed) * 18,
      );
      final opacity = .28 + .68 * (math.sin(phase * 4 + seed) + 1) / 2;
      paint.shader = RadialGradient(
        colors: [
          lightColor.withValues(alpha: opacity * .50),
          lightColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 14));
      canvas.drawCircle(center, 14, paint);
      paint.shader = null;
      paint.color = lightColor.withValues(alpha: opacity);
      canvas.drawCircle(center, i.isEven ? 1.9 : 1.2, paint);
    }
    final frondSize = size.shortestSide.clamp(280.0, 580.0) * .30;
    final foliage = dark ? const Color(0xFF0B2928) : const Color(0xFF365D3F);
    _frond(
      canvas,
      Offset(-8, size.height * .90),
      frondSize,
      -.36 + math.sin(phase) * .015,
      foliage,
    );
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    _frond(
      canvas,
      Offset(-12, size.height * .96),
      frondSize * .85,
      -.48 + math.sin(phase + 1) * .02,
      foliage,
    );
    canvas.restore();
  }

  static void _frond(
    Canvas canvas,
    Offset origin,
    double length,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final paint = Paint()..color = color.withValues(alpha: .72);
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * .15, -length * .5, length * .08, -length);
    canvas.drawPath(
      stem,
      Paint()
        ..color = color.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 1; i <= 7; i++) {
      final y = -length * i / 8;
      final x = length * .08 * math.sin(i / 8 * math.pi);
      final leaf = length * .24 * (1 - i / 10);
      for (final side in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(
            x + side * leaf * .75,
            y + leaf * .1,
            x + side * leaf,
            y - leaf * .7,
          )
          ..quadraticBezierTo(x + side * leaf * .25, y - leaf * .9, x, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WoodlandAtmospherePainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.motion != motion;
}
