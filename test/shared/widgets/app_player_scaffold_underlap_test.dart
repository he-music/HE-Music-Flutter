import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/app_player_scaffold.dart';

void main() {
  for (final hasNavigation in [false, true]) {
    testWidgets(
      'content scrolls behind controls and clears the last row with navigation=$hasNavigation',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var playbackTaps = 0;
        var rowTaps = 0;
        var clearance = 0.0;
        await tester.pumpWidget(
          MaterialApp(
            home: AppPlayerScaffold(
              body: Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(title: const Text('Songs')),
                body: Builder(
                  builder: (context) {
                    clearance = MediaQuery.paddingOf(context).bottom;
                    return ListView.builder(
                      controller: scroll,
                      padding: EdgeInsets.only(bottom: clearance),
                      itemExtent: 64,
                      itemCount: 40,
                      itemBuilder: (context, index) => GestureDetector(
                        key: ValueKey('song-$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => rowTaps++,
                        child: Text('Song $index'),
                      ),
                    );
                  },
                ),
              ),
              miniPlayer: SafeArea(
                top: false,
                bottom: !hasNavigation,
                maintainBottomViewPadding: true,
                child: Padding(
                  key: const ValueKey('playback-clearance'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: GestureDetector(
                    key: const ValueKey('playback'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => playbackTaps++,
                    child: const SizedBox(height: 60, width: double.infinity),
                  ),
                ),
              ),
              navigation: hasNavigation
                  ? const SafeArea(
                      top: false,
                      maintainBottomViewPadding: true,
                      child: SizedBox(height: 64),
                    )
                  : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(ListView));
        final playback = tester.getRect(find.byKey(const ValueKey('playback')));
        final chromeTop = tester
            .getTopLeft(find.byKey(const ValueKey('playback-clearance')))
            .dy;
        expect(viewport.bottom, 844);
        expect(clearance, 844 - chromeTop);

        scroll.jumpTo(200);
        await tester.pumpAndSettle();
        final coveredIndex =
            ((playback.center.dy - viewport.top + scroll.offset) / 64).floor();
        final coveredRow = tester.getRect(
          find.byKey(ValueKey('song-$coveredIndex')),
        );
        expect(coveredRow.contains(playback.center), isTrue);
        await tester.tapAt(playback.center);
        expect(playbackTaps, 1);
        expect(rowTaps, 0);

        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = find.byKey(const ValueKey('song-39'));
        expect(tester.getRect(last).bottom, closeTo(chromeTop, 0.01));
        await tester.tap(last);
        expect(rowTaps, 1);

        tester.view.padding = const FakeViewPadding(top: 24);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('playback'))),
          playback,
        );
        expect(tester.getRect(find.byType(ListView)), viewport);
        expect(clearance, 844 - chromeTop);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
