import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/skin_selection_page.dart';

void main() {
  testWidgets('catalog shows light previews and the currently applied skin', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('skin-preview-light')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey<String>('skin-preview-dark')),
      findsNothing,
    );
    expect(find.text('当前使用').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('apply-skin-button')),
      findsNothing,
    );
  });

  testWidgets('detail shows both previews and applies the selected skin', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-city_sound_creator')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('skin-preview-light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('skin-preview-dark')),
      findsOneWidget,
    );
    expect(find.text('珊瑚红、青绿与中性工作室声场'), findsOneWidget);
    expect(container.read(appConfigProvider).skinId, AppSkinRegistry.classicId);

    await tester.tap(find.byKey(const ValueKey<String>('apply-skin-button')));
    await tester.pump();
    expect(
      container.read(appConfigProvider).skinId,
      AppSkinRegistry.citySoundCreatorId,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('apply-skin-button')),
        matching: find.text('当前使用'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('apply-skin-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('当前使用').hitTestable(), findsOneWidget);
  });

  testWidgets('catalog exposes one create slot and opens the image editor', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('create-custom-skin')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-custom-skin')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('choose-custom-skin-image')),
      findsOneWidget,
    );
  });

  testWidgets('saved custom skin replaces the create slot with one entry', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_CustomAppConfigController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        SkinSelectionPage(assetResolver: _PreviewResolver()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('create-custom-skin')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('skin-choice-custom_image')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Image>(
            find.byKey(
              const ValueKey<String>('skin-preview-image-custom_image-light'),
            ),
          )
          .alignment,
      const Alignment(0.25, -0.5),
    );
  });

  testWidgets('saved custom editor exposes previews, swatches, and commands', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_CustomAppConfigController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        SkinSelectionPage(assetResolver: _PreviewResolver()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-custom_image')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('custom-preview-light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-preview-dark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('swap-custom-skin-brightness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('replace-custom-skin-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('delete-custom-skin')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('apply-custom-skin')),
          )
          .onPressed,
      isNull,
    );

    final secondSwatch = find.byKey(
      const ValueKey<String>('custom-skin-color-4286023841'),
    );
    await tester.ensureVisible(secondSwatch);
    await tester.pump();
    await tester.tap(secondSwatch);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('apply-custom-skin')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey<String>('delete-custom-skin')));
    await tester.pumpAndSettle();
    expect(find.text('删除自定义皮肤？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved custom skin can be reapplied without editing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_CustomAppConfigController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        SkinSelectionPage(assetResolver: _PreviewResolver()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-city_sound_creator')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('apply-skin-button')));
    await tester.pump();
    expect(
      container.read(appConfigProvider).skinId,
      AppSkinRegistry.citySoundCreatorId,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-custom_image')),
    );
    await tester.pumpAndSettle();

    final applyButton = find.byKey(const ValueKey<String>('apply-custom-skin'));
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNotNull);

    await tester.tap(applyButton);
    await tester.pump();
    expect(
      container.read(appConfigProvider).skinId,
      AppSkinRegistry.customImageId,
    );
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);
  });

  testWidgets('starlit detail uses product copy and can be applied', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-starlit_melody')),
    );
    await tester.pumpAndSettle();

    expect(find.text('穿行于清晨云海与璀璨星夜之间的旋律列车'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('apply-skin-button')));
    await tester.pump();
    expect(
      container.read(appConfigProvider).skinId,
      AppSkinRegistry.starlitMelodyId,
    );
  });

  testWidgets('back from detail keeps the applied skin unchanged', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-city_sound_creator')),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).skinId, AppSkinRegistry.classicId);
  });

  testWidgets('production previews load through metadata resolver', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    final resolver = _PreviewResolver();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, SkinSelectionPage(assetResolver: resolver)),
    );
    await tester.pumpAndSettle();

    const skinIds = <String>[
      AppSkinRegistry.classicId,
      AppSkinRegistry.citySoundCreatorId,
      AppSkinRegistry.starlitMelodyId,
    ];
    for (final skinId in skinIds) {
      expect(
        find.byKey(ValueKey<String>('skin-preview-image-$skinId-light')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('skin-preview-image-$skinId-dark')),
        findsNothing,
      );
    }

    for (final skinId in skinIds) {
      await tester.tap(find.byKey(ValueKey<String>('skin-choice-$skinId')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey<String>('skin-preview-image-$skinId-dark')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    expect(
      resolver.paths,
      unorderedEquals(<String>[
        for (final skinId in skinIds) ...<String>[
          'assets/skins/$skinId/preview_light.png',
          'assets/skins/$skinId/preview_light.png',
          'assets/skins/$skinId/preview_dark.png',
        ],
      ]),
    );
  });

  testWidgets('preview load failure keeps the live fallback', (tester) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        const SkinSelectionPage(assetResolver: _FailingPreviewResolver()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-light'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-dark'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-image-city_sound_creator-light'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-city_sound_creator')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-light'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-dark'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preview loading does not mount the wallpaper fallback', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    final resolver = _PendingPreviewResolver();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(container, SkinSelectionPage(assetResolver: resolver)),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-light'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-dark'),
      ),
      findsNothing,
    );

    resolver.completeWithFailure();
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-light'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-starlit_melody-light'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('catalog and detail fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        SkinSelectionPage(assetResolver: _PreviewResolver()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('skin-preview-light')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey<String>('skin-preview-dark')),
      findsNothing,
    );
    final classicRect = tester.getRect(
      find.byKey(const ValueKey<String>('skin-choice-classic')),
    );
    final cityRect = tester.getRect(
      find.byKey(const ValueKey<String>('skin-choice-city_sound_creator')),
    );
    final starlitRect = tester.getRect(
      find.byKey(const ValueKey<String>('skin-choice-starlit_melody')),
    );
    expect(classicRect.top, cityRect.top);
    expect(starlitRect.top, greaterThan(classicRect.bottom));
    expect(starlitRect.bottom, lessThanOrEqualTo(640));

    await tester.tap(
      find.byKey(const ValueKey<String>('skin-choice-starlit_melody')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('skin-preview-light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('skin-preview-dark')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('skin-preview-light')))
          .width,
      lessThanOrEqualTo(138),
    );
    expect(
      find.byKey(const ValueKey<String>('apply-skin-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog remains stable with large system text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: const SkinSelectionPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('skin-choice-starlit_melody')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _buildApp(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: home),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  @override
  void setSkinId(String skinId) {
    state = state.copyWith(skinId: skinId);
  }
}

class _CustomAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    skinId: AppSkinRegistry.customImageId,
    customSkinConfig: AppCustomSkinConfig(
      revision: 'revision_1',
      lightAssetPath: 'skins/custom_image/revision_1/wallpaper_light.jpg',
      darkAssetPath: 'skins/custom_image/revision_1/wallpaper_dark.jpg',
      candidateColors: const <int>[0xFF336699, 0xFF7788A1],
      seedColor: 0xFF336699,
      focalX: 0.25,
      focalY: -0.5,
      sourceWidth: 1200,
      sourceHeight: 1600,
    ),
  );

  @override
  void setSkinId(String skinId) {
    state = state.copyWith(skinId: skinId);
  }
}

class _PreviewResolver implements AppSkinAssetResolver {
  static final _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );

  final paths = <String>[];

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    paths.add(descriptor.path);
    return AppSkinAssetLoadSuccess(ByteData.sublistView(_pngBytes));
  }
}

class _FailingPreviewResolver implements AppSkinAssetResolver {
  const _FailingPreviewResolver();

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    return AppSkinAssetLoadFailure(StateError('missing preview'));
  }
}

class _PendingPreviewResolver implements AppSkinAssetResolver {
  final _result = Completer<AppSkinAssetLoadResult>();

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) {
    return _result.future;
  }

  void completeWithFailure() {
    _result.complete(AppSkinAssetLoadFailure(StateError('missing preview')));
  }
}
