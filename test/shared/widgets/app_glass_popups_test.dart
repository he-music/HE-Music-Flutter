import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';
import 'package:he_music_flutter/shared/widgets/app_alert_dialog.dart';
import 'package:he_music_flutter/shared/widgets/app_form_dialog.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Widget _app(AppGlassMode mode, Widget child) => AppGlassScope(
  enabled: mode != AppGlassMode.off,
  mode: mode,
  child: GlassAdaptiveScope(
    minQuality: GlassQuality.minimal,
    maxQuality: GlassQuality.minimal,
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

void main() {
  for (final mode in AppGlassMode.values) {
    testWidgets('$mode alert preserves input, result and keyboard clearance', (
      tester,
    ) async {
      final input = TextEditingController();
      addTearDown(input.dispose);
      addTearDown(tester.view.resetViewInsets);
      String? result;
      await tester.pumpWidget(
        _app(
          mode,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (context) => AppAlertDialog(
                    title: const Text('Create playlist'),
                    content: TextField(controller: input),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, input.text),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byType(GlassDialog),
        mode.usesGlass ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(AlertDialog),
        mode.usesGlass ? findsNothing : findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'New playlist');
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.text('Create')).dy,
        lessThan(
          (tester.view.physicalSize.height - 160) /
              tester.view.devicePixelRatio,
        ),
      );
      if (!mode.usesGlass) expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, 'New playlist');
      expect(find.text('Create playlist'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$mode desktop menu returns selection and dismisses with escape',
      (tester) async {
        int? result;
        await tester.pumpWidget(
          _app(
            mode,
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAdaptiveActionMenu<int>(
                    context: context,
                    anchorPosition: const Offset(100, 100),
                    items: const [
                      AdaptiveActionMenuItem(
                        value: 0,
                        label: 'Unavailable',
                        enabled: false,
                      ),
                      AdaptiveActionMenuItem(
                        value: 1,
                        label: 'Select item',
                        startsNewSection: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open menu'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open menu'));
        await tester.pumpAndSettle();
        expect(
          find.byType(GlassMenu),
          mode.usesGlass ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('Unavailable'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.text('Select item'), findsOneWidget);
        await tester.tap(find.text('Select item'));
        await tester.pumpAndSettle();
        expect(result, 1);
        await tester.tap(find.text('Open menu'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Select item'), findsNothing);
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  testWidgets(
    'glass alert keeps disabled action semantics with Material fallback',
    (tester) async {
      await tester.pumpWidget(
        _app(
          AppGlassMode.high,
          const AppAlertDialog(
            title: Text('Wait'),
            actions: [TextButton(onPressed: null, child: Text('Disabled'))],
          ),
        ),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(GlassDialog), findsNothing);
    },
  );

  testWidgets('desktop form uses one glass surface with ordinary inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppGlassMode.low,
        const AppFormDialog(child: SizedBox(width: 400, child: TextField())),
      ),
    );
    expect(find.byType(GlassCard), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Form input');
    expect(find.text('Form input'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
