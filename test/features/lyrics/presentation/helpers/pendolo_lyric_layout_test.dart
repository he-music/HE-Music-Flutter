import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/pendolo_lyric_layout.dart';

// Geometry and mechanical settling invariants across stage sizes.
void main() {
  test(
    'focal text begins inside each viewport and wrapped rows widen spacing',
    () {
      for (final size in [const Size(320, 500), const Size(700, 230)]) {
        final wheel = PendoloWheelGeometry(size);
        expect(wheel.point(0).dx, closeTo(28, 0.001));
        expect(wheel.point(0).dy, size.height / 2);
        expect(wheel.point(0).dx + wheel.textWidth, lessThan(size.width));
        expect(wheel.step(120, 80), greaterThan(wheel.step(30, 30)));
      }
    },
  );
  test('escapement overshoots then settles exactly', () {
    expect(pendoloEscapement(0), 0);
    expect(pendoloEscapement(0.25), greaterThan(1));
    expect(pendoloEscapement(1), 1);
  });
}
