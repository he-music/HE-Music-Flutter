import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/home_search_field.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style search submits, clears, retains focus and scales', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      String? changed;
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppUiTheme(style: style)]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              focusNode: focus,
              placeholderPrimary: 'Search songs',
              placeholderSecondary: 'and artists',
              onChanged: (value) => changed = value,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      );
      final input = find.byType(
        style == AppUiStyle.cupertino ? CupertinoTextField : TextField,
      );
      await tester.enterText(input, 'Adele');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, 'Adele');
      expect(changed, 'Adele');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changed, '');
      expect(focus.hasFocus, isTrue);
      expect(tester.getSize(input).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino search surfaces match $brightness with Apple blue', (
      tester,
    ) async {
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.appleBlue,
      ).resolve('classic');
      final theme = brightness == Brightness.light
          ? AppTheme.light(skin, uiStyle: AppUiStyle.cupertino)
          : AppTheme.dark(skin, uiStyle: AppUiStyle.cupertino);
      final controller = TextEditingController();
      final onlineController = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(onlineController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                HomeSearchField(
                  placeholderPrimary: 'Home search',
                  onTap: () {},
                ),
                AppSearchField(
                  controller: controller,
                  placeholderPrimary: 'Settings search',
                ),
                SearchTopBox(
                  controller: onlineController,
                  placeholderPrimary: 'Online search',
                  onSubmit: () async {},
                  onChanged: (_) {},
                ),
                const TextField(
                  decoration: InputDecoration(hintText: 'Profile editor'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputs = tester.widgetList<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      final home = tester.widget<CupertinoButton>(
        find.descendant(
          of: find.byType(HomeSearchField),
          matching: find.byType(CupertinoButton),
        ),
      );
      final fill = home.color!;
      expect(fill.a, 1);
      expect(
        fill.computeLuminance(),
        brightness == Brightness.light ? greaterThan(0.6) : lessThan(0.15),
      );
      expect(inputs, hasLength(2));
      for (final input in inputs) {
        expect(input.decoration!.color, fill);
      }
      // The editable form retains the theme's original input fill.
      expect(
        Theme.of(
          tester.element(find.byType(TextField)),
        ).inputDecorationTheme.fillColor,
        theme.inputDecorationTheme.fillColor,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
