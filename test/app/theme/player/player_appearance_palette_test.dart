import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:he_music_flutter/app/config/app_player_appearance.dart';
import 'package:he_music_flutter/app/theme/player/app_player_appearance_palette.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';

void main() {
  testWidgets(
    'changing palette mid-transition starts from the visible colors',
    (tester) async {
      Widget view(Color color) => MaterialApp(
        home: TweenAnimationBuilder<List<Color>>(
          tween: PlayerPaletteTween([color]),
          duration: const Duration(seconds: 1),
          builder: (_, colors, _) => ColoredBox(
            key: const ValueKey('palette-surface'),
            color: colors.first,
          ),
        ),
      );
      Color visible() => tester
          .widget<ColoredBox>(find.byKey(const ValueKey('palette-surface')))
          .color;
      await tester.pumpWidget(view(Colors.blue));
      await tester.pumpWidget(view(Colors.red));
      await tester.pump(const Duration(milliseconds: 400));
      final interrupted = visible();
      expect(interrupted, isNot(Colors.red));
      await tester.pumpWidget(view(Colors.green));
      expect(visible(), interrupted);
      await tester.pumpAndSettle();
      expect(visible(), Colors.green);
    },
  );
  test('automatic colors follow artwork while manual channels stay fixed', () {
    const blue = [Color(0xff287ebc)];
    const orange = [Color(0xffce7827)];
    const custom = AppPlayerAppearance(
      backgroundColor: 0xff734ab0,
      accentColor: 0xffffce73,
    );
    final first = playerAppearanceScenePalette(
      classicPlayerScenePaletteFallback,
      blue,
      custom,
    );
    final second = playerAppearanceScenePalette(
      classicPlayerScenePaletteFallback,
      orange,
      custom,
    );
    expect(first, second);
    expect(first.accent, const Color(0xffffce73));
    final automatic = custom.copyWith(autoBackground: true);
    final fromBlue = playerAppearanceScenePalette(
      classicPlayerScenePaletteFallback,
      blue,
      automatic,
    );
    final fromOrange = playerAppearanceScenePalette(
      classicPlayerScenePaletteFallback,
      orange,
      automatic,
    );
    expect(fromBlue.surface, isNot(fromOrange.surface));
    expect(fromBlue.accent, fromOrange.accent);
  });

  test(
    'dark mood reduces surface brightness and neutral artwork stays neutral',
    () {
      const source = [Color(0xff3478bf)];
      final vivid = playerAppearanceColors(source, const AppPlayerAppearance());
      final dark = playerAppearanceColors(
        source,
        const AppPlayerAppearance(mood: AppPlayerColorMood.dark),
      );
      expect(
        dark.first.computeLuminance(),
        lessThan(vivid.first.computeLuminance()),
      );
      final neutral = playerAppearanceColors([
        const Color(0xff888888),
      ], const AppPlayerAppearance());
      for (final color in neutral) {
        expect(Hct.fromInt(color.toARGB32()).chroma, lessThan(8));
      }
    },
  );
}
