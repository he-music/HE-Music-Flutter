import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_style.dart';

void main() {
  test('built-in registry exposes four complete unique styles', () {
    final registry = AppPlayerStyleRegistry.builtIn();

    expect(
      registry.styles.map((style) => style.metadata.id).toSet(),
      AppPlayerStyleRegistry.builtInIds,
    );
    expect(registry.styles, hasLength(4));
    expect(registry.styles.every((style) => style.isValid), isTrue);
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
