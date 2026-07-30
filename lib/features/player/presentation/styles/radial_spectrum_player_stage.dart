import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_spectrum_frame.dart';
import '../../domain/entities/player_track.dart';
import '../controllers/realtime_spectrum_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../../../../shared/image/image_color_extractor.dart';

const List<Color> radialSpectrumFallbackPalette = <Color>[
  Color(0xFF82DDCA),
  Color(0xFFFFC86B),
  Color(0xFFE991AA),
];

@immutable
class RadialSpectrumBarGeometry {
  const RadialSpectrumBarGeometry({
    required this.start,
    required this.end,
    required this.palettePosition,
  });

  final Offset start;
  final Offset end;
  final double palettePosition;
}

List<RadialSpectrumBarGeometry> resolveRadialSpectrumBarsForTest({
  required Size size,
  required List<double> bands,
}) {
  assert(bands.length == AudioSpectrumFrame.bandCount);
  final shortestSide = size.shortestSide;
  final center = size.center(Offset.zero);
  final coverRadius = shortestSide * 0.32;
  final startRadius = coverRadius + 8;
  final maxHeight = coverRadius * 0.24;
  return List<RadialSpectrumBarGeometry>.generate(
    AudioSpectrumFrame.bandCount,
    (index) {
      final angle = math.pi / 2 + math.pi * 2 * index / bands.length;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * startRadius;
      return RadialSpectrumBarGeometry(
        start: start,
        end: start + direction * (maxHeight * bands[index]),
        palettePosition: index / bands.length,
      );
    },
    growable: false,
  );
}

List<Color> resolveRadialSpectrumPaletteForTest(List<Color> source) {
  final selected = <HSLColor>[];
  for (final color in source) {
    final candidate = HSLColor.fromColor(color);
    final differs = selected.every(
      (existing) => _hueDistance(existing.hue, candidate.hue) >= 24,
    );
    if (differs || selected.isEmpty) {
      selected.add(candidate);
    }
    if (selected.length == 3) {
      break;
    }
  }
  if (selected.isEmpty) {
    return radialSpectrumFallbackPalette;
  }
  if (selected.length == 1) {
    final base = selected.single;
    selected
      ..add(base.withHue((base.hue + 34) % 360))
      ..add(base.withHue((base.hue + 326) % 360));
  } else if (selected.length == 2) {
    selected.add(
      selected.first.withHue(
        (selected.first.hue +
                _signedHueDelta(selected.first.hue, selected.last.hue) / 2) %
            360,
      ),
    );
  }
  return List<Color>.unmodifiable(
    selected
        .take(3)
        .map(
          (color) => color
              .withSaturation(color.saturation.clamp(0.50, 0.76))
              .withLightness(color.lightness.clamp(0.57, 0.72))
              .toColor(),
        ),
  );
}

class RadialSpectrumPlayerStage extends ConsumerStatefulWidget {
  const RadialSpectrumPlayerStage({required this.track, super.key});

  final PlayerTrack? track;

  @override
  ConsumerState<RadialSpectrumPlayerStage> createState() =>
      _RadialSpectrumPlayerStageState();
}

class _RadialSpectrumPlayerStageState
    extends ConsumerState<RadialSpectrumPlayerStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _paletteController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );
  List<Color> _fromPalette = radialSpectrumFallbackPalette;
  List<Color> _toPalette = radialSpectrumFallbackPalette;
  int _paletteGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPalette());
  }

  @override
  void didUpdateWidget(covariant RadialSpectrumPlayerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldImageProvider = artworkProvider(
      oldWidget.track?.artworkUrl,
      oldWidget.track?.artworkBytes,
    );
    final newImageProvider = artworkProvider(
      widget.track?.artworkUrl,
      widget.track?.artworkBytes,
    );
    if (_trackKey(oldWidget.track) != _trackKey(widget.track) ||
        oldImageProvider != newImageProvider) {
      unawaited(_loadPalette());
    }
  }

  @override
  void dispose() {
    _paletteGeneration += 1;
    _paletteController.dispose();
    super.dispose();
  }

  Future<void> _loadPalette() async {
    final generation = ++_paletteGeneration;
    final imageProvider = artworkProvider(
      widget.track?.artworkUrl,
      widget.track?.artworkBytes,
    );
    final colors = await colorsFromImageProvider(imageProvider, maxColors: 8);
    if (!mounted || generation != _paletteGeneration) {
      return;
    }
    final current = _interpolatedPalette(_paletteController.value);
    setState(() {
      _fromPalette = current;
      _toPalette = resolveRadialSpectrumPaletteForTest(colors);
    });
    unawaited(_paletteController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final bands = ref.watch(
      realtimeSpectrumControllerProvider.select((state) => state.bands),
    );
    final imageProvider = artworkProvider(
      widget.track?.artworkUrl,
      widget.track?.artworkBytes,
    );
    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey<String>('radial-spectrum-player-stage'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            final coverSize = side * 0.64;
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _paletteController,
                    builder: (context, child) {
                      return CustomPaint(
                        key: const ValueKey<String>('radial-spectrum-painter'),
                        painter: RadialSpectrumPainter(
                          bands: bands,
                          palette: _interpolatedPalette(
                            _paletteController.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox.square(
                  key: const ValueKey<String>('radial-spectrum-cover'),
                  dimension: coverSize,
                  child: ClipOval(
                    child: imageProvider == null
                        ? const ColoredBox(
                            color: Color(0xFF292E2D),
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 72,
                              color: Color(0xFFDDE4E2),
                            ),
                          )
                        : Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: Color(0xFF292E2D),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 72,
                                  color: Color(0xFFDDE4E2),
                                ),
                              );
                            },
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

  List<Color> _interpolatedPalette(double value) {
    return List<Color>.generate(3, (index) {
      return Color.lerp(_fromPalette[index], _toPalette[index], value)!;
    }, growable: false);
  }

  String _trackKey(PlayerTrack? track) {
    if (track == null) return '';
    return '${track.platform ?? ''}|${track.id}';
  }
}

class RadialSpectrumPainter extends CustomPainter {
  const RadialSpectrumPainter({required this.bands, required this.palette});

  final List<double> bands;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = resolveRadialSpectrumBarsForTest(size: size, bands: bands);
    final strokeWidth = math.max(2.5, size.shortestSide * 0.011);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    for (final bar in bars) {
      if ((bar.end - bar.start).distance <= 0.001) {
        continue;
      }
      paint.color = _paletteColorAt(palette, bar.palettePosition);
      canvas.drawLine(bar.start, bar.end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadialSpectrumPainter oldDelegate) {
    return !listEquals(oldDelegate.bands, bands) ||
        !listEquals(oldDelegate.palette, palette);
  }
}

Color _paletteColorAt(List<Color> palette, double position) {
  final scaled = position * palette.length;
  final current = scaled.floor() % palette.length;
  final next = (current + 1) % palette.length;
  return Color.lerp(palette[current], palette[next], scaled - scaled.floor())!;
}

double _hueDistance(double first, double second) {
  return _signedHueDelta(first, second).abs();
}

double _signedHueDelta(double first, double second) {
  return (second - first + 540) % 360 - 180;
}
