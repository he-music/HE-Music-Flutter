import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/app_loading_indicator.dart';

void main() {
  testWidgets(
    'loading feedback follows changes to system reduce motion',
    (tester) async {
      final reduceMotion = ValueNotifier<bool>(false);
      addTearDown(reduceMotion.dispose);

      await tester.pumpWidget(
        MaterialApp(
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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('加载中…'), findsOneWidget);

      reduceMotion.value = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
      expect(find.text('加载中…'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      reduceMotion.value = false;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
    },
    semanticsEnabled: true,
  );

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
