import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/tilt_lyric_layout.dart';
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

  test(
    'intermediate cached paint matches direct Color.lerp rendering',
    () async {
      const bodyColor = Color(0xb8f5f0e8);
      const activeColor = Color(0xff80cbc4);
      const baseStyle = TextStyle(fontSize: 40, fontWeight: FontWeight.w700);
      final bodyPainter = _textPainter(
        'M',
        baseStyle.copyWith(color: bodyColor),
      );
      final activePainter = _textPainter(
        'M',
        baseStyle.copyWith(color: activeColor),
      );
      final glyphBounds = Offset.zero & bodyPainter.size;
      final graphemeLayout = TiltGraphemePlacement(
        text: 'M',
        startOffset: 0,
        endOffset: 1,
        localBounds: glyphBounds,
        bounds: glyphBounds.shift(const Offset(20, 20)),
        staggerSign: 0,
        start: Duration.zero,
        end: const Duration(seconds: 1),
      );
      final segmentLayout = TiltLyricSegmentLayout(
        text: 'M',
        startOffset: 0,
        endOffset: 1,
        isTilt: true,
        isShortLast: false,
        origin: const Offset(20, 20),
        size: bodyPainter.size,
        paintScale: 1,
        revealAt: Duration.zero,
        hitRect: glyphBounds.shift(const Offset(20, 20)),
        graphemes: <TiltGraphemePlacement>[graphemeLayout],
      );
      final lineLayout = TiltLyricLineLayout(
        sourceLine: const LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'M',
        ),
        sourceLineIndex: 0,
        segments: <TiltLyricSegmentLayout>[segmentLayout],
        hasFineTiming: true,
        auxiliaryText: null,
        cacheKey: 'paint-test',
        stageBounds: const Rect.fromLTWH(0, 0, 100, 100),
      );
      final renderData = TiltLyricRenderData(
        layout: lineLayout,
        segments: <TiltSegmentPaintData>[
          TiltSegmentPaintData(
            layout: segmentLayout,
            graphemes: <TiltGraphemePaintData>[
              TiltGraphemePaintData(
                layout: graphemeLayout,
                bodyPainter: bodyPainter,
                activePainter: activePainter,
                bodyColor: bodyColor,
                activeColor: activeColor,
              ),
            ],
          ),
        ],
        scaleCenterY: bodyPainter.height / 2,
      );
      for (final position in const <Duration>[
        Duration.zero,
        Duration(milliseconds: 500),
        Duration(seconds: 1),
      ]) {
        final actual = await _rasterize((canvas) {
          TiltLyricPainter(
            data: renderData,
            timelinePosition: position,
            revealAnimation: false,
          ).paint(canvas, const Size(100, 100));
        });

        final rawProgress =
            position.inMicroseconds / const Duration(seconds: 1).inMicroseconds;
        final easedProgress = Curves.easeOutCubic.transform(rawProgress);
        final expectedPainter = _textPainter(
          'M',
          baseStyle.copyWith(
            color: Color.lerp(bodyColor, activeColor, easedProgress),
          ),
        );
        final expected = await _rasterize((canvas) {
          final center = Offset(bodyPainter.width / 2, bodyPainter.height / 2);
          canvas.save();
          canvas.translate(20, 20);
          canvas.translate(center.dx, center.dy);
          canvas.scale(
            resolveTiltGraphemeScale(
              position,
              Duration.zero,
              const Duration(seconds: 1),
            ),
          );
          canvas.translate(-center.dx, -center.dy);
          expectedPainter.paint(canvas, Offset.zero);
          canvas.restore();
        });

        var maxChannelDelta = 0;
        for (var index = 0; index < actual.length; index += 1) {
          maxChannelDelta = math.max(
            maxChannelDelta,
            (actual[index] - expected[index]).abs(),
          );
        }
        expect(actual.any((channel) => channel != 0), isTrue);
        expect(
          maxChannelDelta,
          lessThanOrEqualTo(1),
          reason: 'position: $position',
        );
      }
    },
  );
}

TextPainter _textPainter(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
}

Future<Uint8List> _rasterize(void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(100, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
