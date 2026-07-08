import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_player_background_style.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_backdrop.dart';

void main() {
  test('resolve fluid colors keeps blue covers vivid', () {
    final colors = resolveFluidColorsForTest([
      const Color(0xFF1E88E5),
      const Color(0xFF42A5F5),
      const Color(0xFF0D47A1),
    ]);

    expect(colors.length, 4);

    final leading = HSLColor.fromColor(colors.first);
    expect(leading.hue, inInclusiveRange(190, 235));
    expect(leading.saturation, greaterThan(0.18));
    expect(leading.lightness, greaterThan(0.28));
  });

  test('resolve fluid colors derives a complete palette from one seed', () {
    final colors = resolveFluidColorsForTest([const Color(0xFF43A047)]);

    expect(colors.length, 4);
    expect(colors.toSet().length, greaterThanOrEqualTo(3));
  });

  test('resolve fluid colors preserves muted purple mood', () {
    final colors = resolveFluidColorsForTest([
      const Color(0xFFB39AC7),
      const Color(0xFF8F7FA6),
      const Color(0xFF6E678B),
    ]);

    expect(colors.length, 4);

    final averageSaturation =
        colors
            .map((color) => HSLColor.fromColor(color).saturation)
            .reduce((left, right) => left + right) /
        colors.length;
    final averageLightness =
        colors
            .map((color) => HSLColor.fromColor(color).lightness)
            .reduce((left, right) => left + right) /
        colors.length;

    expect(averageSaturation, lessThan(0.55));
    expect(averageLightness, inInclusiveRange(0.28, 0.58));
  });

  test('fallback fluid colors return a stable cool palette', () {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F8CFF)),
    );

    final colors = fallbackFluidColorsForTest(theme);

    expect(colors.length, 4);
    expect(colors.any((color) => HSLColor.fromColor(color).hue >= 180), isTrue);
  });

  testWidgets('fluid backdrop builds without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerBackdrop(
            style: AppPlayerBackgroundStyle.fluid,
            imageProvider: null,
          ),
        ),
      ),
    );
    // AnimatedMeshGradient 内部 Future() precache shader 产生 pending timer，
    // 多次 pump 确保 microtask 和 timer 全部完成。
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey<String>('player-backdrop-fluid')),
      findsOneWidget,
    );
  });
}
