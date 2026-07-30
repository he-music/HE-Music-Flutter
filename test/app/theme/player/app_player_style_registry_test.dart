import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_style.dart';

void main() {
  test('built-in registry exposes six complete unique styles', () {
    final registry = AppPlayerStyleRegistry.builtIn();

    expect(
      registry.styles.map((style) => style.metadata.id).toSet(),
      AppPlayerStyleRegistry.builtInIds,
    );
    expect(registry.styles, hasLength(6));
    expect(registry.styles.every((style) => style.isValid), isTrue);
    expect(
      registry
          .resolve(AppPlayerStyleRegistry.radialSpectrumId)
          .usesRealtimeSpectrum,
      isTrue,
    );
    expect(
      registry.styles
          .where(
            (style) =>
                style.metadata.id != AppPlayerStyleRegistry.radialSpectrumId,
          )
          .every((style) => !style.usesRealtimeSpectrum),
      isTrue,
    );
  });

  test('unknown and empty ids resolve to classic', () {
    final registry = AppPlayerStyleRegistry.builtIn();

    expect(registry.normalizeId(null), AppPlayerStyleRegistry.classicId);
    expect(registry.normalizeId(''), AppPlayerStyleRegistry.classicId);
    expect(
      registry.resolve('removed').metadata.id,
      AppPlayerStyleRegistry.classicId,
    );
  });

  test(
    'classic vinyl cassette and radial spectrum share backdrop base colors',
    () {
      final registry = AppPlayerStyleRegistry.builtIn();
      final classicColors = registry
          .resolve(AppPlayerStyleRegistry.classicId)
          .colors;

      for (final id in <String>{
        AppPlayerStyleRegistry.vinylId,
        AppPlayerStyleRegistry.cassetteId,
        AppPlayerStyleRegistry.radialSpectrumId,
      }) {
        final colors = registry.resolve(id).colors;
        expect(
          colors.backgroundStart,
          classicColors.backgroundStart,
          reason: id,
        );
        expect(colors.backgroundEnd, classicColors.backgroundEnd, reason: id);
      }
    },
  );

  test('registry rejects duplicate ids', () {
    expect(
      () => AppPlayerStyleRegistry(const [
        classicPlayerStyle,
        classicPlayerStyle,
      ]),
      throwsStateError,
    );
  });
}
