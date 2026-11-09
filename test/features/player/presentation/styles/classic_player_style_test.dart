import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/player/presentation/styles/classic_player_stage.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_backdrop.dart';

void main() {
  test('classic palette limits saturation and brightness', () {
    final colors = resolveClassicGradientColorsForTest(const <Color>[
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFFFF),
    ]);

    expect(colors, hasLength(4));
    for (final color in colors) {
      final hsl = HSLColor.fromColor(color);
      expect(hsl.saturation, lessThanOrEqualTo(0.421));
      expect(hsl.lightness, inInclusiveRange(0.099, 0.481));
    }
  });

  test('classic scene palette keeps artwork color and readable contrast', () {
    final palette = classicPlayerScenePaletteFromBackdrop(const <Color>[
      Color(0xFF3B6F62),
      Color(0xFFC99B55),
      Color(0xFF244A42),
      Color(0xFF102822),
    ]);

    expect(palette, isNot(classicPlayerScenePaletteFallback));
    expect(palette.foreground.computeLuminance(), greaterThan(0.72));
    expect(palette.surfaceDeep.computeLuminance(), lessThan(0.12));
    expect(HSLColor.fromColor(palette.accent).hue, inInclusiveRange(25, 55));
  });

  for (final source in const <Color>[
    Color(0xFF526DA8),
    Color(0xFF8B629F),
    Color(0xFFAD7850),
    Color(0xFF777777),
  ]) {
    test('classic surfaces preserve artwork hue for $source', () {
      final palette = classicPlayerScenePaletteFromBackdrop([source]);
      final original = HSLColor.fromColor(source);
      for (final surface in [
        palette.surface,
        palette.surfaceDeep,
        palette.surfaceRaised,
      ]) {
        final actual = HSLColor.fromColor(surface);
        if (original.saturation < 0.01) {
          expect(actual.saturation, lessThan(0.01));
        } else {
          expect(actual.hue, closeTo(original.hue, 2));
        }
      }
      double contrast(Color foreground) =>
          (foreground.computeLuminance() + 0.05) /
          (palette.surface.computeLuminance() + 0.05);
      expect(contrast(palette.foreground), greaterThanOrEqualTo(7));
      expect(contrast(palette.secondaryForeground), greaterThanOrEqualTo(4.5));
    });
  }

  test('neutral artwork stays neutral in the backdrop palette', () {
    final colors = resolveClassicGradientColorsForTest(const [
      Color(0xFF888888),
      Color(0xFF444444),
      Color(0xFFCCCCCC),
    ]);
    for (final color in colors) {
      expect(HSLColor.fromColor(color).saturation, lessThan(0.01));
    }
  });
  test('classic scene palette has a stable artwork-free fallback', () {
    expect(
      classicPlayerScenePaletteFromBackdrop(const <Color>[]),
      classicPlayerScenePaletteFallback,
    );
  });

  testWidgets('classic stage renders a layered album sleeve', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            classicPlayerScenePaletteFallback,
          ],
        ),
        home: const SizedBox.square(
          dimension: 360,
          child: ClassicPlayerStage(track: null),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('classic-player-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('classic-album-sleeve')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('classic-album-cover')),
      findsOneWidget,
    );
    expect(
      PlayerScenePalette.maybeOf(
        tester.element(
          find.byKey(const ValueKey<String>('classic-player-stage')),
        ),
      ),
      classicPlayerScenePaletteFallback,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide artwork keeps both edges visible inside the sleeve', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final artwork = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final (index, color) in [
        Colors.red,
        Colors.green,
        Colors.blue,
      ].indexed) {
        canvas.drawRect(
          Rect.fromLTWH(index * 100, 0, 100, 100),
          Paint()..color = color,
        );
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(300, 100);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
    const capture = ValueKey('wide-artwork-capture');
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: capture,
          child: ClassicPlayerStage(
            track: PlayerTrack(
              id: 'wide',
              title: 'Wide',
              artworkBytes: artwork,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(artwork!),
        tester.element(find.byType(ClassicPlayerStage)),
      ),
    );
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final left = 4 * (180 * 360 + 30);
        final right = 4 * (180 * 360 + 330);
        expect(pixels!.getUint8(left), greaterThan(200));
        expect(pixels.getUint8(left + 2), lessThan(100));
        expect(pixels.getUint8(right), lessThan(100));
        expect(pixels.getUint8(right + 2), greaterThan(200));
      } finally {
        image.dispose();
      }
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'classic backdrop never paints the cover as a full-screen image',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlayerBackdrop(
            backdropKind: AppPlayerBackdropKind.coverGradient,
            imageProvider: null,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const ValueKey<String>('player-backdrop-cover-gradient')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    },
  );
}
