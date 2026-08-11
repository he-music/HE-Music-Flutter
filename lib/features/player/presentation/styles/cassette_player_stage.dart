import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../../../../app/theme/player/styles/cassette_player_palette.dart';
import '../../domain/entities/player_track.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';

Path _cassetteShellPath(Size size) {
  final cut = size.height * 0.09;
  return Path()
    ..moveTo(cut, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height - cut)
    ..lineTo(size.width - cut, size.height)
    ..lineTo(cut, size.height)
    ..lineTo(0, size.height - cut)
    ..lineTo(0, cut)
    ..close();
}

Path _notchedRectPath(Rect rect, double cut) {
  return Path()
    ..moveTo(rect.left + cut, rect.top)
    ..lineTo(rect.right - cut, rect.top)
    ..lineTo(rect.right, rect.top + cut)
    ..lineTo(rect.right, rect.bottom - cut)
    ..lineTo(rect.right - cut, rect.bottom)
    ..lineTo(rect.left + cut, rect.bottom)
    ..lineTo(rect.left, rect.bottom - cut)
    ..lineTo(rect.left, rect.top + cut)
    ..close();
}

@visibleForTesting
double resolveCassetteTapeProgress(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

class CassettePlayerStage extends ConsumerStatefulWidget {
  const CassettePlayerStage({required this.track, this.label, super.key});

  final PlayerTrack? track;
  final Widget? label;

  @override
  ConsumerState<CassettePlayerStage> createState() =>
      _CassettePlayerStageState();
}

class _CassettePlayerStageState extends ConsumerState<CassettePlayerStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reelController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  bool _isPlaying = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = ref.read(playerControllerProvider).isPlaying;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncReels();
  }

  @override
  void dispose() {
    _reelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      playerControllerProvider.select((state) => state.isPlaying),
      (previous, next) {
        _isPlaying = next;
        _syncReels();
      },
    );
    final imageProvider = artworkProvider(
      widget.track?.artworkUrl,
      widget.track?.artworkBytes,
    );
    final palette =
        PlayerScenePalette.maybeOf(context) ?? CassettePlayerPalette.fallback;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final reelSize = height * 0.30;
        return Stack(
          key: const ValueKey<String>('cassette-player-stage'),
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                key: const ValueKey<String>('cassette-stage-ignore-pointer'),
                child: RepaintBoundary(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(child: _CassetteTapeLayer(palette)),
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey<String>('cassette-light-sweep'),
                          painter: CassetteLightSweepPainter(
                            phase: _reelController,
                            palette: palette,
                          ),
                        ),
                      ),
                      Positioned(
                        left: width * 0.28 - reelSize / 2,
                        top: height * 0.57 - reelSize / 2,
                        child: _CassetteReel(
                          key: const ValueKey<String>('cassette-left-reel'),
                          size: reelSize,
                          turns: _reelController,
                          palette: palette,
                        ),
                      ),
                      Positioned(
                        left: width * 0.72 - reelSize / 2,
                        top: height * 0.57 - reelSize / 2,
                        child: _CassetteReel(
                          key: const ValueKey<String>('cassette-right-reel'),
                          size: reelSize,
                          turns: _reelController,
                          palette: palette,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * 0.10,
              right: width * 0.10,
              top: height * 0.045,
              height: height * 0.285,
              child: _CassetteLabel(
                imageProvider: imageProvider,
                palette: palette,
                child: widget.label,
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncReels() {
    final shouldPlay = _isPlaying && widget.track != null;
    if (_disableAnimations || !shouldPlay) {
      _reelController.stop();
      return;
    }
    if (!_reelController.isAnimating) {
      _reelController.repeat();
    }
  }
}

class _CassetteTapeLayer extends ConsumerWidget {
  const _CassetteTapeLayer(this.palette);

  final PlayerScenePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = ref.watch(
      playerControllerProvider.select(
        (state) => (position: state.position, duration: state.duration),
      ),
    );
    final tapeProgress = resolveCassetteTapeProgress(
      timing.position,
      timing.duration,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: tapeProgress),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return CustomPaint(
          key: const ValueKey<String>('cassette-shell-painter'),
          painter: CassetteShellPainter(tapeProgress: value, palette: palette),
        );
      },
    );
  }
}

