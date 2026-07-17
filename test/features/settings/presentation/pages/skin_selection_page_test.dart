import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/skin_selection_page.dart';

void main() {
  testWidgets('candidate and preview brightness stay local until apply', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container, const SkinSelectionPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('城市声场创作者'));
    await tester.pump();
    expect(container.read(appConfigProvider).skinId, AppSkinRegistry.classicId);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('skin-preview-dark')),
      findsNWidgets(2),
    );
    expect(container.read(appConfigProvider).themeMode.name, 'system');

    await tester.tap(find.byKey(const ValueKey<String>('apply-skin-button')));
    await tester.pump();
    expect(
      container.read(appConfigProvider).skinId,
      AppSkinRegistry.citySoundCreatorId,
    );
  });

  testWidgets('back discards an unapplied candidate', (tester) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildApp(
        container,
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const SkinSelectionPage(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('城市声场创作者'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
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

    expect(resolver.paths, <String>[
      'assets/skins/city_sound_creator/preview_light.png',
    ]);
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-image-city_sound_creator-light'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(resolver.paths, <String>[
      'assets/skins/city_sound_creator/preview_light.png',
      'assets/skins/city_sound_creator/preview_dark.png',
    ]);
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-image-city_sound_creator-dark'),
      ),
      findsOneWidget,
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
        const ValueKey<String>('skin-preview-image-city_sound_creator-light'),
      ),
      findsNothing,
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

    resolver.completeWithFailure();
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('skin-preview-live-city_sound_creator-light'),
      ),
      findsOneWidget,
    );
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
