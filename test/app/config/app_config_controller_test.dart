import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
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

  test(
    'controller normalizes an unknown skin and persists animation choice',
    () async {
      final dataSource = _RecordingAppConfigDataSource(AppConfigState.initial);
      final container = ProviderContainer(
        overrides: [appConfigDataSourceProvider.overrideWithValue(dataSource)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appConfigProvider.notifier);
      await controller.waitUntilHydrated();

      controller.setSkinId('unknown');
      controller.setEnableSkinAnimation(false);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(appConfigProvider).skinId,
        AppSkinRegistry.classicId,
      );
      expect(container.read(appConfigProvider).enableSkinAnimation, isFalse);
      expect(dataSource.saved.enableSkinAnimation, isFalse);
    },
  );

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
}
