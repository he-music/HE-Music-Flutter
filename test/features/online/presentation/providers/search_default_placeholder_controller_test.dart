import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  testWidgets('搜索默认词后台停止刷新并在恢复前台时刷新一次', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final apiClient = _CountingOnlineApiClient();
    final container = ProviderContainer(
      overrides: [
        onlineApiClientProvider.overrideWithValue(apiClient),
        onlinePlatformsProvider.overrideWith(
          _SearchDefaultPlatformsController.new,
        ),
      ],
    );
    container.listen(
      searchDefaultPlaceholderProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pump();
    await tester.pump();
    expect(apiClient.fetchDefaultCallCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(minutes: 10));
    expect(apiClient.fetchDefaultCallCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(apiClient.fetchDefaultCallCount, 2);
    expect(apiClient.silentErrorMessageValues, everyElement(isTrue));
    container.dispose();
    await tester.pump();
  });
}

class _SearchDefaultPlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getSearchDefault,
      ),
    ];
  }
}

class _CountingOnlineApiClient extends OnlineApiClient {
  _CountingOnlineApiClient() : super(Dio());

  int fetchDefaultCallCount = 0;
  final List<bool> silentErrorMessageValues = <bool>[];

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
    bool silentErrorMessage = false,
  }) async {
    fetchDefaultCallCount += 1;
    silentErrorMessageValues.add(silentErrorMessage);
    return const <SearchDefaultEntry>[
      SearchDefaultEntry(key: '周杰伦', description: '稻香'),
    ];
  }
}
