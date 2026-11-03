import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_progress_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_slider.dart';

void main() {
  testWidgets(
    'Cupertino progress retains buffer track and async seek preview',
    (tester) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
          ),
          home: Scaffold(
            body: PlayerProgressBar(
              position: const Duration(seconds: 10),
              bufferedPosition: const Duration(seconds: 90),
              duration: const Duration(minutes: 3),
              onSeek: (position) async => seeks.add(position),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slider = tester.widget<AppSlider>(
        find.byKey(const ValueKey('player-progress-slider')),
      );
      expect(slider.secondaryTrackValue, 90000);
      expect(find.byType(CupertinoSlider), findsOneWidget);
      final nativeSliderRect = tester.getRect(find.byType(CupertinoSlider));
      final bufferedTrackRect = tester.getRect(
        find.byKey(const ValueKey('app-slider-secondary-track')),
      );
      expect(bufferedTrackRect.width, closeTo(nativeSliderRect.width, 0.01));
      expect(bufferedTrackRect.height, greaterThan(0));
      final semantics = tester.getSemantics(find.byType(AppSlider));
      expect(semantics.value, '00:10');
      slider.onChangeStart!(60000);
      slider.onChanged!(70000);
      await tester.pump();
      expect(find.text('01:10'), findsOneWidget);
      slider.onChangeEnd!(70000);
      await tester.pumpAndSettle();
      expect(seeks, [const Duration(milliseconds: 70000)]);
    },
  );
  testWidgets('Cupertino track drag previews and seeks without paging', (
    tester,
  ) async {
    final seeks = <Duration>[];
    final completion = Completer<void>();
    final pager = PageController();
    addTearDown(pager.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
        ),
        home: Scaffold(
          body: PageView(
            controller: pager,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: PlayerProgressBar(
                  position: const Duration(seconds: 10),
                  bufferedPosition: const Duration(seconds: 90),
                  duration: const Duration(minutes: 3),
                  onSeek: (position) {
                    seeks.add(position);
                    return completion.future;
                  },
                ),
              ),
              const SizedBox.expand(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(CupertinoSlider));
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * .75, rect.center.dy),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveTo(Offset(rect.left + rect.width * .35, rect.center.dy));
    await tester.pump();
    final preview = tester
        .widget<CupertinoSlider>(find.byType(CupertinoSlider))
        .value;
    expect(preview, inInclusiveRange(50000, 80000));
    expect(seeks, isEmpty);
    expect(pager.page, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(seeks, hasLength(1));
    expect(seeks.single.inMilliseconds, closeTo(preview, 1));
    expect(
      tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).value,
      closeTo(preview, 1),
    );
    expect(pager.page, 0);
    completion.complete();
    await tester.pumpAndSettle();
  });
}
