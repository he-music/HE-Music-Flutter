import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('平台 Provider 被提前读取时仍应等待配置水合', () async {
    final dataSource = _DelayedAppConfigDataSource();
    final apiClient = _DelayedOnlineApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(dataSource),
        onlineApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(container.dispose);

    final initialLoad = container.read(onlinePlatformsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(apiClient.fetchPlatformsCallCount, 0);

    dataSource.complete(AppConfigState.initial);
    await apiClient.requestStarted.future;
    expect(apiClient.fetchPlatformsCallCount, 1);

    apiClient.complete();
    await initialLoad;
  });

  test('首次加载期间的刷新应复用同一个平台请求', () async {
    final apiClient = _DelayedOnlineApiClient();
    final container = ProviderContainer(
      overrides: [onlineApiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);

    final initialLoad = container.read(onlinePlatformsProvider.future);
    await apiClient.requestStarted.future;

    final refresh = container
        .read(onlinePlatformsProvider.notifier)
        .ensureLoaded(forceRefresh: true);

    expect(apiClient.fetchPlatformsCallCount, 1);

    apiClient.complete();
    final results = await Future.wait([initialLoad, refresh]);

    expect(results, everyElement(hasLength(1)));
    expect(apiClient.fetchPlatformsCallCount, 1);
  });

  test('首次加载失败时并发等待者应共享同一个平台请求和错误', () async {
    final apiClient = _DelayedOnlineApiClient();
    final container = ProviderContainer(
      overrides: [onlineApiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);

    final initialLoad = container.read(onlinePlatformsProvider.future);
    await apiClient.requestStarted.future;
    final ensureLoaded = container
        .read(onlinePlatformsProvider.notifier)
        .ensureLoaded();
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/platforms'),
      type: DioExceptionType.connectionError,
    );
    final initialExpectation = expectLater(initialLoad, throwsA(error));
    final ensureExpectation = expectLater(ensureLoaded, throwsA(error));

    apiClient.completeError(error);

    await Future.wait(<Future<void>>[initialExpectation, ensureExpectation]);
    expect(apiClient.fetchPlatformsCallCount, 1);
    expect(container.read(onlinePlatformsProvider).error, error);
  });
}

class _DelayedAppConfigDataSource extends AppConfigDataSource {
  final Completer<AppConfigState> _loaded = Completer<AppConfigState>();

  @override
  Future<AppConfigState> load() => _loaded.future;

  void complete(AppConfigState config) {
    _loaded.complete(config);
  }
}

class _DelayedOnlineApiClient extends OnlineApiClient {
  _DelayedOnlineApiClient() : super(Dio());

  final requestStarted = Completer<void>();
  final _response = Completer<List<Map<String, dynamic>>>();
  int fetchPlatformsCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlatforms({
    bool silentErrorMessage = false,
  }) {
    fetchPlatformsCallCount += 1;
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    return _response.future;
  }

  void complete() {
    _response.complete(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'qq',
        'name': 'QQ',
        'shortname': 'QQ',
        'status': 1,
        'feature_support_flag': PlatformFeatureSupportFlag.getDiscoverPage,
      },
    ]);
  }

  void completeError(Object error) {
    _response.completeError(error);
  }
}
