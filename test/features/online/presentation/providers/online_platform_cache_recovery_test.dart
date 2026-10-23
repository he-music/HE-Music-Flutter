import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/data/datasources/online_platform_cache_data_source.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final unauthorized in [false, true]) {
    test(
      'cached metadata loads immediately and ${unauthorized ? 'is cleared on 401' : 'survives network failure'}',
      () async {
        final api = _PendingApi();
        final cache = _Cache();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWith(_Config.new),
            onlineApiClientProvider.overrideWithValue(api),
            onlinePlatformCacheDataSourceProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(container.dispose);
        final platforms = await container.read(onlinePlatformsProvider.future);
        expect(platforms.single.id, 'qq');
        expect(container.read(onlinePlatformSyncProvider).usingCache, isTrue);
        await api.started.future;
        final refresh = container
            .read(onlinePlatformsProvider.notifier)
            .ensureLoaded(forceRefresh: true);
        final check = expectLater(refresh, throwsA(isA<DioException>()));
        final options = RequestOptions(path: '/v1/platforms');
        api.result.completeError(
          DioException(
            requestOptions: options,
            type: unauthorized
                ? DioExceptionType.badResponse
                : DioExceptionType.connectionError,
            response: unauthorized
                ? Response(requestOptions: options, statusCode: 401)
                : null,
          ),
        );
        await check;
        final state = container.read(onlinePlatformsProvider);
        expect(state.hasError, unauthorized);
        if (!unauthorized) expect(state.requireValue.single.id, 'qq');
        expect(cache.cleared, unauthorized);
        expect(
          container.read(onlinePlatformSyncProvider).refreshFailed,
          isTrue,
        );
        expect(api.calls, 1);
      },
    );
  }
  for (final accountChanged in [true, false]) {
    test(
      'a ${accountChanged ? 'new account invalidates old requests' : 'renewed token keeps the active request'}',
      () async {
        final api = _PendingApi();
        final cache = _Cache();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWith(_Config.new),
            onlineApiClientProvider.overrideWithValue(api),
            onlinePlatformCacheDataSourceProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(container.dispose);
        await container.read(onlinePlatformsProvider.future);
        await api.started.future;
        final previous = container
            .read(onlinePlatformsProvider.notifier)
            .ensureLoaded(forceRefresh: true);
        final previousCheck = accountChanged
            ? expectLater(previous, throwsStateError)
            : expectLater(previous, completes);
        (container.read(appConfigProvider.notifier) as _Config).setToken(
          'renewed',
        );
        if (accountChanged) {
          container.invalidate(onlinePlatformsProvider);
          await container.read(onlinePlatformsProvider.future);
          await Future<void>.delayed(Duration.zero);
        }
        final active = container
            .read(onlinePlatformsProvider.notifier)
            .ensureLoaded(forceRefresh: true);
        api.result.complete([
          {
            'id': 'fresh',
            'name': 'Fresh',
            'status': 1,
            'feature_support_flag': '1',
          },
        ]);
        await previousCheck;
        await active;
        expect(
          container.read(onlinePlatformsProvider).requireValue.single.id,
          'fresh',
        );
        expect(api.calls, accountChanged ? 2 : 1);
        expect(cache.writtenScopes, [
          OnlinePlatformCacheDataSource.scopeFor(
            container.read(appConfigProvider).apiBaseUrl,
            'renewed',
          ),
        ]);
      },
    );
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
  @override
  Future<void> waitUntilHydrated() async {}
  void setToken(String token) => state = state.copyWith(authToken: token);
}

class _Cache extends OnlinePlatformCacheDataSource {
  bool cleared = false;
  final writtenScopes = <String>[];
  @override
  Future<void> write(String scope, List<OnlinePlatform> platforms) async {
    writtenScopes.add(scope);
  }

  @override
  Future<List<OnlinePlatform>?> read(String scope) async => [
    OnlinePlatform(
      id: 'qq',
      name: 'QQ',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag: BigInt.one,
    ),
  ];
  @override
  Future<void> clear(String scope) async {
    cleared = true;
  }
}

class _PendingApi extends OnlineApiClient {
  _PendingApi() : super(Dio());
  final result = Completer<List<Map<String, dynamic>>>();
  final started = Completer<void>();
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> fetchPlatforms({
    bool silentErrorMessage = false,
  }) {
    calls++;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}
