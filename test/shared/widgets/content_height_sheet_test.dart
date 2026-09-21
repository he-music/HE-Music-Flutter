import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/settings_single_choice_sheet.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final glass in [true, false]) {
    for (final count in [3, 6, 20]) {
      testWidgets('settings fits $count choices with glass=$glass', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          AppGlassScope(
            enabled: glass,
            mode: glass ? AppGlassMode.low : AppGlassMode.off,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showSettingsSingleChoiceSheet<int>(
                        context: context,
                        title: 'Settings',
                        currentValue: 0,
                        options: [
                          for (var i = 0; i < count; i++)
                            SettingsChoiceOption(
                              value: i,
                              title: 'Option $i',
                              subtitle: count > 3
                                  ? 'Description of this setting'
                                  : null,
                              section: i == 0 || i == 4 ? 'Group $i' : null,
                            ),
                        ],
                        onSelected: (value) => selected = value,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scrollable = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        if (count <= 6) {
          expect(position.maxScrollExtent, closeTo(0, 1));
          expect(
            find.text('Option ${count - 1}').hitTestable(),
            findsOneWidget,
          );
        }
        if (glass) {
          final sheet = tester.widget<GlassModalSheet>(
            find.byType(GlassModalSheet),
          );
          expect(sheet.halfSize, lessThanOrEqualTo(.8));
          if (count == 3) expect(sheet.halfSize, lessThan(.45));
          if (count == 6) expect(sheet.halfSize, greaterThan(.45));
          expect(sheet.detents, {GlassSheetDetent.medium});
        }
        if (count == 6) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Option 5'),
            150,
            scrollable: scrollable,
          );
          expect(find.text('Option 5').hitTestable(), findsOneWidget);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Option 5'),
            150,
            scrollable: scrollable,
          );
          if (glass) {
            expect(
              tester
                  .widget<GlassModalSheet>(find.byType(GlassModalSheet))
                  .halfSize,
              lessThanOrEqualTo(.8),
            );
          }
        }
        if (count == 20) {
          final before = tester.getTopLeft(find.byType(ListView)).dy;
          await tester.drag(find.byType(ListView), const Offset(0, -180));
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(0));
          expect(
            tester.getTopLeft(find.byType(ListView)).dy,
            closeTo(before, 1),
          );
          await tester.scrollUntilVisible(
            find.text('Option 19'),
            200,
            scrollable: scrollable,
          );
        }
        await tester.tap(find.text('Option ${count - 1}'));
        await tester.pumpAndSettle();
        expect(selected, count - 1);
        expect(find.text('Settings'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
