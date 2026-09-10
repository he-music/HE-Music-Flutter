import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/lyric_position_smoother.dart';

void main() {
  testWidgets(
    'samples interpolate without extrapolation or permanent ticking',
    (tester) async {
      final smoother = LyricPositionSmoother(
        vsync: tester,
        position: Duration.zero,
      );
      smoother.update(const Duration(milliseconds: 33));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(smoother.value.inMilliseconds, inExclusiveRange(0, 33));
      await tester.pump(const Duration(milliseconds: 20));
      expect(smoother.value, const Duration(milliseconds: 33));
      await tester.pump(const Duration(seconds: 2));
      expect(smoother.value, const Duration(milliseconds: 33));
      expect(tester.binding.transientCallbackCount, 0);
      smoother.dispose();
    },
  );

  testWidgets('seek, backwards samples, line boundaries and large jumps snap', (
    tester,
  ) async {
    final smoother = LyricPositionSmoother(
      vsync: tester,
      position: const Duration(seconds: 1),
    );
    smoother.update(const Duration(milliseconds: 1033));
    await tester.pump();
    smoother.seek();
    smoother.update(const Duration(milliseconds: 1060));
    expect(smoother.value, const Duration(milliseconds: 1060));
    smoother.update(const Duration(milliseconds: 1050));
    expect(smoother.value, const Duration(milliseconds: 1050));
    smoother.update(const Duration(seconds: 3));
    expect(smoother.value, const Duration(seconds: 3));
    smoother.update(const Duration(milliseconds: 3033), discontinuity: true);
    expect(smoother.value, const Duration(milliseconds: 3033));
    smoother.dispose();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('disabling snaps pending sample and resumes only on new input', (
    tester,
  ) async {
    final smoother = LyricPositionSmoother(
      vsync: tester,
      position: Duration.zero,
    );
    smoother.update(const Duration(milliseconds: 33));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    smoother.enabled = false;
    expect(smoother.value, const Duration(milliseconds: 33));
    smoother.update(const Duration(milliseconds: 66));
    expect(smoother.value, const Duration(milliseconds: 66));
    smoother.enabled = true;
    await tester.pump(const Duration(seconds: 1));
    expect(smoother.value, const Duration(milliseconds: 66));
    smoother.update(const Duration(milliseconds: 99));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(smoother.value.inMilliseconds, inExclusiveRange(66, 99));
    smoother.dispose();
  });
}
