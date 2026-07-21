import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
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
