import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/router/app_router.dart';

void main() {
  testWidgets('app uses dark status bar icons for light theme by default', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(themeMode: AppThemeMode.light));
    await tester.pump();

    final overlayStyle = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .first
        .value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(overlayStyle.statusBarBrightness, Brightness.light);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('app uses light status bar icons for dark theme by default', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(themeMode: AppThemeMode.dark));
    await tester.pump();

    final overlayStyle = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .first
        .value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('app follows system locale when locale code is system', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(themeMode: AppThemeMode.light, localeCode: 'system'),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, isNull);
  });
}

Widget _buildApp({required AppThemeMode themeMode, String localeCode = 'zh'}) {
  final router = GoRouter(
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          themeMode: themeMode,
          localeCode: localeCode,
        ),
      ),
      appRouterProvider.overrideWithValue(router),
    ],
    child: const HeMusicApp(),
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.themeMode, required this.localeCode});

  final AppThemeMode themeMode;
  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      themeMode: themeMode,
    );
  }
}
