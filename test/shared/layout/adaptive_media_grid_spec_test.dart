import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/layout/adaptive_media_grid_spec.dart';

void main() {
  test('keeps at least two columns on compact widths', () {
    final spec = resolveAdaptiveMediaGridSpec(maxWidth: 320);

    expect(spec.crossAxisCount, 2);
    expect(spec.itemWidth, greaterThan(0));
  });

  test('promotes to three columns on medium widths', () {
    final spec = resolveAdaptiveMediaGridSpec(maxWidth: 560);
    const expectedItemWidth = (560 - 8 * 2) / 3;

    expect(spec.crossAxisCount, 3);
    expect(spec.itemWidth, closeTo(expectedItemWidth, 0.01));
  });

  test('continues to add columns on wide desktop widths', () {
    final spec = resolveAdaptiveMediaGridSpec(maxWidth: 980);

    expect(spec.crossAxisCount, greaterThanOrEqualTo(5));
    expect(spec.itemWidth, greaterThanOrEqualTo(160));
  });
}
