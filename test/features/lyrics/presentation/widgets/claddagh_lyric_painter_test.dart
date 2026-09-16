import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/claddagh_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/claddagh_lyric_painter.dart';

// Regressions for continuous separator motion and actual composited row opacity.
CladdaghPaintRow makeRow(LyricLine line, {Color base = Colors.white}) {
  final tokens = buildCladdaghGlyphs(line);
  TextPainter glyph(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: 40, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return CladdaghPaintRow(
    entry: MonetVisibleLyricLine(
      line: line,
      index: 0,
      sourceIndex: 0,
      offset: 0,
      status: MonetLyricLineStatus.active,
      key: 'test',
    ),
    subtitle: null,
    tokens: tokens,
    glyphs: tokens.map((t) => glyph(t.text, base)).toList(),
    highlights: tokens.map((t) => glyph(t.text, Colors.white)).toList(),
    angles: List.generate(tokens.length, (i) => i * 0.2),
    glyphScale: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final timed in [false, true]) {
    test(
      'active line highlights with ${timed ? 'word mode off' : 'no timing'}',
      () async {
        final row = makeRow(
          LyricLine(
            start: Duration.zero,
            end: const Duration(seconds: 2),
            text: 'A',
            tokens: timed
                ? const [
                    LyricToken(
                      text: 'A',
                      startOffset: Duration.zero,
                      duration: Duration(seconds: 2),
                    ),
                  ]
                : const [],
          ),
          base: Colors.transparent,
        );
        final position = ValueNotifier(Duration.zero);
        final recorder = ui.PictureRecorder();
        CladdaghLyricPainter(
          rows: [row],
          anchor: 0,
          activeIndex: 0,
          geometry: CladdaghOrbitGeometry(const Size(320, 500)),
          angles: const [0],
          positionListenable: position,
          motion: const AlwaysStoppedAnimation(1),
          fromAngle: 0,
          documentOffset: 0,
          wordHighlight: !timed,
          color: Colors.transparent,
        ).paint(Canvas(recorder), const Size(320, 500));
        final picture = recorder.endRecording();
        final image = await picture.toImage(320, 500);
        final bytes = (await image.toByteData())!;
        expect(bytes.buffer.asUint8List().any((value) => value > 0), isTrue);
        image.dispose();
        picture.dispose();
        position.dispose();
        for (final painter in row.textPainters) {
          painter.dispose();
        }
      },
    );
  }
  for (final separator in [' ', '   ']) {
    test('orbit is continuous across zero-duration "$separator"', () {
      final row = makeRow(
        LyricLine(
          start: Duration.zero,
          end: const Duration(seconds: 2),
          text: 'A${separator}B',
          tokens: [
            const LyricToken(
              text: 'A',
              startOffset: Duration.zero,
              duration: Duration(seconds: 1),
            ),
            LyricToken(
              text: separator,
              startOffset: const Duration(seconds: 1),
              duration: Duration.zero,
            ),
            const LyricToken(
              text: 'B',
              startOffset: Duration(seconds: 1),
              duration: Duration(seconds: 1),
            ),
          ],
        ),
      );
      addTearDown(() {
        for (final p in row.textPainters) {
          p.dispose();
        }
      });
      final before = row.wordOffset(const Duration(microseconds: 999999));
      final boundary = row.wordOffset(const Duration(seconds: 1));
      final after = row.wordOffset(const Duration(microseconds: 1000001));
      expect(before, closeTo(boundary, 0.00001));
      expect(after, closeTo(boundary, 0.00001));
      expect(boundary, row.angles.last);
      expect(row.tokens[1].hasTiming, isFalse);
      expect(
        resolveMonetTokenProgress(
          timelinePosition: const Duration(milliseconds: 500),
          token: row.tokens.first,
        ),
        0.5,
      );
      expect(
        resolveMonetTokenProgress(
          timelinePosition: const Duration(milliseconds: 999),
          token: row.tokens.last,
        ),
        0,
      );
    });
  }
  for (final highlighted in [false, true]) {
    test(
      'paint fades ${highlighted ? 'highlight' : 'base'} at distance two',
      () async {
        final row = makeRow(
          const LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'A',
            tokens: [
              LyricToken(
                text: 'A',
                startOffset: Duration.zero,
                duration: Duration(seconds: 1),
              ),
            ],
          ),
          base: highlighted ? Colors.transparent : Colors.white,
        );
        final position = ValueNotifier(const Duration(seconds: 1));
        addTearDown(() {
          position.dispose();
          for (final p in row.textPainters) {
            p.dispose();
          }
        });
        Future<int> alpha(double distance) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final painter = CladdaghLyricPainter(
            rows: [row],
            anchor: 0,
            activeIndex: 0,
            geometry: CladdaghOrbitGeometry(const Size(320, 500)),
            angles: const [0],
            positionListenable: position,
            motion: const AlwaysStoppedAnimation(0),
            fromAngle: distance * math.pi,
            documentOffset: 0,
            wordHighlight: highlighted,
            color: Colors.transparent,
          );
          painter.paint(canvas, const Size(320, 500));
          final picture = recorder.endRecording();
          final image = await picture.toImage(320, 500);
          final data = (await image.toByteData())!;
          var sum = 0;
          for (var i = 3; i < data.lengthInBytes; i += 4) {
            sum += data.getUint8(i);
          }
          image.dispose();
          picture.dispose();
          return sum;
        }

        final background = await alpha(2);
        final visible = await alpha(1) - background;
        final fading = await alpha(1.99) - background;
        final edge = await alpha(1.9999) - background;
        expect(visible, greaterThan(0));
        expect(fading, greaterThan(0));
        expect(fading, lessThan(visible * 0.03));
        expect(edge, lessThanOrEqualTo(fading));
        expect(edge, 0);
      },
    );
  }
}
