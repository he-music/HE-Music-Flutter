import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/player/presentation/styles/classic_player_stage.dart';
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

  testWidgets(
    'classic backdrop never paints the cover as a full-screen image',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlayerBackdrop(
            stageKind: AppPlayerStageKind.classic,
            imageProvider: null,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const ValueKey<String>('player-backdrop-classic')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    },
  );
}
