import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/startup/app_startup_provider.dart';
import 'package:he_music_flutter/core/network/token_refresh_interceptor.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppEnvironment.initialize);

  setUp(() {
    globalTokenHolder.accessToken = null;
    globalTokenHolder.refreshToken = null;
    globalTokenHolder.expiresAt = null;
  });

  tearDown(() {
    globalTokenHolder.accessToken = null;
    globalTokenHolder.refreshToken = null;
    globalTokenHolder.expiresAt = null;
  });

  test('平台请求应等待配置和 token 水合完成', () async {
    final dataSource = _DelayedAppConfigDataSource();
    final apiClient = _RecordingOnlineApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(dataSource),
        onlineApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(container.dispose);

    final startup = container.read(appStartupProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(apiClient.fetchPlatformsCallCount, 0);

    dataSource.complete(
      AppConfigState.initial.copyWith(
        authToken: 'saved-access-token',
        refreshToken: 'saved-refresh-token',
        tokenExpiresAt: 123,
      ),
    );
    await startup;

    final config = container.read(appConfigProvider);
    expect(config.authToken, 'saved-access-token');
    expect(config.refreshToken, 'saved-refresh-token');
    expect(config.tokenExpiresAt, 123);
    expect(apiClient.fetchPlatformsCallCount, 1);
  });

  test('平台加载错误应立即结束 startup 且不触发通用自动重试', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/platforms'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/v1/platforms'),
        statusCode: 503,
      ),
      type: DioExceptionType.badResponse,
    );
    final apiClient = _RecordingOnlineApiClient(error: error);
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _ImmediateAppConfigDataSource(),
        ),
        onlineApiClientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(appStartupProvider.future),
      throwsA(error),
    );

    expect(apiClient.fetchPlatformsCallCount, 1);
  });

  test('水合完成时应优先保留刷新拦截器写入的实时 token', () async {
    globalTokenHolder.accessToken = 'live-access-token';
    globalTokenHolder.refreshToken = 'live-refresh-token';
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _ImmediateAppConfigDataSource(
            AppConfigState.initial.copyWith(
              authToken: 'saved-access-token',
              refreshToken: 'saved-refresh-token',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appConfigProvider.notifier).waitUntilHydrated();

    final config = container.read(appConfigProvider);
    expect(config.authToken, 'live-access-token');
    expect(config.refreshToken, 'live-refresh-token');
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

class _ImmediateAppConfigDataSource extends AppConfigDataSource {
  _ImmediateAppConfigDataSource([this.config]);

  final AppConfigState? config;

  @override
  Future<AppConfigState> load() async => config ?? AppConfigState.initial;
}

class _RecordingOnlineApiClient extends OnlineApiClient {
  _RecordingOnlineApiClient({this.error}) : super(Dio());

  final Object? error;
  int fetchPlatformsCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlatforms({
    bool silentErrorMessage = false,
  }) async {
    fetchPlatformsCallCount += 1;
    final requestError = error;
    if (requestError != null) {
      throw requestError;
    }
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'qq',
        'name': 'QQ',
        'shortname': 'QQ',
        'status': 1,
        'feature_support_flag': 0,
      },
    ];
  }
}
