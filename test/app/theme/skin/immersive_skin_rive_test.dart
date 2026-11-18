import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/forest_sanctuary_skin.dart';
import 'package:he_music_flutter/app/theme/skins/tidal_sanctuary_skin.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  for (final skin in [forestSanctuarySkin(), tidalSanctuarySkin()]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${skin.metadata.id} $brightness uses bundled Rive and preserves its controller',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final resolver = _Resolver();
          final prefix = skin.metadata.id == 'forest_sanctuary'
              ? 'Forest'
              : 'Tidal';
          final descriptor =
              skin.configFor(brightness).background.animation
                  as AppSkinRiveAnimationDescriptor;
          expect(
            descriptor.artboard,
            brightness == Brightness.dark ? '${prefix}Night' : '${prefix}Day',
          );
          expect(descriptor.stateMachine, 'AmbientLoop');

          Widget host({
            bool enabled = true,
            bool reduced = false,
            bool visible = true,
          }) => MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark(skin)
                : AppTheme.light(skin),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: visible,
                child: AppSkinBackgroundLayer(
                  skin: skin,
                  enableAnimation: enabled,
                  assetResolver: resolver,
                ),
              ),
            ),
          );

          await tester.pumpWidget(host(enabled: false));
          await tester.pump();
          expect(resolver.riveLoads, 0);
          await tester.pumpWidget(host(reduced: true));
          await tester.pump();
          expect(resolver.riveLoads, 0);
          await tester.pumpWidget(host());
          final finder = find.byKey(const ValueKey('app-skin-rive-widget'));
          for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(finder, findsOneWidget);
          final widget = tester.widget<rive.RiveWidget>(finder);
          final controller = widget.controller;
          expect(widget.fit, rive.Fit.cover);
          expect(widget.alignment, Alignment.center);
          expect(controller.active, isTrue);
          expect(resolver.riveLoads, 1);
          // Cross each skin's full timeline (24s / 36s), then verify resuming.
          for (var frame = 0; frame < 74; frame++) {
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
          }

          await tester.pumpWidget(host(enabled: false));
          await tester.pump();
          expect(controller.active, isFalse);
          expect(finder, findsNothing);
          final backgroundContext = tester.element(
            find.byType(AppSkinBackgroundLayer),
          );
          expect(MediaQuery.disableAnimationsOf(backgroundContext), isFalse);
          await tester.pumpWidget(host());
          await tester.pump();
          expect(
            tester.widget<rive.RiveWidget>(finder).controller,
            same(controller),
          );

          await tester.pumpWidget(host(reduced: true));
          await tester.pump();
          expect(controller.active, isFalse);
          await tester.pumpWidget(host());
          await tester.pump();
          expect(controller.active, isTrue);

          await tester.pumpWidget(host(visible: false));
          await tester.pump();
          expect(controller.active, isFalse);
          await tester.pumpWidget(host());
          await tester.pump();
          expect(controller.active, isTrue);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          expect(controller.active, isFalse);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(
            tester.widget<rive.RiveWidget>(finder).controller,
            same(controller),
          );
          expect(controller.active, isTrue);
          expect(resolver.riveLoads, 1);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Resolver implements AppSkinAssetResolver {
  var riveLoads = 0;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    if (descriptor.type != AppSkinAssetType.rive) {
      // 壁纸失败时仍应保留后备底色，并独立加载动画。
      return AppSkinAssetLoadFailure(StateError('wallpaper omitted by test'));
    }
    riveLoads++;
    final bytes = await File(descriptor.path).readAsBytes();
    return AppSkinAssetLoadSuccess(ByteData.sublistView(bytes));
  }
}
