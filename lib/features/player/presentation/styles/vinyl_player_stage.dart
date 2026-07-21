import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player_track.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';

class VinylPlayerStage extends ConsumerStatefulWidget {
  const VinylPlayerStage({required this.track, super.key});

  final PlayerTrack? track;

  @override
  ConsumerState<VinylPlayerStage> createState() => _VinylPlayerStageState();
}

class _VinylPlayerStageState extends ConsumerState<VinylPlayerStage>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final AnimationController _tonearmController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  PlayerTrack? _displayedTrack;
  bool _isPlaying = false;
  bool _disableAnimations = false;
  bool _isTrackTransitioning = false;
  int _trackGeneration = 0;

  @override
  void initState() {
    super.initState();
    _displayedTrack = widget.track;
    _isPlaying = ref.read(playerControllerProvider).isPlaying;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncPlaybackAnimation();
  }

  @override
  void didUpdateWidget(covariant VinylPlayerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_trackKey(oldWidget.track) != _trackKey(widget.track)) {
      unawaited(_transitionTrack(widget.track));
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      playerControllerProvider.select((state) => state.isPlaying),
      (previous, next) {
        _isPlaying = next;
        _syncPlaybackAnimation();
      },
    );
    final imageProvider = artworkProvider(
      _displayedTrack?.artworkUrl,
      _displayedTrack?.artworkBytes,
    );
    return IgnorePointer(
      key: const ValueKey<String>('vinyl-stage-ignore-pointer'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final recordSize = math.min(
              constraints.maxWidth * 0.82,
              constraints.maxHeight * 0.92,
            );
            return Stack(
              key: const ValueKey<String>('vinyl-player-stage'),
              clipBehavior: Clip.none,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: RotationTransition(
                    key: const ValueKey<String>('vinyl-record-rotation'),
                    turns: _rotationController,
                    child: SizedBox.square(
                      dimension: recordSize,
                      child: CustomPaint(
                        painter: const VinylRecordPainter(),
                        child: Center(
                          child: _VinylCenterLabel(
                            size: recordSize * 0.31,
                            trackId: _displayedTrack?.id ?? 'empty',
                            imageProvider: imageProvider,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _tonearmController,
                    builder: (context, child) {
                      return Transform.rotate(
                        key: const ValueKey<String>('vinyl-tonearm'),
                        angle: -0.34 + (_tonearmController.value * 0.22),
                        alignment: Alignment.topCenter,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: recordSize * 0.38,
                      height: recordSize * 0.82,
                      child: CustomPaint(painter: const VinylTonearmPainter()),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _syncPlaybackAnimation() {
    final shouldPlay = _isPlaying && widget.track != null;
    if (_disableAnimations) {
      _rotationController.stop();
      _tonearmController.value = shouldPlay ? 1 : 0;
      return;
    }
    if (shouldPlay) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
    if (_isTrackTransitioning) {
      return;
    }
    if (shouldPlay) {
      unawaited(_tonearmController.forward());
    } else {
      unawaited(_tonearmController.reverse());
    }
  }

  Future<void> _transitionTrack(PlayerTrack? nextTrack) async {
    final generation = ++_trackGeneration;
    if (_disableAnimations) {
      if (!mounted || generation != _trackGeneration) return;
      setState(() => _displayedTrack = nextTrack);
      _syncPlaybackAnimation();
      return;
    }
    _isTrackTransitioning = true;
    try {
      await _tonearmController.reverse().orCancel;
      if (!mounted || generation != _trackGeneration) return;
      setState(() => _displayedTrack = nextTrack);
      if (_isPlaying && nextTrack != null) {
        await _tonearmController.forward().orCancel;
      }
    } on TickerCanceled {
      if (mounted && generation == _trackGeneration && _disableAnimations) {
        setState(() => _displayedTrack = nextTrack);
      }
    } finally {
      if (mounted && generation == _trackGeneration) {
        _isTrackTransitioning = false;
        _syncPlaybackAnimation();
      }
    }
  }

  String _trackKey(PlayerTrack? track) {
    if (track == null) return '';
    return '${track.platform ?? ''}|${track.id}';
  }
}

class _VinylCenterLabel extends StatelessWidget {
  const _VinylCenterLabel({
    required this.size,
    required this.trackId,
    required this.imageProvider,
  });

  final double size;
  final String trackId;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final image = imageProvider;
    return Container(
      key: ValueKey<String>('vinyl-center-label-$trackId'),
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF9B414D),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? const Icon(Icons.music_note_rounded, color: Color(0xFFFFE8C1))
          : Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.music_note_rounded,
                color: Color(0xFFFFE8C1),
              ),
            ),
    );
  }
}

class VinylRecordPainter extends CustomPainter {
  const VinylRecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xFF343234),
            Color(0xFF141315),
            Color(0xFF050506),
          ],
          stops: <double>[0, 0.68, 1],
        ).createShader(Offset.zero & size),
    );
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var index = 0; index < 30; index++) {
      groovePaint.color = Colors.white.withValues(
        alpha: index.isEven ? 0.075 : 0.035,
      );
      canvas.drawCircle(center, radius * (0.38 + index * 0.019), groovePaint);
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      -math.pi * 0.78,
      math.pi * 0.46,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.055
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    canvas.drawCircle(center, radius * 0.035, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant VinylRecordPainter oldDelegate) => false;
}

class VinylTonearmPainter extends CustomPainter {
  const VinylTonearmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.52, size.width * 0.28);
    final elbow = Offset(size.width * 0.50, size.height * 0.54);
    final stylus = Offset(size.width * 0.27, size.height * 0.88);
    final arm = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(stylus.dx, stylus.dy);
    canvas.drawPath(
      arm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0xFFEEE7DC),
            Color(0xFF8F8883),
            Color(0xFFD6CEC2),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      pivot,
      size.width * 0.18,
      Paint()..color = const Color(0xFF50484A),
    );
    canvas.drawCircle(
      pivot,
      size.width * 0.105,
      Paint()..color = const Color(0xFFBEB4A6),
    );
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: stylus,
        width: size.width * 0.28,
        height: size.width * 0.14,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(headRect, Paint()..color = const Color(0xFF342E30));
  }

  @override
  bool shouldRepaint(covariant VinylTonearmPainter oldDelegate) => false;
}
