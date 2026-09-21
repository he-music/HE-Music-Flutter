import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/shared/widgets/detail_description_sheet.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final height in [800.0, 600.0]) {
      for (final lineCount in [2, 100]) {
        testWidgets(
          'description stays glass during upward overdrag: $brightness height=$height lines=$lineCount',
          (tester) async {
            tester.view.physicalSize = Size(400, height);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              AppGlassScope(
                enabled: true,
                child: GlassAdaptiveScope(
                  minQuality: GlassQuality.minimal,
                  maxQuality: GlassQuality.minimal,
                  child: MaterialApp(
                    theme: ThemeData(brightness: brightness),
                    home: Scaffold(
                      body: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showDetailDescriptionSheet(
                            context,
                            title: 'Description',
                            text: List.generate(
                              lineCount,
                              (i) => 'Line $i',
                            ).join('\n'),
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
            final fill = find.byKey(const Key('glass_modal_sheet_fill'));
            double fillAlpha() =>
                (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration)
                    .color!
                    .a;
            expect(
              fillAlpha(),
              0,
              reason:
                  'The resting high sheet must stay glass, even above the library full-height threshold.',
            );
            final top = tester.getTopLeft(fill).dy;
            final gesture = await tester.startGesture(Offset(200, top + 14));
            for (var step = 0; step < 5; step++) {
              await gesture.moveBy(const Offset(0, -12));
              await tester.pump(const Duration(milliseconds: 16));
              expect(
                fillAlpha(),
                0,
                reason:
                    'Check while the finger is held, not only after the spring settles.',
              );
            }
            await gesture.up();
            await tester.pumpAndSettle();
            expect(fillAlpha(), 0);
            expect(tester.getTopLeft(fill).dy, closeTo(top, 1));
            await tester.drag(find.byType(ListView), const Offset(0, -220));
            await tester.pumpAndSettle();
            expect(
              tester
                  .state<ScrollableState>(find.byType(Scrollable))
                  .position
                  .pixels,
              lineCount > 2 ? greaterThan(100) : closeTo(0, 1),
            );
            expect(fillAlpha(), 0);
            expect(tester.getTopLeft(fill).dy, closeTo(top, 1));
            await tester.dragFrom(Offset(200, top + 14), Offset(0, height));
            await tester.pumpAndSettle();
            expect(find.byType(ListView), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('long description opens tall and scrolls without resizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDetailDescriptionSheet(
                context,
                title: 'Description',
                text: List.generate(100, (i) => 'Line $i').join('\n'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    final sheetFinder = find.byType(BottomSheet);
    expect(tester.widget<BottomSheet>(sheetFinder).backgroundColor!.a, 1);
    final top = tester.getTopLeft(sheetFinder).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.pixels, greaterThan(100));
    expect(tester.getTopLeft(sheetFinder).dy, closeTo(top, 1));
    expect(tester.takeException(), isNull);
  });
}
