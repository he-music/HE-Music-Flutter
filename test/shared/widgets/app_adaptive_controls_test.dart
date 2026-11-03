import 'dart:ui' show Tristate;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/app_back_button.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style navigation reserves the SDK toolbar height', (
      tester,
    ) async {
      final bodyKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(style),
          home: Scaffold(
            appBar: AppNavigationBar(
              title: const Text('Library'),
              leading: AppBackButton(onPressed: () {}),
            ),
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      );
      final expectedHeight = style == AppUiStyle.cupertino ? 44.0 : 56.0;
      expect(tester.getTopLeft(find.byKey(bodyKey)).dy, expectedHeight);
      final back = tester.getRect(find.byType(AppBackButton));
      expect(back.center.dy, expectedHeight / 2);
      expect(back.height, greaterThanOrEqualTo(44));
      if (style == AppUiStyle.cupertino) {
        final bar = tester.widget<CupertinoNavigationBar>(
          find.byType(CupertinoNavigationBar),
        );
        expect(bar.enableBackgroundFilterBlur, isFalse);
        expect(bar.transitionBetweenRoutes, isFalse);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$style icon actions keep keyboard activation and disabled semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(style),
            home: Scaffold(
              body: Column(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Play',
                    onPressed: () => taps++,
                  ),
                  const AppIconButton(
                    icon: Icon(Icons.skip_next),
                    tooltip: 'Next',
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        );
        final extent = style == AppUiStyle.cupertino ? 44 : 48;
        expect(
          tester.getSize(find.byType(AppIconButton).first).height,
          greaterThanOrEqualTo(extent),
        );
        final disabled = style == AppUiStyle.cupertino
            ? find.descendant(
                of: find.byType(AppIconButton).last,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.label == 'Next',
                ),
              )
            : find.byTooltip('Next');
        final disabledData = tester.getSemantics(disabled).getSemanticsData();
        expect(disabledData.flagsCollection.isButton, isTrue);
        expect(disabledData.flagsCollection.isEnabled, Tristate.isFalse);
        expect(
          '${disabledData.label}${disabledData.tooltip}',
          contains('Next'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, 1);
        await tester.tap(find.byTooltip('Next'));
        expect(taps, 1);
        semantics.dispose();
      },
    );
  }

  testWidgets('Cupertino back accepts the optional previous page title', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(AppUiStyle.cupertino),
        home: Scaffold(
          appBar: AppNavigationBar(
            title: const Text('Track'),
            leading: AppBackButton(
              previousPageTitle: 'Library',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Library'), findsOneWidget);
    await tester.tap(find.text('Library'));
    expect(taps, 1);
  });
}

ThemeData _theme(AppUiStyle style) => AppTheme.light(
  AppSkinRegistry.builtIn(AppThemeAccent.appleBlue).resolve('classic'),
  uiStyle: style,
);
