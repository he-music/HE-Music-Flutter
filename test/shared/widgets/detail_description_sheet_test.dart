import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/detail_description_sheet.dart';

void main() {
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
