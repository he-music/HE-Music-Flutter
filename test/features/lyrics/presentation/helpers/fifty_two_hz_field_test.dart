import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/fifty_two_hz_field.dart';

void main() {
  test(
    'distance texture stores Euclidean distance with independent axis scales',
    () {
      const width = 8;
      const height = 7;
      const reach = 10.0;
      const dx = 1.5;
      const dy = 2.0;
      const ink = [(0, 1), (4, 3), (5, 3), (7, 6)];
      final mask = Uint8List(width * height * 4);
      for (final (x, y) in ink) {
        mask[(y * width + x) * 4 + 3] = 255;
      }
      final field = encodeFiftyTwoHzDistances((
        rgba: mask,
        width: width,
        height: height,
        dx: dx,
        dy: dy,
        reach: reach,
        glyphGap: 0,
      ))!;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final offset = (y * width + x) * 4;
          final actual =
              (field[offset] * 256 + field[offset + 1]) * reach / 65535;
          var expected = reach;
          for (final (inkX, inkY) in ink) {
            final horizontal = (x - inkX) * dx;
            final vertical = (y - inkY) * dy;
            expected = math.min(
              expected,
              math.sqrt(horizontal * horizontal + vertical * vertical),
            );
          }
          expect(
            actual,
            closeTo(expected, reach / 65535),
            reason: 'pixel ($x, $y)',
          );
        }
      }
    },
  );

  test('the gap between glyphs and the margin around them stay clear', () {
    const width = 21;
    const height = 13;
    const reach = 10.0;
    final mask = Uint8List(width * height * 4);
    for (var y = 5; y <= 7; y++) {
      mask[(y * width + 3) * 4 + 3] = 255;
      mask[(y * width + 17) * 4 + 3] = 255;
    }
    final field = encodeFiftyTwoHzDistances((
      rgba: mask,
      width: width,
      height: height,
      dx: 1.0,
      dy: 1.0,
      reach: reach,
      glyphGap: 3.0,
    ))!;
    double distance(int x, int y) {
      final offset = (y * width + x) * 4;
      return (field[offset] * 256 + field[offset + 1]) * reach / 65535;
    }

    expect(distance(10, 6), 0);
    expect(distance(10, 3), 0);
    expect(distance(1, 6), 0);
    expect(distance(10, 1), closeTo(1, reach / 65535));
  });
  test('fixed cadence reconstructs radii and expires an outgoing lyric', () {
    const start = Duration(seconds: 2);
    const nextLine = Duration(seconds: 3);
    const reach = 180.0;
    expect(
      fiftyTwoHzRadii(position: Duration.zero, start: start, reach: reach),
      isNull,
    );
    const position = Duration(milliseconds: 2900);
    final radii = fiftyTwoHzRadii(
      position: position,
      start: start,
      reach: reach,
    )!;
    expect(radii.newest, closeTo(1, .001));
    expect(radii.oldest, closeTo(37, .001));
    expect(
      fiftyTwoHzRadii(position: position, start: start, reach: reach),
      radii,
    );
    final outgoing = fiftyTwoHzRadii(
      position: const Duration(seconds: 4),
      start: start,
      stop: nextLine,
      reach: reach,
    )!;
    expect(outgoing.newest, closeTo(56, .001));
    expect(
      fiftyTwoHzRadii(
        position: const Duration(milliseconds: 6480),
        start: start,
        stop: nextLine,
        reach: reach,
      ),
      isNull,
    );
  });
}
