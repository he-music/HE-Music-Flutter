import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_scroll_behavior.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/app_button.dart';
import 'package:he_music_flutter/shared/widgets/app_list_tile.dart';

void main() {
  final skin = AppSkinRegistry.builtIn(
    AppThemeAccent.appleBlue,
  ).resolve('classic');

  test(
    'Cupertino classic uses neutral surfaces and keeps the selected tint',
    () {
      final light = AppTheme.light(skin, uiStyle: AppUiStyle.cupertino);
      final dark = AppTheme.dark(skin, uiStyle: AppUiStyle.cupertino);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF2F2F7));
      expect(dark.scaffoldBackgroundColor, Colors.black);
      expect(light.colorScheme.primary, AppThemeAccent.appleBlue.lightSeed);
      expect(dark.colorScheme.primary, AppThemeAccent.appleBlue.darkSeed);
      expect(light.textTheme.bodyMedium?.fontSize, 17);
      expect(
        light.extension<AppSkinTheme>()?.config.colors.cardBackground,
        Colors.white,
      );
      final wallpaper = AppSkinRegistry.builtIn(
        AppThemeAccent.appleBlue,
      ).resolve(AppSkinRegistry.citySoundCreatorId);
      expect(
        AppTheme.light(
          wallpaper,
          uiStyle: AppUiStyle.cupertino,
        ).extension<AppSkinTheme>()?.config,
        wallpaper.light,
      );
    },
  );

  testWidgets('Cupertino action rows support keyboard and disabled actions', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin, uiStyle: AppUiStyle.cupertino),
        home: Scaffold(
          body: AppListSection(
            children: [
              AppListTile(title: const Text('Enabled'), onTap: () => calls++),
              AppListTile(
                title: const Text('Disabled'),
                enabled: false,
                onTap: () => calls++,
              ),
              AppButton.filled(
                onPressed: null,
                child: const Text('Unavailable'),
              ),
            ],
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.text('Enabled'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.tap(find.text('Disabled'));
    await tester.tap(find.text('Unavailable'));
    expect(calls, 1);
    await tester.tap(find.text('Enabled'));
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cupertino settings wrap long values and labels at large text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(skin, uiStyle: AppUiStyle.cupertino),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppListSection(
                children: [
                  AppListTile(
                    leading: const AppSkinIcon(
                      role: AppSkinIconRole.settingsAppearance,
                    ),
                    title: const Text('Interface style'),
                    subtitle: const Text(
                      'Choose the design used for navigation and controls.',
                    ),
                    additionalInfo: const Text(
                      'Cupertino with a long translated value',
                    ),
                    showChevron: true,
                    onTap: () {},
                  ),
                  AppSwitchListTile(
                    title: const Text('Cache music during playback'),
                    value: false,
                    onChanged: (_) => toggles++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(CupertinoSwitch));
      await tester.tap(find.byType(CupertinoSwitch));
      expect(toggles, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cupertino scrolling follows the design choice on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(uiStyle: AppUiStyle.cupertino),
        theme: AppTheme.light(
          skin,
          uiStyle: AppUiStyle.cupertino,
        ).copyWith(platform: TargetPlatform.android),
        home: Scaffold(body: ListView(children: const [Text('Content')])),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final gesture = await tester.startGesture(const Offset(100, 200));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(scrollable.position.pixels, lessThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });
}
