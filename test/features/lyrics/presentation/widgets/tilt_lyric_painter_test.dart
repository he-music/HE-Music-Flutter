import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/tilt_lyric_painter.dart';

void main() {
  test('entry reveal progresses over the bounded 250ms window', () {
    const revealAt = Duration(seconds: 1);

    expect(resolveTiltEntryProgress(const Duration(seconds: 1), revealAt), 0);
    expect(
      resolveTiltEntryProgress(const Duration(milliseconds: 1125), revealAt),
      closeTo(0.5, 0.001),
    );
    expect(resolveTiltEntryProgress(const Duration(seconds: 2), revealAt), 1);
  });

  test('grapheme pulse clamps before and after valid timing', () {
    const start = Duration(seconds: 2);
    const end = Duration(seconds: 3);

    expect(
      resolveTiltGraphemeProgress(const Duration(seconds: 1), start, end),
      0,
    );
    expect(
      resolveTiltGraphemeProgress(
        const Duration(milliseconds: 2500),
        start,
        end,
      ),
      0.5,
    );
    expect(
      resolveTiltGraphemeProgress(const Duration(seconds: 4), start, end),
      1,
    );
    expect(resolveTiltGraphemeProgress(start, end, start), 0);

    expect(
      resolveTiltGraphemeScale(const Duration(milliseconds: 2500), start, end),
      closeTo(1.3, 0.001),
    );
  });
}
