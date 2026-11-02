import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/settings/data/account_settings_api_client.dart';
import 'package:he_music_flutter/features/settings/data/providers/account_settings_providers.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('取消重置推荐标识不会发送请求', (tester) async {
    final client = _FakeAccountSettingsApiClient();
    await _pumpSettings(tester, client: client);

    await tester.tap(find.text('重置推荐标识').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(client.resetCalls, 0);
  });

  testWidgets('提交期间禁用重复提交并在成功后提示', (tester) async {
    final pending = Completer<void>();
    final client = _FakeAccountSettingsApiClient(pending: pending);
    await _pumpSettings(tester, client: client);

    await tester.tap(find.text('重置推荐标识').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确认重置'));
    await tester.pump();
    await tester.tap(find.text('重置推荐标识').first);
    await tester.pump();

    expect(client.resetCalls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('推荐标识已重置'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('无响应网络异常提示无法确认结果', (tester) async {
    final client = _FakeAccountSettingsApiClient(
      error: DioException(
        requestOptions: RequestOptions(
          path: '/v1/user/provider-identity/reset',
        ),
        type: DioExceptionType.connectionError,
      ),
    );
    await _pumpSettings(tester, client: client);

    await tester.tap(find.text('重置推荐标识').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确认重置'));
    await _pumpToast(tester);

    expect(find.text('未能确认重置结果，请稍后刷新。'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('有响应业务错误沿用错误消息', (tester) async {
    final request = RequestOptions(path: '/v1/user/provider-identity/reset');
    final client = _FakeAccountSettingsApiClient(
      error: DioException(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 400,
          data: <String, dynamic>{'message': '业务失败'},
        ),
      ),
    );
    await _pumpSettings(tester, client: client);

    await tester.tap(find.text('重置推荐标识').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确认重置'));
    await _pumpToast(tester);

    expect(find.text('业务失败'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });
}

Future<void> _pumpToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required _FakeAccountSettingsApiClient client,
}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      accountSettingsApiClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: ThemeData(platform: TargetPlatform.android),
        home: const SettingsPage(sectionId: SettingsSectionIds.account),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(authToken: 'token', clearToken: false);
}

class _FakeAccountSettingsApiClient extends AccountSettingsApiClient {
  _FakeAccountSettingsApiClient({this.error, this.pending}) : super(Dio());

  final Object? error;
  final Completer<void>? pending;
  int resetCalls = 0;

  @override
  Future<void> resetRecommendationIdentity() {
    resetCalls++;
    final error = this.error;
    if (error != null) {
      return Future<void>.error(error);
    }
    return pending?.future ?? Future<void>.value();
  }
}
