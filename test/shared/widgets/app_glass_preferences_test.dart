import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('changing glass mode preserves routes and local state', (
    tester,
  ) async {
    final controller = _ConfigController();
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    var builds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppGlassPreferences(
          available: true,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) {
                builds++;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: TextField()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep input');
    final navigator = navigatorKey.currentState;
    final priorBuilds = builds;
    controller.setGlassMode(AppGlassMode.powerSaving);
    await tester.pumpAndSettle();
    expect(navigatorKey.currentState, same(navigator));
    expect(find.text('keep input'), findsOneWidget);
    expect(navigator!.canPop(), isTrue);
    final scope = tester.widget<GlassAdaptiveScope>(
      find.byType(GlassAdaptiveScope),
    );
    expect(scope.maxQuality, GlassQuality.standard);
    final context = tester.element(find.byType(TextField));
    expect(AppGlassScope.isEnabled(context), isTrue);
    expect(AppGlassScope.preferOpaqueSurfaces(context), isTrue);
    controller.setGlassMode(AppGlassMode.off);
    await tester.pumpAndSettle();
    expect(AppGlassScope.isEnabled(context), isFalse);
    expect(find.text('keep input'), findsOneWidget);
    controller.setGlassMode(AppGlassMode.automatic);
    await tester.pumpAndSettle();
    expect(AppGlassScope.isEnabled(context), isTrue);
    expect(AppGlassScope.preferOpaqueSurfaces(context), isFalse);
    for (final mode in AppGlassMode.values) {
      controller.setGlassMode(mode);
      await tester.pumpAndSettle();
      final scope = tester.widget<GlassAdaptiveScope>(
        find.byType(GlassAdaptiveScope),
      );
      final expected = switch (mode) {
        AppGlassMode.automatic || AppGlassMode.high => GlassQuality.premium,
        AppGlassMode.standard ||
        AppGlassMode.powerSaving => GlassQuality.standard,
        AppGlassMode.low || AppGlassMode.off => GlassQuality.minimal,
      };
      expect(scope.maxQuality, expected);
      expect(
        scope.minQuality,
        mode == AppGlassMode.automatic ? GlassQuality.minimal : expected,
      );
      expect(scope.allowStepUp, mode == AppGlassMode.automatic);
      expect(AppGlassScope.qualityOf(context), expected);
      expect(AppGlassScope.controlsEnabled(context), mode.usesGlass);
      expect(navigatorKey.currentState, same(navigator));
      expect(find.text('keep input'), findsOneWidget);
      expect(navigator.canPop(), isTrue);
    }
    expect(builds, priorBuilds);
    expect(tester.takeException(), isNull);
  });
}

class _ConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  @override
  void setGlassMode(AppGlassMode mode) =>
      state = state.copyWith(glassMode: mode);
}
