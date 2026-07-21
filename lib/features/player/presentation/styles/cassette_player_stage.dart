import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player_track.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';

@visibleForTesting
double resolveCassetteTapeProgress(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

class CassettePlayerStage extends ConsumerStatefulWidget {
  const CassettePlayerStage({required this.track, super.key});

  final PlayerTrack? track;

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
    final timing = ref.watch(
      playerControllerProvider.select(
        (state) => (position: state.position, duration: state.duration),
      ),
    );
    final tapeProgress = resolveCassetteTapeProgress(
      timing.position,
      timing.duration,
    );
    final imageProvider = artworkProvider(
      widget.track?.artworkUrl,
      widget.track?.artworkBytes,
    );

    return IgnorePointer(
      key: const ValueKey<String>('cassette-stage-ignore-pointer'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final reelSize = height * 0.27;
            return Stack(
              key: const ValueKey<String>('cassette-player-stage'),
              children: <Widget>[
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: tapeProgress),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return CustomPaint(
                        key: const ValueKey<String>('cassette-shell-painter'),
                        painter: CassetteShellPainter(tapeProgress: value),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: width * 0.31 - reelSize / 2,
                  top: height * 0.50 - reelSize / 2,
                  child: _CassetteReel(
                    key: const ValueKey<String>('cassette-left-reel'),
                    size: reelSize,
                    turns: _reelController,
                  ),
                ),
                Positioned(
                  left: width * 0.69 - reelSize / 2,
                  top: height * 0.50 - reelSize / 2,
                  child: _CassetteReel(
                    key: const ValueKey<String>('cassette-right-reel'),
                    size: reelSize,
                    turns: _reelController,
                  ),
                ),
                Positioned(
                  left: width * 0.12,
                  right: width * 0.12,
                  top: height * 0.10,
                  height: height * 0.23,
                  child: _CassetteLabel(
                    track: widget.track,
                    imageProvider: imageProvider,
                  ),
                ),
              ],
            );
          },
        ),
      ),
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

class _CassetteLabel extends StatelessWidget {
  const _CassetteLabel({required this.track, required this.imageProvider});

  final PlayerTrack? track;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final image = imageProvider;
    return DecoratedBox(
      key: const ValueKey<String>('cassette-track-label'),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E0C9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFB8AD94)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: image == null
                    ? const ColoredBox(
                        color: Color(0xFF34534F),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFFE9E0C9),
                          size: 18,
                        ),
                      )
                    : Image(
                        image: image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0xFF34534F),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: Color(0xFFE9E0C9),
                                size: 18,
                              ),
                            ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track?.title ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF263532),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track?.artist ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF52635F),
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CassetteReel extends StatelessWidget {
  const _CassetteReel({required this.size, required this.turns, super.key});

  final double size;
  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turns,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: const CassetteReelPainter()),
      ),
    );
  }
}

class CassetteShellPainter extends CustomPainter {
  const CassetteShellPainter({required this.tapeProgress});

  final double tapeProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.09),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF566C68),
            Color(0xFF2D3D3A),
            Color(0xFF192724),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      outer.deflate(size.height * 0.014),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.012
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.36,
        size.width * 0.68,
        size.height * 0.31,
      ),
      Radius.circular(size.height * 0.045),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xB3192221));
    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x668FB6AE),
    );

    final leftCenter = Offset(size.width * 0.31, size.height * 0.50);
    final rightCenter = Offset(size.width * 0.69, size.height * 0.50);
    final maxTapeRadius = size.height * 0.125;
    final minTapeRadius = size.height * 0.075;
    final leftRadius = _lerp(maxTapeRadius, minTapeRadius, tapeProgress);
    final rightRadius = _lerp(minTapeRadius, maxTapeRadius, tapeProgress);
    final tapePaint = Paint()..color = const Color(0xFF211715);
    canvas.drawCircle(leftCenter, leftRadius, tapePaint);
    canvas.drawCircle(rightCenter, rightRadius, tapePaint);
    canvas.drawLine(
      Offset(leftCenter.dx, leftCenter.dy + leftRadius * 0.72),
      Offset(rightCenter.dx, rightCenter.dy + rightRadius * 0.72),
      Paint()
        ..color = const Color(0xFF2C1C18)
        ..strokeWidth = size.height * 0.018
        ..strokeCap = StrokeCap.round,
    );

    final lowerPlate = Path()
      ..moveTo(size.width * 0.23, size.height * 0.73)
      ..lineTo(size.width * 0.77, size.height * 0.73)
      ..lineTo(size.width * 0.68, size.height * 0.92)
      ..lineTo(size.width * 0.32, size.height * 0.92)
      ..close();
    canvas.drawPath(lowerPlate, Paint()..color = const Color(0xFFBBC2B9));
    canvas.drawPath(
      lowerPlate,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF6E7770),
    );

    final screwPaint = Paint()..color = const Color(0xFFC7CCC7);
    for (final center in <Offset>[
      Offset(size.width * 0.07, size.height * 0.10),
      Offset(size.width * 0.93, size.height * 0.10),
      Offset(size.width * 0.08, size.height * 0.88),
      Offset(size.width * 0.92, size.height * 0.88),
    ]) {
      canvas.drawCircle(center, size.height * 0.018, screwPaint);
    }
  }

  double _lerp(double start, double end, double value) {
    return start + ((end - start) * value);
  }

  @override
  bool shouldRepaint(covariant CassetteShellPainter oldDelegate) {
    return oldDelegate.tapeProgress != tapeProgress;
  }
}

class CassetteReelPainter extends CustomPainter {
  const CassetteReelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFE0DED3));
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()..color = const Color(0xFF6D7772),
    );
    final spokePaint = Paint()
      ..color = const Color(0xFFECE9DB)
      ..strokeWidth = radius * 0.17
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 6; index++) {
      final angle = (math.pi * 2 * index) / 6;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.24,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.62,
        spokePaint,
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.20,
      Paint()..color = const Color(0xFF26312F),
    );
  }

  @override
  bool shouldRepaint(covariant CassetteReelPainter oldDelegate) => false;
}
