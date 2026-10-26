import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final usePointerPosition in [true, false]) {
    testWidgets(
      'glass menu preserves ${usePointerPosition ? 'pointer' : 'widget'} anchor across nested navigator',
      (tester) async {
        tester.view.physicalSize = const Size(500, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _nestedMenuApp(
            count: 2,
            usePointerPosition: usePointerPosition,
            onSelected: (_) {},
          ),
        );
        final buttonRect = tester.getRect(find.byKey(const Key('trigger')));
        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        final anchor = usePointerPosition
            ? buttonRect.center
            : buttonRect.topLeft;
        // GlassMenu content has 12px horizontal inset; the point trigger is 1px.
        expect(viewport.left, closeTo(anchor.dx + 11.5, 1));
        expect(viewport.top, closeTo(anchor.dy - 0.5, 1));
        expect(find.text('Nested action 1').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  testWidgets(
    'long glass menu can select last action above root bottom chrome',
    (tester) async {
      tester.view.physicalSize = const Size(500, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        _nestedMenuApp(
          count: 30,
          usePointerPosition: true,
          onSelected: (v) => selected = v,
        ),
      );
      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nested action 29'),
        180,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      final lastAction = find.text('Nested action 29');
      final chromeRect = tester.getRect(find.byKey(const Key('bottom-chrome')));
      expect(tester.getCenter(lastAction).dy, greaterThan(chromeRect.top));
      expect(lastAction.hitTestable(), findsOneWidget);
      await tester.tap(lastAction);
      await tester.pumpAndSettle();
      expect(selected, 29);
      expect(find.byType(GlassMenu), findsNothing);
      expect(find.byKey(const Key('bottom-chrome')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

Widget _nestedMenuApp({
  required int count,
  required bool usePointerPosition,
  required ValueChanged<int?> onSelected,
}) => AppGlassScope(
  enabled: true,
  mode: AppGlassMode.low,
  child: GlassAdaptiveScope(
    minQuality: GlassQuality.minimal,
    maxQuality: GlassQuality.minimal,
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: GlassScaffold(
        body: Stack(
          children: [
            Positioned(
              left: 40,
              top: 30,
              right: 40,
              bottom: 30,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 40, top: 20),
                      child: Builder(
                        builder: (anchorContext) => TextButton(
                          key: const Key('trigger'),
                          onPressed: () async {
                            final box =
                                anchorContext.findRenderObject()! as RenderBox;
                            onSelected(
                              await showAdaptiveActionMenu<int>(
                                context: context,
                                anchorContext: anchorContext,
                                anchorPosition: usePointerPosition
                                    ? box.localToGlobal(
                                        box.size.center(Offset.zero),
                                      )
                                    : null,
                                items: [
                                  for (var index = 0; index < count; index++)
                                    AdaptiveActionMenuItem(
                                      value: index,
                                      label: 'Nested action $index',
                                    ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Open nested menu'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: AbsorbPointer(
                key: const Key('bottom-chrome'),
                child: ColoredBox(
                  color: Colors.blue,
                  child: const Center(child: Text('Root bottom chrome')),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
