import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_player_theme_boundary.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';

void main() {
  testWidgets('player keeps classic accent theme under an immersive skin', (
    tester,
  ) async {
    final immersive = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve(AppSkinRegistry.citySoundCreatorId);
    final classic = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve(AppSkinRegistry.classicId);
    late ThemeData capturedTheme;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_ImmersiveConfigController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(immersive),
          home: AppPlayerThemeBoundary(
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

    expect(
      capturedTheme.colorScheme.primary,
      classic.light.colorScheme.primary,
    );
    expect(capturedTheme.extension<AppSkinTheme>()?.config, classic.light);
    expect(
      capturedTheme.colorScheme.primary,
      isNot(immersive.light.colorScheme.primary),
    );
  });
}

class _ImmersiveConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      skinId: AppSkinRegistry.citySoundCreatorId,
      themeAccent: AppThemeAccent.rose,
    );
  }
}
