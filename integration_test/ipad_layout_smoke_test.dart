import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/i18n/app_i18n.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/about_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/main.dart' as app;
import 'package:he_music_flutter/shared/widgets/app_back_button.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Run on an iPad simulator with a wide window.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wide iPad My, Settings and About flow', (tester) async {
    await app.main();
    final initialSize = tester.view.physicalSize;
    if (initialSize.width < initialSize.height) {
      // Simulator rotation is host-controlled in multitasking mode. Exercise
      // landscape layout metrics without changing the app’s orientation policy.
      tester.view.physicalSize = Size(initialSize.height, initialSize.width);
      addTearDown(tester.view.resetPhysicalSize);
    }
    await tester.pump();

    final appContext = tester.element(find.byType(HeMusicApp));
    final container = ProviderScope.containerOf(appContext, listen: false);
    final router = container.read(appRouterProvider);
    final config = container.read(appConfigProvider);
    final settingsLabel = AppI18n.t(config, 'settings.title');
    final aboutLabel = AppI18n.t(config, 'settings.about.title');

    Future<void> pumpNavigation() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    router.go(AppRoutes.my);
    await pumpNavigation();

    final my = find.byType(MyPage);
    final viewport = MediaQuery.sizeOf(tester.element(my));
    debugPrint('IPAD_TEST_VIEWPORT=$viewport');
    expect(viewport.width, greaterThanOrEqualTo(840));
    expect(tester.getSize(my).width, viewport.width);

    await tester.tap(
      find.descendant(of: my, matching: find.text(settingsLabel)),
    );
    await pumpNavigation();
    final sidebar = find.byKey(const ValueKey('settings-sidebar'));
    final detail = find.byKey(const ValueKey('settings-detail-pane'));
    expect(sidebar, findsOneWidget);
    expect(
      tester.getRect(detail).left,
      greaterThan(tester.getRect(sidebar).right),
    );
    final expectedAbout = find.descendant(
      of: detail,
      matching: find.byType(AboutPage),
    );
    final aboutRow = find.descendant(
      of: sidebar,
      matching: find.text(AppI18n.t(config, 'settings.section.general')),
    );
    await tester.tap(aboutRow);
    await pumpNavigation();
    expect(expectedAbout, findsOneWidget);
    expect(router.state.uri.path, AppRoutes.settings);

    await tester.tap(
      find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(AppBackButton),
      ),
    );
    await pumpNavigation();
    await tester.tap(find.descendant(of: my, matching: find.text(aboutLabel)));
    await pumpNavigation();
    expect(sidebar, findsOneWidget);
    expect(expectedAbout, findsOneWidget);
    expect(router.state.uri.path, AppRoutes.about);
  });
}