class _CassetteLabel extends StatelessWidget {
  const _CassetteLabel({
    required this.imageProvider,
    required this.palette,
    required this.child,
  });

  final ImageProvider<Object>? imageProvider;
  final PlayerScenePalette palette;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final image = imageProvider;
    return DecoratedBox(
      key: const ValueKey<String>('cassette-track-label'),
      decoration: BoxDecoration(
        color: palette.surfaceDeep.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.edge.withValues(alpha: 0.68)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.edge.withValues(alpha: 0.14),
            blurRadius: 10,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 手机横屏时收紧标签内边距，避免改变磁带主体比例。
          final compact = constraints.maxHeight < 48;
          final padding = compact ? 4.0 : 6.0;
          final labelFontSize = compact ? 8.0 : 10.0;
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: <Widget>[
                AspectRatio(
                  key: const ValueKey<String>('cassette-label-cover'),
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: palette.edge.withValues(alpha: 0.42),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: image == null
                          ? _buildFallbackCover()
                          : Image(
                              image: image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackCover(),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 6 : 9),
                Expanded(
                  child: child ?? _buildDecorativeLabel(labelFontSize, compact),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackCover() {
    return ColoredBox(
      color: palette.surfaceRaised,
      child: Icon(Icons.music_note_rounded, color: palette.edge, size: 16),
    );
  }

  Widget _buildDecorativeLabel(double labelFontSize, bool compact) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ColoredBox(
                color: palette.edge.withValues(alpha: 0.42),
                child: const SizedBox(height: 1),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'SIDE A',
              style: TextStyle(
                color: palette.edge,
                fontSize: labelFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 3 : 5),
        Row(
          children: <Widget>[
            Expanded(
              child: ColoredBox(
                color: palette.foreground.withValues(alpha: 0.20),
                child: const SizedBox(height: 1),
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 4),
            ),
          ],
        ),
      ],
    );
  }
}

class _CassetteReel extends StatelessWidget {
  const _CassetteReel({
    required this.size,
    required this.turns,
    required this.palette,
    super.key,
  });

  final double size;
  final Animation<double> turns;
  final PlayerScenePalette palette;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turns,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: CassetteReelPainter(palette: palette)),
      ),
    );
  }
}

class CassetteShellPainter extends CustomPainter {
  const CassetteShellPainter({
    required this.tapeProgress,
    this.palette = CassettePlayerPalette.fallback,
  });

