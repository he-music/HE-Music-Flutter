import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/single_line_lyric.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('word timing without a line end remains usable', () {
    const line = LyricLine(
      start: Duration(seconds: 3),
      text: 'ab',
      tokens: [
        LyricToken(
          text: 'a',
          startOffset: Duration.zero,
          duration: Duration(seconds: 1),
        ),
        LyricToken(
          text: 'b',
          startOffset: Duration(seconds: 1),
          duration: Duration(seconds: 1),
        ),
      ],
    );
    final tokens = buildSingleLineLyricTokens(line, null);
    expect(tokens.every((token) => token.hasTiming), isTrue);
    expect(tokens.last.end, const Duration(seconds: 5));
    expect(
      buildSingleLineLyricTokens(
        line,
        const Duration(seconds: 4),
      ).single.hasTiming,
      isFalse,
    );
  });

  test(
    'word sweep paints increasing highlight while keeping unsung text white',
    () async {
      final fixture = _Fixture(text: 'abcdefgh', words: true);
      addTearDown(fixture.dispose);
      final before = await _colors(fixture.painter);
      expect(before.red, 0);
      expect(before.white, greaterThan(0));
      fixture.clock.value = const Duration(milliseconds: 4000);
      final halfway = await _colors(fixture.painter);
      expect(halfway.red, greaterThan(0));
      expect(halfway.white, greaterThan(0));
      fixture.clock.value = const Duration(seconds: 8);
      final after = await _colors(fixture.painter);
      expect(after.red, greaterThan(halfway.red));
      expect(after.white, 0);
      fixture.clock.value = Duration.zero;
      expect((await _colors(fixture.painter)).red, 0);
    },
  );

  test('untimed text stays white as playback advances', () async {
    final fixture = _Fixture(text: 'abcdefgh', words: false);
    addTearDown(fixture.dispose);
    fixture.clock.value = const Duration(seconds: 4);
    final colors = await _colors(fixture.painter);
    expect(colors.red, 0);
    expect(colors.white, greaterThan(0));
  });

  for (final direction in TextDirection.values) {
    test('long timed line follows current words and seeks in $direction', () {
      final fixture = _Fixture(
        text: direction == TextDirection.ltr
            ? 'abcdefghijklmnopqrstuvwxyz'
            : 'ابتثجحخدذرزسشصضطظعغفقكلمنهو',
        words: true,
        direction: direction,
      );
      addTearDown(fixture.dispose);
      const width = 100.0;
      final initial = fixture.painter.scrollOffset(width);
      fixture.clock.value = const Duration(seconds: 12);
      final middle = fixture.painter.scrollOffset(width);
      final boxes = fixture.painter.base.getBoxesForSelection(
        const TextSelection(baseOffset: 12, extentOffset: 13),
      );
      expect(boxes.first.left - middle, greaterThanOrEqualTo(-1));
      expect(boxes.first.right - middle, lessThanOrEqualTo(width + 1));
      fixture.clock.value = Duration(seconds: fixture.text.length);
      final end = fixture.painter.scrollOffset(width);
      expect(end, inInclusiveRange(0, fixture.painter.base.width - width));
      if (direction == TextDirection.ltr) {
        expect(middle, greaterThan(initial));
        expect(end, closeTo(fixture.painter.base.width - width, 0.01));
      } else {
        expect(middle, lessThan(initial));
        expect(end, 0);
      }
      fixture.clock.value = Duration.zero;
      expect(fixture.painter.scrollOffset(width), initial);
    });
  }

  test(
    'plain long line waits, scrolls once, holds at the end and resets on seek',
    () {
      final fixture = _Fixture(
        text: 'abcdefghijklmnopqrstuvwxyz',
        words: false,
      );
      addTearDown(fixture.dispose);
      const width = 100.0;
      fixture.clock.value = const Duration(milliseconds: 700);
      expect(fixture.painter.scrollOffset(width), 0);
      fixture.clock.value = const Duration(seconds: 4);
      final middle = fixture.painter.scrollOffset(width);
      expect(middle, greaterThan(0));
      expect(fixture.painter.scrollOffset(width), middle);
      fixture.clock.value = const Duration(minutes: 1);
      final end = fixture.painter.scrollOffset(width);
      expect(end, fixture.painter.base.width - width);
      fixture.clock.value = const Duration(minutes: 2);
      expect(fixture.painter.scrollOffset(width), end);
      fixture.clock.value = Duration.zero;
      expect(fixture.painter.scrollOffset(width), 0);
    },
  );

  test(
    'short lines stay still and reduced motion advances only at word boundaries',
    () {
      final short = _Fixture(text: 'abc', words: true);
      final reduced = _Fixture(
        text: 'abcdefghijklmnopqrstuvwxyz',
        words: true,
        reduced: true,
      );
      final plain = _Fixture(
        text: 'abcdefghijklmnopqrstuvwxyz',
        words: false,
        reduced: true,
      );
      addTearDown(short.dispose);
      addTearDown(reduced.dispose);
      addTearDown(plain.dispose);
      short.clock.value = const Duration(seconds: 2);
      expect(short.painter.scrollOffset(300), 0);
      reduced.clock.value = const Duration(milliseconds: 10000);
      final atWord = reduced.painter.scrollOffset(100);
      expect(atWord, greaterThan(0));
      reduced.clock.value = const Duration(milliseconds: 10999);
      expect(reduced.painter.scrollOffset(100), atWord);
      plain.clock.value = const Duration(minutes: 1);
      expect(plain.painter.scrollOffset(100), 0);
    },
  );
}

class _Fixture {
  _Fixture({
    required this.text,
    required bool words,
    TextDirection direction = TextDirection.ltr,
    bool reduced = false,
  }) {
    final line = LyricLine(
      start: Duration.zero,
      end: Duration(seconds: text.length),
      text: text,
      tokens: words
          ? [
              for (var i = 0; i < text.length; i++)
                LyricToken(
                  text: text[i],
                  startOffset: Duration(seconds: i),
                  duration: const Duration(seconds: 1),
                ),
            ]
          : const [],
    );
    TextPainter paragraph(Color color) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 20),
      ),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    painter = SingleLineLyricPainter(
      base: paragraph(Colors.white),
      highlight: words ? paragraph(const Color(0xFFFF0000)) : null,
      tokens: buildSingleLineLyricTokens(line, null),
      position: clock,
      lineStart: Duration.zero,
      documentOffset: 0,
      reduceMotion: reduced,
    );
  }

  final String text;
  final clock = ValueNotifier(Duration.zero);
  late final SingleLineLyricPainter painter;

  void dispose() {
    clock.dispose();
    painter.base.dispose();
    painter.highlight?.dispose();
  }
}

Future<({int red, int white})> _colors(SingleLineLyricPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(300, 40));
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 40);
  final bytes = (await image.toByteData())!;
  var red = 0;
  var white = 0;
  for (var i = 0; i < bytes.lengthInBytes; i += 4) {
    if (bytes.getUint8(i + 3) < 100) continue;
    if (bytes.getUint8(i) > 200 && bytes.getUint8(i + 1) < 50) red++;
    if (bytes.getUint8(i) > 200 && bytes.getUint8(i + 1) > 200) white++;
  }
  image.dispose();
  picture.dispose();
  return (red: red, white: white);
}
