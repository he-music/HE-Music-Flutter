import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

import '../helpers/player_image_color_helper.dart';

/// 使用封面原始色调生成持续流动的播放器背景。
class FluidPlayerBackdrop extends StatefulWidget {
  const FluidPlayerBackdrop({required this.imageProvider, super.key});

  final ImageProvider<Object>? imageProvider;

  @override
  State<FluidPlayerBackdrop> createState() => _FluidPlayerBackdropState();
}

class _FluidPlayerBackdropState extends State<FluidPlayerBackdrop>
    with SingleTickerProviderStateMixin {
  static const Duration _paletteTransitionDuration = Duration(
    milliseconds: 900,
  );
  static const Duration _motionDuration = Duration(seconds: 24);
  static final MeshGradientOptions _meshOptions = MeshGradientOptions(
    blend: 3.5,
    noiseIntensity: 0.08,
  );

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: _motionDuration,
    value: 0.17,
  );

  int _paletteGeneration = 0;
  int _paletteVersion = 0;
  bool? _animationsDisabled;
  List<Color> _currentPalette = const <Color>[];
  List<Color> _previousPalette = const <Color>[];

  @override
  void initState() {
    super.initState();
    _refreshPalette();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;
    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _motionController.stop();
    } else {
      _motionController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FluidPlayerBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _refreshPalette();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _refreshPalette() async {
    final generation = ++_paletteGeneration;
    final candidates = await colorsFromImageProvider(
      widget.imageProvider,
      prioritizeSaturation: false,
    );
    final resolved = _resolveFluidPalette(candidates);
    if (!mounted || generation != _paletteGeneration) return;
    setState(() {
      _previousPalette = _currentPalette.isEmpty
          ? resolved
          : List<Color>.of(_currentPalette);
      _currentPalette = resolved;
      _paletteVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetPalette = _currentPalette.isEmpty
        ? _fallbackFluidPalette
        : _currentPalette;
    final previousPalette = _previousPalette.isEmpty
        ? targetPalette
        : _previousPalette;
    final animationsDisabled = _animationsDisabled ?? false;

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_paletteVersion),
      tween: Tween<double>(begin: 0, end: 1),
      duration: animationsDisabled ? Duration.zero : _paletteTransitionDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final palette = _blendFluidPalettes(
          previousPalette,
          targetPalette,
          value,
        );
        return Stack(
          key: const ValueKey<String>('player-backdrop-fluid'),
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[palette.first, palette[3], palette.last],
                ),
              ),
            ),
            IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _motionController,
                  builder: (context, child) {
                    return MeshGradient(
                      key: ValueKey<String>(
                        'player-fluid-mesh-'
                        '${animationsDisabled ? 'static' : 'animated'}',
                      ),
                      points: _buildFluidMeshPoints(
                        palette,
                        _motionController.value,
                      ),
                      options: _meshOptions,
                      child: child,
                    );
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            DecoratedBox(
              key: const ValueKey<String>('player-fluid-readability-mask'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                  stops: const <double>[0, 0.48, 1],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
List<Color> resolveFluidPaletteForTest(List<Color> colors) {
  return _resolveFluidPalette(colors);
}

List<Color> _resolveFluidPalette(List<Color> candidates) {
  final unique = <Color>[];
  final seen = <int>{};
  for (final color in candidates) {
    final bounded = _boundFluidColor(color);
    if (seen.add(bounded.toARGB32())) {
      unique.add(bounded);
    }
  }
  if (unique.isEmpty) return const <Color>[];

  final seeds = unique.take(6).toList(growable: false);
  final palette = List<Color>.of(seeds);
  final paletteValues = palette.map((color) => color.toARGB32()).toSet();
  const lightnessDeltas = <double>[
    -0.03,
    0.03,
    -0.06,
    0.06,
    -0.09,
    0.09,
    -0.12,
    0.12,
    -0.15,
    0.15,
  ];
  for (final delta in lightnessDeltas) {
    for (final seed in seeds) {
      final tone = _adjustFluidLightness(seed, delta);
      if (paletteValues.add(tone.toARGB32())) {
        palette.add(tone);
      }
      if (palette.length == 6) return palette;
    }
  }
  return palette;
}

Color _boundFluidColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness(hsl.lightness.clamp(0.08, 0.72)).toColor();
}

Color _adjustFluidLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.08, 0.72)).toColor();
}

