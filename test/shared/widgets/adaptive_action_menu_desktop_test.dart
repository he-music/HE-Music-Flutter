import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';

void main() {
  for (final anchor in <Offset>[
    const Offset(2, 2),
    const Offset(358, 2),
    const Offset(2, 278),
    const Offset(358, 278),
  ]) {
    testWidgets(
      'long action menu at $anchor stays in window and reaches last item',
      (tester) async {
        tester.view.physicalSize = const Size(360, 280);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          _menuApp(anchor: anchor, count: 30, onSelected: (v) => selected = v),
        );
        await tester.tap(find.text('Open menu'));
        await tester.pumpAndSettle();

        final scrollView = find.byType(SingleChildScrollView);
        expect(scrollView, findsOneWidget);
        final viewport = tester.getRect(scrollView);
        // Allow subpixel spring settling while preserving the 8px screen margin.
        expect(viewport.left, greaterThanOrEqualTo(7.9));
        expect(viewport.top, greaterThanOrEqualTo(7.9));
        expect(viewport.right, lessThanOrEqualTo(352.1));
        expect(viewport.bottom, lessThanOrEqualTo(272.1));

        await tester.scrollUntilVisible(
          find.text('Action 29'),
          180,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text('Action 29').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Action 29'));
        await tester.pumpAndSettle();
        expect(selected, 29);
        expect(find.byType(PopupMenuItem<int>), findsNothing);
        expect(tester.takeException(), isNull);

        // A new route must own a fresh scroll position after dismissal.
        await tester.tap(find.text('Open menu'));
        await tester.pumpAndSettle();
        expect(find.text('Action 0').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  testWidgets(
    'short action menu keeps natural height at bottom edge',
    (tester) async {
      tester.view.physicalSize = const Size(360, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        _menuApp(
          anchor: const Offset(358, 278),
          count: 2,
          onSelected: (v) => selected = v,
        ),
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      final scrollView = find.byType(SingleChildScrollView);
      expect(tester.getSize(scrollView).height, lessThan(150));
      expect(find.text('Action 0').hitTestable(), findsOneWidget);
      expect(find.text('Action 1').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Action 1'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

Widget _menuApp({
  required Offset anchor,
  required int count,
  required ValueChanged<int?> onSelected,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.macOS),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            onSelected(
              await showAdaptiveActionMenu<int>(
                context: context,
                anchorPosition: anchor,
                items: [
                  for (var index = 0; index < count; index++)
                    AdaptiveActionMenuItem(
                      value: index,
                      label: 'Action $index',
                      startsNewSection: index > 0 && index % 5 == 0,
                    ),
                ],
              ),
            );
          },
          child: const Text('Open menu'),
        ),
      ),
    ),
  ),
);
