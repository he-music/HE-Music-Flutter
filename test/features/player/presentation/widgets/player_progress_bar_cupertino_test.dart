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
}
