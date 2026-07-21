import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';

void main() {
  testWidgets('player style ignores global skin and outer brightness', (
    tester,
  ) async {
    final immersive = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve(AppSkinRegistry.citySoundCreatorId);
    final expected = AppPlayerStyleRegistry.instance.resolve(
      AppPlayerStyleRegistry.cassetteId,
    );
    late ThemeData capturedTheme;

    Future<void> pump(ThemeData outerTheme) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_CassetteConfigController.new),
          ],
          child: MaterialApp(
            theme: outerTheme,
            home: AppPlayerStyleBoundary(
              child: Builder(
                builder: (context) {
                  capturedTheme = Theme.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(AppTheme.light(immersive));
    final lightOuterPlayerColor = capturedTheme.colorScheme.primary;
    final lightPlayerStyleTheme = capturedTheme
        .extension<AppPlayerStyleTheme>();

    expect(capturedTheme.brightness, Brightness.dark);
    expect(lightPlayerStyleTheme?.package, same(expected));
    expect(lightPlayerStyleTheme?.sheetBrightness, Brightness.light);
    expect(capturedTheme.extension<AppSkinTheme>(), isNull);

    await pump(AppTheme.dark(immersive));
    final darkPlayerStyleTheme = capturedTheme.extension<AppPlayerStyleTheme>();
    expect(capturedTheme.colorScheme.primary, lightOuterPlayerColor);
    expect(capturedTheme.colorScheme.primary, expected.colors.accent);
    expect(darkPlayerStyleTheme?.package, same(expected));
    expect(darkPlayerStyleTheme?.sheetBrightness, Brightness.dark);
  });
}

class _CassetteConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      skinId: AppSkinRegistry.citySoundCreatorId,
      themeAccent: AppThemeAccent.rose,
      playerStyleId: AppPlayerStyleRegistry.cassetteId,
    );
  }
}
