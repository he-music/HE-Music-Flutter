import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_custom_skin_store.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/core/network/token_refresh_interceptor.dart';

void main() {
  setUp(() {
    globalTokenHolder
      ..accessToken = null
      ..refreshToken = null
      ..expiresAt = null;
  });

  test(
    'controller switches skins without changing the manual accent',
    () async {
      final dataSource = _RecordingAppConfigDataSource(
        AppConfigState.initial.copyWith(themeAccent: AppThemeAccent.rose),
      );
      final container = ProviderContainer(
        overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appConfigProvider.notifier);
      await controller.waitUntilHydrated();

      controller.setSkinId(AppSkinRegistry.citySoundCreatorId);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appConfigProvider).skinId,
        AppSkinRegistry.citySoundCreatorId,
      );
      controller.setSkinId(AppSkinRegistry.starlitMelodyId);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appConfigProvider).skinId,
        AppSkinRegistry.starlitMelodyId,
      );
      controller.setSkinId(AppSkinRegistry.classicId);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(appConfigProvider).skinId,
        AppSkinRegistry.classicId,
      );
      expect(
        container.read(appConfigProvider).themeAccent,
        AppThemeAccent.rose,
      );
      expect(dataSource.saved.themeAccent, AppThemeAccent.rose);
    },
  );

  test('controller persists global skin display preferences', () async {
    final dataSource = _RecordingAppConfigDataSource(AppConfigState.initial);
    final container = ProviderContainer(
      overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appConfigProvider.notifier);
    await controller.waitUntilHydrated();

    controller.setSkinId('unknown');
    controller.setEnableSkinAnimation(false);
    controller.setShowContentBackground(true);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(appConfigProvider).skinId, AppSkinRegistry.classicId);
    expect(container.read(appConfigProvider).enableSkinAnimation, isFalse);
    expect(container.read(appConfigProvider).showContentBackground, isTrue);
    expect(dataSource.saved.enableSkinAnimation, isFalse);
    expect(dataSource.saved.showContentBackground, isTrue);
  });

  test('controller normalizes and persists player style ids', () async {
    final dataSource = _RecordingAppConfigDataSource(AppConfigState.initial);
    final container = ProviderContainer(
      overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appConfigProvider.notifier);
    await controller.waitUntilHydrated();

    controller.setPlayerStyleId(AppPlayerStyleRegistry.cassetteId);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appConfigProvider).playerStyleId,
      AppPlayerStyleRegistry.cassetteId,
    );

    controller.setPlayerStyleId('removed');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appConfigProvider).playerStyleId,
      AppPlayerStyleRegistry.classicId,
    );
    expect(dataSource.saved.playerStyleId, AppPlayerStyleRegistry.classicId);
  });

  test('controller persists download acceleration preferences', () async {
    final dataSource = _RecordingAppConfigDataSource(AppConfigState.initial);
    final container = ProviderContainer(
      overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appConfigProvider.notifier);
    await controller.waitUntilHydrated();

    controller.setGitHubDownloadAccelerationEnabled(true);
    controller.setGitHubDownloadProxyAutoUpdateEnabled(false);
    controller.setGitHubDownloadProxyId(' proxy-1 ');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(appConfigProvider).githubDownloadAccelerationEnabled,
      isTrue,
    );
    expect(
      container.read(appConfigProvider).githubDownloadProxyAutoUpdateEnabled,
      isFalse,
    );
    expect(container.read(appConfigProvider).githubDownloadProxyId, 'proxy-1');
    expect(dataSource.saved.githubDownloadProxyAutoUpdateEnabled, isFalse);
    expect(dataSource.saved.githubDownloadProxyId, 'proxy-1');

    controller.setGitHubDownloadProxyId(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appConfigProvider).githubDownloadProxyId, isNull);
    expect(dataSource.saved.githubDownloadProxyId, isNull);
  });

  test(
    'hydrate clears damaged custom resources and falls back to classic',
    () async {
      final dataSource = _RecordingAppConfigDataSource(
        AppConfigState.initial.copyWith(
          skinId: AppSkinRegistry.customImageId,
          customSkinConfig: _customConfig(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(dataSource),
          appCustomSkinStoreProvider.overrideWithValue(
            _FakeCustomSkinStore(valid: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appConfigProvider.notifier).waitUntilHydrated();

      expect(
        container.read(appConfigProvider).skinId,
        AppSkinRegistry.classicId,
      );
      expect(container.read(appConfigProvider).customSkinConfig, isNull);
      expect(dataSource.invalidCustomCleared, isTrue);
    },
  );

  test('apply custom skin preserves manual accent and player style', () async {
    final dataSource = _RecordingAppConfigDataSource(
      AppConfigState.initial.copyWith(
        themeAccent: AppThemeAccent.rose,
        playerStyleId: AppPlayerStyleRegistry.vinylId,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(dataSource),
        appCustomSkinStoreProvider.overrideWithValue(
          _FakeCustomSkinStore(valid: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(appConfigProvider.notifier);
    await controller.waitUntilHydrated();

    await controller.applyCustomSkin(_customConfig());

    final state = container.read(appConfigProvider);
    expect(state.skinId, AppSkinRegistry.customImageId);
    expect(state.customSkinConfig, _customConfig());
    expect(state.themeAccent, AppThemeAccent.rose);
    expect(state.playerStyleId, AppPlayerStyleRegistry.vinylId);
  });

  test(
    'config updates queued during custom apply persist the committed skin',
    () async {
      final dataSource = _BlockingReplaceAppConfigDataSource(
        AppConfigState.initial,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(dataSource),
          appCustomSkinStoreProvider.overrideWithValue(
            _FakeCustomSkinStore(valid: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appConfigProvider.notifier);
      await controller.waitUntilHydrated();

      final applying = controller.applyCustomSkin(_customConfig());
      await dataSource.replaceStarted.future;
      controller.setThemeAccent(AppThemeAccent.rose);
      dataSource.allowReplace.complete();
      await applying;
      await Future<void>.delayed(Duration.zero);

      expect(dataSource.saved.skinId, AppSkinRegistry.customImageId);
      expect(dataSource.saved.customSkinConfig, _customConfig());
      expect(dataSource.saved.themeAccent, AppThemeAccent.rose);
    },
  );

  test(
    'unrelated config updates preserve tokens refreshed outside Riverpod',
    () async {
      final dataSource = _RecordingAppConfigDataSource(
        AppConfigState.initial.copyWith(
          authToken: 'expired-token',
          refreshToken: 'old-refresh-token',
          tokenExpiresAt: 1,
        ),
      );
      final container = ProviderContainer(
        overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appConfigProvider.notifier);
      await controller.waitUntilHydrated();
      globalTokenHolder
        ..accessToken = 'fresh-token'
        ..refreshToken = 'fresh-refresh-token'
        ..expiresAt = 123;

      controller.setThemeAccent(AppThemeAccent.rose);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(appConfigProvider);
      expect(state.authToken, 'fresh-token');
      expect(state.refreshToken, 'fresh-refresh-token');
      expect(state.tokenExpiresAt, 123);
      expect(dataSource.saved.authToken, 'fresh-token');
      expect(dataSource.saved.refreshToken, 'fresh-refresh-token');
      expect(dataSource.saved.tokenExpiresAt, 123);
    },
  );
}

class _RecordingAppConfigDataSource extends AppConfigDataSource {
  _RecordingAppConfigDataSource(this.loaded) : saved = loaded;

  final AppConfigState loaded;
  AppConfigState saved;
  bool invalidCustomCleared = false;

  @override
  Future<AppConfigState> load() async => loaded;

  @override
  Future<void> save(AppConfigState state) async {
    saved = state;
  }

  @override
  Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    int expiresAt,
  ) async {
    saved = saved.copyWith(
      authToken: accessToken,
      refreshToken: refreshToken,
      tokenExpiresAt: expiresAt,
    );
  }

  @override
  Future<void> replaceCustomSkin(AppCustomSkinConfig config) async {
    saved = saved.copyWith(
      skinId: AppSkinRegistry.customImageId,
      customSkinConfig: config,
    );
  }

  @override
  Future<String> deleteCustomSkin() async {
    saved = saved.copyWith(
      skinId: saved.skinId == AppSkinRegistry.customImageId
          ? AppSkinRegistry.classicId
          : saved.skinId,
      clearCustomSkinConfig: true,
    );
    return saved.skinId;
  }

  @override
  Future<void> clearInvalidCustomSkin({required bool fallbackToClassic}) async {
    invalidCustomCleared = true;
    saved = saved.copyWith(
      skinId: fallbackToClassic ? AppSkinRegistry.classicId : saved.skinId,
      clearCustomSkinConfig: true,
    );
  }
}

class _BlockingReplaceAppConfigDataSource
    extends _RecordingAppConfigDataSource {
  _BlockingReplaceAppConfigDataSource(super.loaded);

  final replaceStarted = Completer<void>();
  final allowReplace = Completer<void>();

  @override
  Future<void> replaceCustomSkin(AppCustomSkinConfig config) async {
    replaceStarted.complete();
    await allowReplace.future;
    await super.replaceCustomSkin(config);
  }
}

class _FakeCustomSkinStore extends AppCustomSkinStore {
  _FakeCustomSkinStore({required this.valid})
    : super(applicationSupportDirectory: () async => Directory.systemTemp);

  final bool valid;

  @override
  Future<bool> validateConfig(AppCustomSkinConfig config) async => valid;

  @override
  Future<void> cleanupOrphans(AppCustomSkinConfig? current) async {}

  @override
  Future<void> deleteAll() async {}
}

AppCustomSkinConfig _customConfig() {
  return AppCustomSkinConfig(
    revision: 'revision_1',
    lightAssetPath: 'skins/custom_image/revision_1/wallpaper_light.jpg',
    darkAssetPath: 'skins/custom_image/revision_1/wallpaper_dark.jpg',
    candidateColors: const <int>[0xFF123456],
    seedColor: 0xFF123456,
    focalX: 0,
    focalY: 0,
    sourceWidth: 1200,
    sourceHeight: 1600,
  );
}
