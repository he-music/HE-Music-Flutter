import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
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
}
