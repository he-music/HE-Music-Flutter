import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/settings/data/account_settings_api_client.dart';
import 'package:he_music_flutter/features/settings/data/providers/account_settings_providers.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_password_page.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('signed out password page does not show protected form', (
    tester,
  ) async {
    final client = _FakeAccountSettingsApiClient();
    await _pumpPage(tester, client: client, authToken: null);

    expect(find.text('尚未登录'), findsOneWidget);
    expect(find.text('登录帐号'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('account-password-old')),
      findsNothing,
    );
    expect(client.passwordCalls, 0);
  });

  testWidgets('password page supports narrow dark english layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPage(
      tester,
      client: _FakeAccountSettingsApiClient(),
      localeCode: 'en',
      theme: ThemeData.dark(),
    );

    expect(find.text('Change Password'), findsAtLeastNWidgets(1));
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password validation blocks empty and mismatched values', (
    tester,
  ) async {
    final client = _FakeAccountSettingsApiClient();
    await _pumpPage(tester, client: client);

    await tester.tap(
      find.byKey(const ValueKey<String>('account-password-submit')),
    );
    await _pumpToast(tester);
    expect(find.text('请输入密码'), findsNWidgets(3));

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-old')),
      'old-pass',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-new')),
      'new-pass',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-confirm')),
      'different',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-password-submit')),
    );
    await _pumpToast(tester);

    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
    expect(client.passwordCalls, 0);
  });

  testWidgets('password validation enforces 6 to 18 characters', (
    tester,
  ) async {
    final client = _FakeAccountSettingsApiClient();
    await _pumpPage(tester, client: client);

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-old')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-new')),
      '1234567890123456789',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-password-confirm')),
      '1234567890123456789',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-password-submit')),
    );
    await _pumpToast(tester);

    expect(find.text('原密码长度需为 6–18 个字符'), findsOneWidget);
    expect(find.text('新密码长度需为 6–18 个字符'), findsNWidgets(2));
    expect(client.passwordCalls, 0);
  });

  testWidgets('valid password submit keeps token and clears fields', (
    tester,
  ) async {
    final client = _FakeAccountSettingsApiClient();
    final container = await _pumpPage(tester, client: client);

    await _enterPasswords(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('account-password-submit')),
    );
    await _pumpToast(tester);

    expect(client.passwordCalls, 1);
    expect(client.oldPassword, 'old-pass');
    expect(client.newPassword, 'new-pass');
    expect(container.read(appConfigProvider).authToken, 'token');
    expect(_fieldText(tester, 'account-password-old'), isEmpty);
    expect(_fieldText(tester, 'account-password-new'), isEmpty);
    expect(_fieldText(tester, 'account-password-confirm'), isEmpty);
    expect(find.text('密码已修改'), findsOneWidget);
    await _dismissToasts(tester);
  });

  testWidgets('failed password submit keeps sensitive form values', (
    tester,
  ) async {
    final client = _FakeAccountSettingsApiClient(
      error: StateError('password update failed'),
    );
    await _pumpPage(tester, client: client);

    await _enterPasswords(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('account-password-submit')),
    );
    await _pumpToast(tester);

    expect(client.passwordCalls, 1);
    expect(_fieldText(tester, 'account-password-old'), 'old-pass');
    expect(_fieldText(tester, 'account-password-new'), 'new-pass');
    expect(_fieldText(tester, 'account-password-confirm'), 'new-pass');
    expect(find.textContaining('password update failed'), findsOneWidget);
    await _dismissToasts(tester);
  });
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required _FakeAccountSettingsApiClient client,
  String? authToken = 'token',
  String localeCode = 'zh',
  ThemeData? theme,
}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          authToken: authToken,
          localeCode: localeCode,
        ),
      ),
      accountSettingsApiClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: theme,
        home: const AccountPasswordPage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _enterPasswords(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('account-password-old')),
    'old-pass',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('account-password-new')),
    'new-pass',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('account-password-confirm')),
    'new-pass',
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester
          .widget<TextFormField>(find.byKey(ValueKey<String>(key)))
          .controller
          ?.text ??
      '';
}

Future<void> _dismissToasts(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _pumpToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({
    required this.authToken,
    required this.localeCode,
  });

  final String? authToken;
  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      authToken: authToken,
      clearToken: authToken == null,
      localeCode: localeCode,
    );
  }
}

class _FakeAccountSettingsApiClient extends AccountSettingsApiClient {
  _FakeAccountSettingsApiClient({this.error}) : super(Dio());

  final Object? error;
  int passwordCalls = 0;
  String? oldPassword;
  String? newPassword;

  @override
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    passwordCalls++;
    this.oldPassword = oldPassword;
    this.newPassword = newPassword;
    if (error != null) {
      throw error!;
    }
  }
}
