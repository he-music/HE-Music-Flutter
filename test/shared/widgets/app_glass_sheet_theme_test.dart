import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_sheet.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';

void main() {
  for (final player in [false, true]) {
    testWidgets(
      'open glass sheet tracks system brightness with player=$player',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final input = TextEditingController();
        addTearDown(input.dispose);
        await tester.pumpWidget(
          AppGlassScope(
            enabled: true,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              initialQuality: GlassQuality.minimal,
              child: MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: ThemeMode.system,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Open'),
                      onPressed: () {
                        Widget content(BuildContext context) => Column(
                          children: [
                            TextField(controller: input),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                        if (player) {
                          showPlayerStyledBottomSheet<void>(
                            context: context,
                            builder: content,
                          );
                        } else {
                          showLiveGlassSheet<void>(
                            context: context,
                            builder: content,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Keep draft');
        await tester.pumpAndSettle();
        final controller = tester
            .widget<GlassModalSheet>(find.byType(GlassModalSheet))
            .controller;
        for (final brightness in [Brightness.dark, Brightness.light]) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await tester.pumpAndSettle();
          final sheet = tester.widget<GlassModalSheet>(
            find.byType(GlassModalSheet),
          );
          final context = tester.element(find.text('Close'));
          expect(Theme.of(context).brightness, brightness);
          expect(
            sheet.settings!.backerColor!.computeLuminance(),
            brightness == Brightness.dark ? lessThan(0.2) : greaterThan(0.7),
          );
          expect(
            ModalRoute.of(context)!.barrierColor,
            brightness == Brightness.dark
                ? GlassDefaults.barrierColor
                : const Color(0x33000000),
          );
          expect(sheet.controller, same(controller));
          expect(input.text, 'Keep draft');
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassModalSheet), findsNothing);
      },
    );
  }
}