const List<Color> _fallbackFluidPalette = <Color>[
  Color(0xFF315A88),
  Color(0xFF704D87),
  Color(0xFF2A796F),
  Color(0xFF8B5969),
  Color(0xFF243754),
  Color(0xFF514368),
];

@visibleForTesting
List<Color> fallbackFluidPaletteForTest() {
  return _fallbackFluidPalette;
}

class _FluidPointPath {
  const _FluidPointPath({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.frequencyX,
    required this.frequencyY,
    required this.phaseX,
    required this.phaseY,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final int frequencyX;
  final int frequencyY;
  final double phaseX;
  final double phaseY;
}

const List<_FluidPointPath> _fluidPointPaths = <_FluidPointPath>[
  _FluidPointPath(
    center: Offset(0.05, 0.08),
    radiusX: 0.22,
    radiusY: 0.18,
    frequencyX: 1,
    frequencyY: 2,
    phaseX: 0.2,
    phaseY: 1.1,
  ),
  _FluidPointPath(
    center: Offset(0.92, 0.06),
    radiusX: 0.18,
    radiusY: 0.21,
    frequencyX: 2,
    frequencyY: 1,
    phaseX: 1.7,
    phaseY: 0.4,
  ),
  _FluidPointPath(
    center: Offset(-0.03, 0.55),
    radiusX: 0.19,
    radiusY: 0.22,
    frequencyX: 1,
    frequencyY: 3,
    phaseX: 3.0,
    phaseY: 2.1,
  ),
  _FluidPointPath(
    center: Offset(0.54, 0.42),
    radiusX: 0.22,
    radiusY: 0.18,
    frequencyX: 3,
    frequencyY: 1,
    phaseX: 4.2,
    phaseY: 2.8,
  ),
  _FluidPointPath(
    center: Offset(1.02, 0.64),
    radiusX: 0.20,
    radiusY: 0.23,
    frequencyX: 2,
    frequencyY: 3,
    phaseX: 5.1,
    phaseY: 4.0,
  ),
  _FluidPointPath(
    center: Offset(0.48, 1.02),
    radiusX: 0.24,
    radiusY: 0.18,
    frequencyX: 1,
    frequencyY: 2,
    phaseX: 2.4,
    phaseY: 5.4,
  ),
];

@visibleForTesting
List<MeshGradientPoint> buildFluidMeshPointsForTest(
  List<Color> palette,
  double progress,
) {
  return _buildFluidMeshPoints(palette, progress);
}

List<MeshGradientPoint> _buildFluidMeshPoints(
  List<Color> palette,
  double progress,
) {
  assert(palette.isNotEmpty);
  final angle = progress * math.pi * 2;
  return List<MeshGradientPoint>.generate(_fluidPointPaths.length, (index) {
    final path = _fluidPointPaths[index];
    final position = Offset(
      path.center.dx +
          math.sin(angle * path.frequencyX + path.phaseX) * path.radiusX,
      path.center.dy +
          math.cos(angle * path.frequencyY + path.phaseY) * path.radiusY,
    );
    return MeshGradientPoint(
      position: position,
      color: palette[index % palette.length],
    );
  });
}

List<Color> _blendFluidPalettes(
  List<Color> from,
  List<Color> to,
  double value,
) {
  return List<Color>.generate(6, (index) {
    return Color.lerp(
          from[index % from.length],
          to[index % to.length],
          value,
        ) ??
        to[index % to.length];
  });
}
