import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_painter.dart';

void main() {
  testWidgets(
    'Monet reuses identical text resources with pixel-identical output and invalidates width locale style',
    (tester) async {
      const document = LyricDocument(
        lines: [
          LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 2),
            text: 'sing',
            translation: 'translation',
          ),
          LyricLine(start: Duration(seconds: 2), text: 'along'),
        ],
      );
      final engine = MonetLyricLayoutEngine(document);
      final entries = engine.buildVisibleWindow(
        position: engine.resolvePosition(const Duration(seconds: 1)),
      );
      MonetLyricRenderData build({
        MonetLyricRenderData? previous,
        double width = 430,
        double font = 36,
        Locale? locale,
        double anchor = 0.46,
      }) {
        final options = MonetLyricLayoutOptions(
          railSize: Size(width, 620),
          activeTextStyle: TextStyle(fontSize: font),
          inactiveTextStyle: const TextStyle(fontSize: 24),
          translationTextStyle: const TextStyle(fontSize: 16),
          locale: locale,
          anchorAlignment: anchor,
        );
        final lines = layoutMonetLyricWindow(
          engine: engine,
          entries: entries,
          options: options,
        );
        return buildMonetLyricRenderData(
          positionedLines: lines,
          options: options,
          palette: classicPlayerScenePaletteFallback,
          enableWordByWordLyric: true,
          timelineOffset: Duration.zero,
          reusableData: previous,
        );
      }

      final first = build();
      final shifted = build(previous: first, anchor: 0.6);
      final fresh = build(anchor: 0.6);
      expect(
        shifted.lines.first.mainPainter,
        same(first.lines.first.mainPainter),
      );
      expect(
        shifted.lines.first.translationPainter,
        same(first.lines.first.translationPainter),
      );
      expect(
        await tester.runAsync(() => _pixels(shifted)),
        await tester.runAsync(() => _pixels(fresh)),
      );
      final resized = build(previous: first, width: 300);
      final styled = build(previous: first, font: 40);
      final localized = build(previous: first, locale: const Locale('ja'));
      expect(
        resized.lines.first.mainPainter,
        isNot(same(first.lines.first.mainPainter)),
      );
      expect(
        styled.lines.first.mainPainter,
        isNot(same(first.lines.first.mainPainter)),
      );
      expect(
        localized.lines.first.mainPainter,
        isNot(same(first.lines.first.mainPainter)),
      );
      final painters = Set<TextPainter>.identity();
      for (final data in [first, shifted, fresh, resized, styled, localized]) {
        painters.addAll(data.textPainters);
      }
      for (final painter in painters) {
        painter.dispose();
      }
    },
  );
}

Future<List<int>> _pixels(MonetLyricRenderData data) async {
  final recorder = ui.PictureRecorder();
  final position = ValueNotifier(const Duration(seconds: 1));
  MonetLyricPainter(
    data: data,
    previousData: null,
    position: position,
    transition: const AlwaysStoppedAnimation(1),
  ).paint(Canvas(recorder), data.size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    data.size.width.toInt(),
    data.size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  position.dispose();
  return result;
}
