import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_rive_animation.dart';
import 'package:rive/rive.dart' as rive;

const _descriptor = AppSkinRiveAnimationDescriptor(
  asset: AppSkinAssetDescriptor(
    path: 'assets/skins/city_sound_creator/ambient.riv',
    type: AppSkinAssetType.rive,
  ),
  artboard: 'CitySoundAmbient',
  stateMachine: 'AmbientLoop',
  fit: BoxFit.cover,
  alignment: Alignment(0.36, -0.12),
  opacity: 0.92,
);

void main() {
  testWidgets('disabled and reduced motion states do not load Rive', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    final resolver = _CountingFailureResolver();

    await tester.pumpWidget(_testApp(resolver: resolver, enabled: false));
    await tester.pump();
    expect(resolver.loadCount, 0);

    await tester.pumpWidget(
      _testApp(resolver: resolver, disableAnimations: true),
    );
    await tester.pump();
    expect(resolver.loadCount, 0);
    expect(find.byType(rive.RiveWidget), findsNothing);
  });

  testWidgets('asset failure keeps the static background fallback', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    final resolver = _CountingFailureResolver();

    await tester.pumpWidget(_testApp(resolver: resolver));
    await tester.pump();
    await tester.pump();

    expect(resolver.loadCount, 1);
    expect(find.byType(rive.RiveWidget), findsNothing);
  });

  testWidgets('bundled Rive pauses without recreating its controller', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    final resolver = _BundledRiveResolver();

    await tester.pumpWidget(_testApp(resolver: resolver));
    final controller = await _waitForController(tester);
    final riveWidget = tester.widget<rive.RiveWidget>(
      find.byKey(const ValueKey<String>('app-skin-rive-widget')),
    );
    expect(riveWidget.fit, rive.Fit.cover);
    expect(riveWidget.alignment, const Alignment(0.36, -0.12));
    expect(controller.active, isTrue);
    expect(resolver.loadCount, 1);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    expect(controller.active, isFalse);
    expect(find.byType(rive.RiveWidget), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();
    expect(controller.active, isTrue);
    expect(
      tester
          .widget<rive.RiveWidget>(
            find.byKey(const ValueKey<String>('app-skin-rive-widget')),
          )
          .controller,
      same(controller),
    );
    expect(resolver.loadCount, 1);

    await tester.pumpWidget(
      _testApp(resolver: resolver, disableAnimations: true),
    );
    await tester.pump();
    expect(controller.active, isFalse);
    expect(find.byType(rive.RiveWidget), findsNothing);

    await tester.pumpWidget(_testApp(resolver: resolver));
    await tester.pump();
    expect(controller.active, isTrue);
    expect(
      tester
          .widget<rive.RiveWidget>(
            find.byKey(const ValueKey<String>('app-skin-rive-widget')),
          )
          .controller,
      same(controller),
    );
    expect(resolver.loadCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _testApp({
  required AppSkinAssetResolver resolver,
  bool enabled = true,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: AppSkinRiveAnimation(
        descriptor: _descriptor,
        assetResolver: resolver,
        enabled: enabled,
      ),
    ),
  );
}

Future<rive.RiveWidgetController> _waitForController(
  WidgetTester tester,
) async {
  final finder = find.byKey(const ValueKey<String>('app-skin-rive-widget'));
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(finder, findsOneWidget);
  return tester.widget<rive.RiveWidget>(finder).controller;
}

class _CountingFailureResolver implements AppSkinAssetResolver {
  var loadCount = 0;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    loadCount += 1;
    return AppSkinAssetLoadFailure(StateError('missing'));
  }
}

class _BundledRiveResolver implements AppSkinAssetResolver {
  var loadCount = 0;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    loadCount += 1;
    final bytes = await File(descriptor.path).readAsBytes();
    return AppSkinAssetLoadSuccess(ByteData.sublistView(bytes));
  }
}