  final double tapeProgress;
  final PlayerScenePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final shell = _cassetteShellPath(size);
    canvas.drawPath(
      shell,
      Paint()
        ..color = palette.edge.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.055),
    );
    canvas.drawPath(
      shell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surface.withValues(alpha: 0.96),
            palette.surfaceDeep.withValues(alpha: 0.96),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.012
        ..color = palette.edge.withValues(alpha: 0.78),
    );

    final windowRect = Rect.fromLTWH(
      size.width * 0.075,
      size.height * 0.34,
      size.width * 0.85,
      size.height * 0.43,
    );
    final window = _notchedRectPath(windowRect, size.height * 0.055);
    canvas.drawPath(
      window,
      Paint()..color = palette.surfaceDeep.withValues(alpha: 0.90),
    );
    canvas.drawPath(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.008
        ..color = palette.edge.withValues(alpha: 0.42),
    );

    final leftCenter = Offset(size.width * 0.28, size.height * 0.57);
    final rightCenter = Offset(size.width * 0.72, size.height * 0.57);
    final maxTapeRadius = size.height * 0.185;
    final minTapeRadius = size.height * 0.095;
    // 两侧磁带盘半径随播放进度反向变化，拖动后磁带量同步过渡。
    final leftRadius = _lerp(maxTapeRadius, minTapeRadius, tapeProgress);
    final rightRadius = _lerp(minTapeRadius, maxTapeRadius, tapeProgress);
    final tapePaint = Paint()
      ..color = Color.lerp(palette.surfaceDeep, palette.accent, 0.14)!;
    canvas.drawCircle(leftCenter, leftRadius, tapePaint);
    canvas.drawCircle(rightCenter, rightRadius, tapePaint);
    _drawTapeRings(canvas, leftCenter, leftRadius);
    _drawTapeRings(canvas, rightCenter, rightRadius);

    canvas.drawLine(
      leftCenter,
      rightCenter,
      Paint()
        ..color = Color.lerp(palette.surfaceRaised, palette.accent, 0.24)!
        ..strokeWidth = size.height * 0.018
        ..strokeCap = StrokeCap.round,
    );
    final progressEnd = Offset(
      _lerp(leftCenter.dx, rightCenter.dx, tapeProgress),
      leftCenter.dy,
    );
    canvas.drawLine(
      leftCenter,
      progressEnd,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.42)
        ..strokeWidth = size.height * 0.045
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.04),
    );
    canvas.drawLine(
      leftCenter,
      progressEnd,
      Paint()
        ..color = palette.accent
        ..strokeWidth = size.height * 0.010
        ..strokeCap = StrokeCap.round,
    );

    final dataRail = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.86,
        size.width * 0.60,
        size.height * 0.042,
      ),
      Radius.circular(size.height * 0.021),
    );
    canvas.drawRRect(dataRail, Paint()..color = palette.surfaceDeep);
    final railStart = size.width * 0.225;
    final railGap = size.width * 0.065;
    for (var index = 0; index < 9; index++) {
      canvas.drawLine(
        Offset(railStart + railGap * index, size.height * 0.881),
        Offset(
          railStart + railGap * index + size.width * 0.024,
          size.height * 0.881,
        ),
        Paint()
          ..color = index == 0
              ? palette.accent
              : palette.edge.withValues(alpha: 0.38)
          ..strokeWidth = size.height * 0.008
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final center in <Offset>[
      Offset(size.width * 0.045, size.height * 0.15),
      Offset(size.width * 0.955, size.height * 0.15),
      Offset(size.width * 0.045, size.height * 0.85),
      Offset(size.width * 0.955, size.height * 0.85),
    ]) {
      _drawFastener(canvas, center, size.height * 0.024);
    }
  }

  void _drawTapeRings(Canvas canvas, Offset center, double radius) {
    for (final scale in <double>[0.72, 0.46]) {
      canvas.drawCircle(
        center,
        radius * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.035
          ..color = palette.accent.withValues(alpha: 0.12),
      );
    }
  }

  void _drawFastener(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.8,
      Paint()
        ..color = palette.edge.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius),
    );
    canvas.drawCircle(center, radius, Paint()..color = palette.surfaceDeep);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.32
        ..color = palette.edge.withValues(alpha: 0.85),
    );
  }

  double _lerp(double start, double end, double value) {
    return start + ((end - start) * value);
  }

  @override
  bool shouldRepaint(covariant CassetteShellPainter oldDelegate) {
    return oldDelegate.tapeProgress != tapeProgress ||
        oldDelegate.palette != palette;
  }
}

class CassetteLightSweepPainter extends CustomPainter {
  CassetteLightSweepPainter({
    required Animation<double> phase,
    required this.palette,
  }) : _phase = phase,
       super(repaint: phase);

  final Animation<double> _phase;
  final PlayerScenePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = -size.width * 0.22 + size.width * 1.44 * _phase.value;
    final sweepWidth = size.width * 0.10;
    final sweep = Path()
      ..moveTo(centerX - sweepWidth, 0)
      ..lineTo(centerX, 0)
      ..lineTo(centerX + sweepWidth, size.height)
      ..lineTo(centerX, size.height)
      ..close();
    canvas
      ..save()
      ..clipPath(_cassetteShellPath(size))
      ..drawPath(
        sweep,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              palette.edge.withValues(alpha: 0),
              palette.edge.withValues(alpha: 0.14),
              palette.foreground.withValues(alpha: 0),
            ],
          ).createShader(sweep.getBounds()),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CassetteLightSweepPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class CassetteReelPainter extends CustomPainter {
  const CassetteReelPainter({this.palette = CassettePlayerPalette.fallback});

  final PlayerScenePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = palette.edge.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
    );
    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()..color = palette.surfaceDeep,
    );
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07
        ..color = palette.edge,
    );
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()..color = palette.surfaceRaised,
    );
    final spokePaint = Paint()
      ..color = palette.foreground
      ..strokeWidth = radius * 0.13
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 8; index++) {
      final angle = (math.pi * 2 * index) / 8;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.24,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.54,
        spokePaint,
      );
    }
    canvas.drawCircle(center, radius * 0.17, Paint()..color = palette.accent);
  }

  @override
  bool shouldRepaint(covariant CassetteReelPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}
