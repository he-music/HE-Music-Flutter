import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      'Material menu preserves disabled, cancel and selection (desktop=$desktop)',
      (tester) async {
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
            ),
            home: Scaffold(
              body: AdaptiveActionMenu<int>(
                menuKey: const Key('open'),
                tooltip: 'Menu',
                icon: const Icon(Icons.more_horiz),
                items: const [
                  AdaptiveActionMenuItem(value: 1, label: 'Available'),
                  AdaptiveActionMenuItem(
                    value: 2,
                    label: 'Disabled',
                    enabled: false,
                  ),
                ],
                onSelected: selections.add,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Disabled'));
        await tester.pumpAndSettle();
        expect(selections, isEmpty);
        expect(find.text('Available'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(selections, isEmpty);
        expect(find.text('Available'), findsNothing);
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Available'));
        await tester.pumpAndSettle();
        expect(selections, [1]);
        expect(find.text('Available'), findsNothing);
      },
    );
  }
}
