import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('InterfacePreview')..addFont(
          File(
            'test/assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(
            File(
              'test/assets/fonts/Roboto-Regular.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  for (final style in AppUiStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('$style appearance settings render in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) {
                final theme = Theme.of(context);
                return Theme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'InterfacePreview',
                    ),
                    appBarTheme: theme.appBarTheme.copyWith(
                      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'InterfacePreview',
                      ),
                    ),
                    cupertinoOverrideTheme: CupertinoThemeData(
                      brightness: brightness,
                      primaryColor: theme.colorScheme.primary,
                      barBackgroundColor: theme.colorScheme.surface,
                      textTheme: CupertinoTextThemeData(
                        textStyle: TextStyle(
                          fontFamily: 'InterfacePreview',
                          color: theme.colorScheme.onSurface,
                        ),
                        navTitleTextStyle: TextStyle(
                          fontFamily: 'InterfacePreview',
                          color: theme.colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  child: const SettingsPage(
                    sectionId: SettingsSectionIds.appearance,
                  ),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(() => _Config(style, brightness)),
              appRouterProvider.overrideWithValue(router),
            ],
            child: RepaintBoundary(key: capture, child: const HeMusicApp()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Appearance'), findsOneWidget);
        expect(
          find.text(brightness == Brightness.dark ? 'Dark' : 'Light'),
          findsOneWidget,
        );
        expect(find.text('Current: Apple blue'), findsNothing);
        expect(find.text('Interface style'), findsOneWidget);
        expect(
          find.text(style == AppUiStyle.material ? 'Material' : 'Cupertino'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final pageState = tester.state(find.byType(SettingsPage));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsPage)),
        );
        for (final backgroundEnabled in [false, true]) {
          if (backgroundEnabled) {
            final tile = find.ancestor(
              of: find.text('Show Content Backgrounds'),
              matching: find.byType(AppSwitchListTile),
            );
            final toggle = find.descendant(
              of: tile,
              matching: find.byType(
                style == AppUiStyle.cupertino ? CupertinoSwitch : Switch,
              ),
            );
            await tester.ensureVisible(toggle);
            await tester.pumpAndSettle();
            await tester.tap(toggle);
            await tester.pumpAndSettle();
          }
          expect(
            container.read(appConfigProvider).showContentBackground,
            backgroundEnabled,
          );
          expect(tester.state(find.byType(SettingsPage)), same(pageState));
          if (style == AppUiStyle.cupertino) {
            for (final group in tester.widgetList<CupertinoListSection>(
              find.byType(CupertinoListSection),
            )) {
              expect(
                group.decoration!.color!.a,
                backgroundEnabled ? greaterThan(0) : 0,
              );
            }
          }
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '${Directory.systemTemp.path}/he-music-interface-previews/${style.name}-${brightness.name}${backgroundEnabled ? '-background' : ''}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Config extends AppConfigController {
  _Config(this.style, this.brightness);
  final AppUiStyle style;
  final Brightness brightness;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: 'en',
    uiStyle: style,
    themeAccent: AppThemeAccent.appleBlue,
    themeMode: brightness == Brightness.dark
        ? AppThemeMode.dark
        : AppThemeMode.light,
  );

  @override
  void setShowContentBackground(bool value) =>
      state = state.copyWith(showContentBackground: value);
}
