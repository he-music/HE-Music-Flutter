import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_photo_brightness_control.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/lyric_photo_dimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('brightness defaults to original and validates stored values', () async {
    const source = AppConfigDataSource();
    expect((await source.load()).lyricPhotoBrightness, 1);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in {
      -.2: 0.0,
      .35: .35,
      2.0: 1.0,
      double.nan: 1.0,
    }.entries) {
      await prefs.setDouble('app_config.lyric_photo_brightness', entry.key);
      expect((await source.load()).lyricPhotoBrightness, entry.value);
    }
    await prefs.setString('app_config.lyric_photo_brightness', 'invalid');
    expect((await source.load()).lyricPhotoBrightness, 1);
  });

  test(
    'brightness survives backdrop changes and a new config controller',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      final controller = first.read(appConfigProvider.notifier);
      await controller.waitUntilHydrated();
      controller.setLyricPhotoBrightness(.4);
      controller.setPlayerBackdropId(AppPlayerBackdropRegistry.artistPhotoId);
      controller.setPlayerBackdropId(AppPlayerBackdropRegistry.coverGradientId);
      // The controller serializes saves; allow its local persistence queue to drain.
      await pumpEventQueue();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(appConfigProvider.notifier).waitUntilHydrated();
      expect(second.read(appConfigProvider).lyricPhotoBrightness, .4);
      expect(
        second.read(appConfigProvider).playerBackdropId,
        AppPlayerBackdropRegistry.coverGradientId,
      );
      second.read(appConfigProvider.notifier).setLyricPhotoBrightness(1);
      await pumpEventQueue();
      expect(
        (await const AppConfigDataSource().load()).lyricPhotoBrightness,
        1,
      );
    },
  );

  testWidgets('slider previews only the mask and commits on release', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(appConfigProvider.notifier).waitUntilHydrated(),
    );
    var contentBuilds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: LyricPhotoDimmer()),
                Builder(
                  builder: (_) {
                    contentBuilds++;
                    return const LyricPhotoBrightnessControl();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    double opacity() => tester
        .widget<ColoredBox>(find.byKey(const ValueKey('lyric-photo-dimmer')))
        .color
        .a;
    expect(opacity(), 0);
    final builds = contentBuilds;
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0);
    await tester.pump();
    expect(opacity(), closeTo(.75, .005));
    expect(contentBuilds, builds);
    expect((await const AppConfigDataSource().load()).lyricPhotoBrightness, 1);
    await tester.runAsync(() async {
      slider.onChangeEnd!(0);
      await pumpEventQueue();
    });
    expect((await const AppConfigDataSource().load()).lyricPhotoBrightness, 0);
    slider.onChanged!(1);
    await tester.pump();
    expect(opacity(), 0);
    await tester.runAsync(() async {
      slider.onChangeEnd!(1);
      await pumpEventQueue();
    });
  });

  testWidgets(
    'portrait cover stays original and lyrics dim with page movement',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWith(_DimConfig.new)],
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(
                  child: LyricPhotoDimmer(pageController: controller),
                ),
                PageView(
                  controller: controller,
                  children: const [
                    Center(child: Text('Cover')),
                    Center(child: Text('Lyrics')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      double opacity() => tester
          .widget<ColoredBox>(find.byKey(const ValueKey('lyric-photo-dimmer')))
          .color
          .a;
      expect(opacity(), 0);
      controller.jumpToPage(1);
      await tester.pump();
      expect(opacity(), closeTo(.75, .005));
      controller.jumpToPage(0);
      await tester.pump();
      expect(opacity(), 0);
    },
  );
}

class _DimConfig extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(lyricPhotoBrightness: 0);
}
