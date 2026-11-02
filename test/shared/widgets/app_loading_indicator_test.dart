import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_loading_indicator.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style loading feedback follows changes to system reduce motion',
      (tester) async {
        final reduceMotion = ValueNotifier<bool>(false);
        addTearDown(reduceMotion.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: ValueListenableBuilder<bool>(
              valueListenable: reduceMotion,
              builder: (context, disabled, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: disabled),
                child: Center(child: child),
              ),
              child: const AppLoadingIndicator(label: '加载中…'),
            ),
          ),
        );

        final spinner = style == AppUiStyle.cupertino
            ? find.byType(CupertinoActivityIndicator)
            : find.byType(CircularProgressIndicator);
        expect(spinner, findsOneWidget);
        expect(find.bySemanticsLabel('加载中…'), findsOneWidget);
        final semantics = tester.getSemantics(find.bySemanticsLabel('加载中…'));
        expect(
          semantics.getSemanticsData().flagsCollection.isLiveRegion,
          isTrue,
        );

        reduceMotion.value = true;
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
        expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
        expect(find.text('加载中…'), findsOneWidget);
        expect(find.bySemanticsLabel('加载中…'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);

        reduceMotion.value = false;
        await tester.pump();
        expect(spinner, findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
      },
      semanticsEnabled: true,
    );
  }

  testWidgets('loading label fits a narrow layout with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Center(
            child: SizedBox(
              width: 120,
              child: AppLoadingIndicator(label: 'Loading…'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Loading…'), findsOneWidget);
  });
}
