import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/widgets/scroll_to_top_overlay.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets(
      '${grid ? 'grid' : 'list'} returns to top without rebuilding content',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var builds = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appConfigProvider.overrideWith(_TestConfig.new)],
            child: MaterialApp(
              home: Scaffold(
                body: ScrollToTopOverlay(
                  controller: controller,
                  child: Builder(
                    builder: (context) {
                      builds++;
                      return grid
                          ? GridView.builder(
                              controller: controller,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisExtent: 80,
                                  ),
                              itemCount: 200,
                              itemBuilder: (_, index) => Text('item $index'),
                            )
                          : ListView.builder(
                              controller: controller,
                              itemExtent: 64,
                              itemCount: 100,
                              itemBuilder: (_, index) => Text('item $index'),
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byTooltip('回到顶部').hitTestable();
        expect(button, findsNothing);
        final initialBuilds = builds;
        controller.jumpTo(controller.position.viewportDimension * 3);
        await tester.pumpAndSettle();
        expect(button, findsOneWidget);
        expect(builds, initialBuilds);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.minScrollExtent);
        expect(button, findsNothing);
        expect(builds, initialBuilds);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _TestConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');
}
