import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_sheet_close_button.dart';
import 'package:he_music_flutter/shared/widgets/app_sheet_header.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Cupertino close is labeled and cancels in $locale $brightness',
        (tester) async {
          final result = Completer<int?>();
          await tester.pumpWidget(
            _app(
              locale: locale,
              brightness: brightness,
              child: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async => result.complete(
                    await showAppThemedBottomSheet<int>(
                      context: context,
                      fitContent: true,
                      builder: (_) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSheetHeader(title: 'Options', actionLabel: 'Done'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final close = find.byType(AppSheetCloseButton);
          expect(close.hitTestable(), findsOneWidget);
          expect(find.text('Done'), findsNothing);
          expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsOneWidget);
          expect(
            find.byTooltip(locale == 'zh' ? '关闭' : 'Close'),
            findsOneWidget,
          );
          final rect = tester.getRect(close);
          expect(rect.width, greaterThanOrEqualTo(44));
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(
            find.descendant(
              of: close,
              matching: find.bySemanticsLabel(locale == 'zh' ? '关闭' : 'Close'),
            ),
            findsOneWidget,
          );
          expect(ModalRoute.of(tester.element(close)), isA<PopupRoute<int>>());
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(await result.future, isNull);
          expect(find.byType(AppSheetCloseButton), findsNothing);
          expect(find.text('Open'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('Material headers retain the supplied text action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        style: AppUiStyle.material,
        child: const AppSheetHeader(title: 'Options', actionLabel: 'Dismiss'),
      ),
    );
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.byType(AppSheetCloseButton), findsNothing);
  });

  testWidgets('closing a nested sheet preserves the parent route and choices', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      _app(
        child: Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () => showAppThemedBottomSheet<void>(
              context: context,
              fitContent: true,
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppSheetHeader(title: 'Parent'),
                  TextButton(
                    child: const Text('Select and open'),
                    onPressed: () {
                      selected = true;
                      showAppThemedBottomSheet<void>(
                        context: context,
                        fitContent: true,
                        builder: (_) => const AppSheetHeader(title: 'Child'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final parentRoute = ModalRoute.of(tester.element(find.text('Parent')));
    await tester.tap(find.text('Select and open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppSheetCloseButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsNothing);
    expect(find.text('Parent'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.text('Parent'))),
      same(parentRoute),
    );
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required Widget child,
  String locale = 'en',
  Brightness brightness = Brightness.light,
  AppUiStyle style = AppUiStyle.cupertino,
}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(
    brightness: brightness,
    extensions: [AppUiTheme(style: style)],
  ),
  home: Scaffold(body: child),
);
