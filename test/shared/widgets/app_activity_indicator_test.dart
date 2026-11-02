import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_activity_indicator.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style waiting feedback preserves size, color and semantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: const Center(
              child: AppActivityIndicator(
                size: 18,
                strokeWidth: 1.5,
                color: Colors.white,
                semanticsLabel: 'Preparing track',
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(AppActivityIndicator)),
          const Size(18, 18),
        );
        expect(find.bySemanticsLabel('Preparing track'), findsOneWidget);
        if (style == AppUiStyle.cupertino) {
          final spinner = tester.widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          );
          expect(spinner.radius, 9);
          expect(spinner.color, Colors.white);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        } else {
          final spinner = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          expect(spinner.strokeWidth, 1.5);
          expect(spinner.color, Colors.white);
          expect(find.byType(CupertinoActivityIndicator), findsNothing);
        }
      },
      semanticsEnabled: true,
    );

    testWidgets('$style waiting feedback follows live system reduced motion', (
      tester,
    ) async {
      final disabled = ValueNotifier(false);
      addTearDown(disabled.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppUiTheme(style: style)]),
          home: ValueListenableBuilder<bool>(
            valueListenable: disabled,
            builder: (context, value, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: child!,
            ),
            child: const Center(
              child: AppActivityIndicator(color: Colors.white),
            ),
          ),
        ),
      );
      disabled.value = true;
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.hourglass_empty_rounded),
      );
      expect(icon.color, Colors.white);
      expect(tester.hasRunningAnimations, isFalse);
      disabled.value = false;
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
      expect(tester.hasRunningAnimations, isTrue);
    });
  }
}
