import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_route_page.dart';

void main() {
  Future<void> openPlayer(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('header tracks dragging and returns after a small slow release', (
    tester,
  ) async {
    await openPlayer(tester);
    final header = find.byKey(const ValueKey('header'));
    final start = tester.getCenter(header);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    final before = tester.getTopLeft(header).dy;
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getTopLeft(header).dy - before, closeTo(60, 1));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(header).dy, closeTo(0, 1));
    expect(find.text('Player'), findsOneWidget);
  });

  testWidgets('downward flick dismisses and body scrolling does not', (
    tester,
  ) async {
    await openPlayer(tester);
    await tester.fling(find.byType(ListView), const Offset(0, -200), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    await tester.fling(
      find.byKey(const ValueKey('header')),
      const Offset(0, 100),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('underlying page stays painted while exit cleanup awaits', (
    tester,
  ) async {
    final cleanup = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: _Harness(beforeDismiss: cleanup.future)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // Orientation/system-UI cleanup may outlive the closing spring. The
    // player is offscreen, so the previous page must remain onstage.
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    cleanup.complete();
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('closing spring can be grabbed and reversed', (tester) async {
    await openPlayer(tester);
    final header = find.byKey(const ValueKey('header'));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final movingY = tester.getTopLeft(header).dy;
    expect(movingY, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(header));
    await gesture.moveBy(const Offset(0, -25));
    await tester.pump();
    final caughtY = tester.getTopLeft(header).dy;
    expect(caughtY, lessThanOrEqualTo(movingY));
    await gesture.moveBy(
      const Offset(0, -180),
      timeStamp: const Duration(milliseconds: 40),
    );
    await tester.pump();
    await gesture.up(timeStamp: const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    expect(tester.getTopLeft(header).dy, closeTo(0, 1));
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({this.beforeDismiss});
  final Future<void>? beforeDismiss;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Navigator(
    onDidRemovePage: (_) => setState(() => _open = false),
    pages: [
      MaterialPage<void>(
        child: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => setState(() => _open = true),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      if (_open)
        PlayerRoutePage(
          child: Builder(
            builder: (context) {
              Future<void> dismiss() async {
                await widget.beforeDismiss;
                if (context.mounted) Navigator.of(context).pop();
              }

              return Scaffold(
                body: Column(
                  children: [
                    PlayerDismissRegion(
                      onDismiss: dismiss,
                      child: SizedBox(
                        key: const ValueKey('header'),
                        height: 80,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  PlayerDismissRegion.close(context, dismiss),
                              icon: const Icon(Icons.close),
                            ),
                            const Expanded(
                              child: Center(child: Text('Player')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: List.generate(
                          50,
                          (i) => ListTile(title: Text('Line $i')),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    ],
  );
}
