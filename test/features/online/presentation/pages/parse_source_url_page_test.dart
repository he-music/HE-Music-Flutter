import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/parse_source_url_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  testWidgets('parse source url page shows explicit back button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: ParseSourceUrlPage()),
      ),
    );
    await tester.pump();

    expect(find.text('链接解析'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('parse result title uses platform short name when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlineApiClientProvider.overrideWithValue(_FakeOnlineApiClient()),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: ParseSourceUrlPage()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'https://example.com/song');
    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();

    expect(find.text('QQ  ·  歌曲'), findsOneWidget);
    expect(find.text('qq  ·  歌曲'), findsNothing);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());

  @override
  Future<SourceUrlParseResult> parseSourceUrl(String text) async {
    return const SourceUrlParseResult(
      platform: 'qq',
      id: 'song-1',
      type: 'song',
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}
