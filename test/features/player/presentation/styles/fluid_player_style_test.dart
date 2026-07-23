import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/styles/fluid_player_backdrop.dart';

void main() {
  test('fluid palette preserves a muted cover mood', () {
    const candidates = <Color>[
      Color(0xFFB39AC7),
      Color(0xFF8F7FA6),
      Color(0xFF6E678B),
    ];

    final colors = resolveFluidPaletteForTest(candidates);

    expect(colors, hasLength(6));
    expect(
      _averageSaturation(colors),
      closeTo(_averageSaturation(candidates), 0.02),
    );
    expect(
      HSLColor.fromColor(colors.first).hue,
      closeTo(HSLColor.fromColor(candidates.first).hue, 0.01),
    );
  });

  test('fluid palette derives six same-hue tones from one seed', () {
    const seed = Color(0xFF416F9D);

    final colors = resolveFluidPaletteForTest(const <Color>[seed]);

    expect(colors, hasLength(6));
    final seedHue = HSLColor.fromColor(seed).hue;
    for (final color in colors) {
      expect(HSLColor.fromColor(color).hue, closeTo(seedHue, 0.5));
    }
  });

  test('fluid palette removes colors duplicated by lightness bounds', () {
    final colors = resolveFluidPaletteForTest(const <Color>[
      Color(0xFF030405),
      Color(0xFF06080A),
    ]);

    expect(colors, hasLength(6));
    expect(colors.toSet(), hasLength(6));
  });

  test('fluid fallback palette is stable and complete', () {
    final first = fallbackFluidPaletteForTest();
    final second = fallbackFluidPaletteForTest();

    expect(first, hasLength(6));
    expect(second, first);
  });

  test('six fluid mesh points move on independent paths', () {
    final palette = fallbackFluidPaletteForTest();
    final initial = buildFluidMeshPointsForTest(palette, 0);
    final later = buildFluidMeshPointsForTest(palette, 0.21);

    expect(initial, hasLength(6));
    expect(later, hasLength(6));

    final offsets = List<Offset>.generate(
      initial.length,
      (index) => later[index].position - initial[index].position,
    );
    expect(offsets.where((offset) => offset.distance > 0.01), hasLength(6));
    expect(offsets.toSet().length, greaterThanOrEqualTo(4));
  });
}

double _averageSaturation(List<Color> colors) {
  return colors
          .map((color) => HSLColor.fromColor(color).saturation)
          .reduce((left, right) => left + right) /
      colors.length;
}
