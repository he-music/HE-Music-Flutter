import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';

void main() {
  testWidgets(
    'switching interface style keeps route, input, skin and system motion settings',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) => const Scaffold(body: TextField()),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_Config.new),
          appRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HeMusicApp(),
        ),
      );
      router.push('/edit');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'keep this input');
      final navigator = navigatorKey.currentState;
      final editable = tester.state(find.byType(EditableText));
      final skin = container.read(appConfigProvider).skinId;
      final media = MediaQuery.of(tester.element(find.byType(TextField)));
      final config = container.read(appConfigProvider.notifier);
      for (final style in [AppUiStyle.cupertino, AppUiStyle.material]) {
        config.setUiStyle(style);
        await tester.pumpAndSettle();
        expect(navigatorKey.currentState, same(navigator));
        expect(tester.state(find.byType(EditableText)), same(editable));
        expect(find.text('keep this input'), findsOneWidget);
        expect(router.state.uri.path, '/edit');
        expect(container.read(appConfigProvider).skinId, skin);
        final context = tester.element(find.byType(TextField));
        expect(
          AppUiTheme.usesCupertino(context),
          style == AppUiStyle.cupertino,
        );
        expect(
          MediaQuery.disableAnimationsOf(context),
          media.disableAnimations,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style controls follow the user choice on every platform',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: Scaffold(
              appBar: const AppNavigationBar(title: Text('Settings')),
              body: Column(
                children: [
                  AppSearchField(
                    controller: controller,
                    placeholderPrimary: 'Search',
                  ),
                  AppSwitchListTile(
                    value: true,
                    onChanged: (_) {},
                    title: const Text('Playback cache'),
                  ),
                  AppIconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {},
                    tooltip: 'Play',
                  ),
                ],
              ),
            ),
          ),
        );
        if (style == AppUiStyle.cupertino) {
          expect(find.byType(CupertinoNavigationBar), findsOneWidget);
          expect(find.byType(CupertinoTextField), findsOneWidget);
          expect(find.byType(CupertinoSwitch), findsOneWidget);
        } else {
          expect(find.byType(AppBar), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          expect(find.byType(Switch), findsOneWidget);
        }
        expect(
          find.byWidgetPredicate(
            (widget) => widget is BackdropFilter && widget.enabled,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }),
    );
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  @override
  void setUiStyle(AppUiStyle style) => state = state.copyWith(
    uiStyle: style,
    uiStylePreference: style == AppUiStyle.cupertino
        ? AppUiStylePreference.cupertino
        : AppUiStylePreference.material,
  );
}
