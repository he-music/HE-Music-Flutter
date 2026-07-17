import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/core/device/device_info_provider.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _testDeviceInfo = DeviceInfoData(
  deviceId: 'flutter_macos_test-uuid',
  platform: 'macos',
  appType: 'flutter',
  appVersion: '1.0.0',
  deviceName: 'Test Device',
);

void main() {
  testWidgets('desktop login page defaults to password tab', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        platform: TargetPlatform.macOS,
        client: _LoginPageTestClient.desktop(),
      ),
    );
    await tester.pump();

    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('扫码登录'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('desktop login page creates qr only after switching tab', (
    tester,
  ) async {
    final client = _LoginPageTestClient.desktop();
    await tester.pumpWidget(
      _buildApp(platform: TargetPlatform.macOS, client: client),
    );
    await tester.pump();

    expect(client.createQrCallCount, 0);

    await tester.tap(find.text('扫码登录'));
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(client.createQrCallCount, 1);
  });

  testWidgets('desktop login page recreates qr session after reopening', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(() => _TestAppConfigController()),
        onlineApiClientProvider.overrideWithValue(
          _LoginPageTestClient.desktop(),
        ),
        deviceInfoProvider.overrideWithValue(AsyncData(_testDeviceInfo)),
      ],
    );
    addTearDown(container.dispose);
    final client =
        container.read(onlineApiClientProvider) as _LoginPageTestClient;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const LoginPage(redirectLocation: null),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('扫码登录'));
    await tester.pump();

    expect(client.createQrCallCount, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const LoginPage(redirectLocation: null),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('扫码登录'));
    await tester.pump();

    expect(client.createQrCallCount, 2);
  });

  testWidgets(
    'desktop login page shows overlay and refresh only when expired',
    (tester) async {
      final client = _LoginPageTestClient.desktop(
        qrSessionResult: const QrLoginSessionResult(
          sessionId: 'qls_desktop',
          qrContent: 'hemusic://auth/qr?sid=qls_desktop&c=challenge_desktop',
          resultToken: 'result_desktop',
          status: 'expired',
          checkInterval: 2,
          expiresAt: 1774593600,
        ),
      );
      await tester.pumpWidget(
        _buildApp(platform: TargetPlatform.macOS, client: client),
      );
      await tester.pump();

      await tester.tap(find.text('扫码登录'));
      await tester.pump();

      expect(find.text('二维码已过期，请重新扫码'), findsOneWidget);
      expect(find.text('刷新二维码'), findsOneWidget);
    },
  );

  testWidgets('login page shows scan entry on mobile', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        platform: TargetPlatform.android,
        client: _LoginPageTestClient.mobile(),
      ),
    );
    await tester.pump();

    expect(find.text('扫一扫登录设备'), findsNothing);
    expect(find.text('二维码登录'), findsNothing);
  });

  testWidgets('沉浸式皮肤下登录页保留内容但不渲染旧渐变', (tester) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      _buildApp(
        platform: TargetPlatform.android,
        client: _LoginPageTestClient.mobile(),
        theme: AppTheme.light(skin),
      ),
    );
    await tester.pump();

    expect(find.text('登录'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient is LinearGradient,
      ),
      findsNothing,
    );
  });
}

Widget _buildApp({
  required TargetPlatform platform,
  required OnlineApiClient client,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(() => _TestAppConfigController()),
      onlineApiClientProvider.overrideWithValue(client),
      deviceInfoProvider.overrideWithValue(AsyncData(_testDeviceInfo)),
    ],
    child: MaterialApp(
      theme: (theme ?? ThemeData()).copyWith(platform: platform),
      home: const LoginPage(redirectLocation: null),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _LoginPageTestClient extends OnlineApiClient {
  _LoginPageTestClient._({
    required this.providers,
    required this.qrSessionResult,
  }) : super(Dio());

  final List<String> providers;
  final QrLoginSessionResult qrSessionResult;
  int createQrCallCount = 0;
  int statusCallCount = 0;

  factory _LoginPageTestClient.desktop({
    QrLoginSessionResult? qrSessionResult,
  }) {
    return _LoginPageTestClient._(
      providers: const <String>[],
      qrSessionResult:
          qrSessionResult ??
          const QrLoginSessionResult(
            sessionId: 'qls_desktop',
            qrContent: 'hemusic://auth/qr?sid=qls_desktop&c=challenge_desktop',
            resultToken: 'result_desktop',
            status: 'pending',
            checkInterval: 2,
            expiresAt: 1774593600,
          ),
    );
  }

  factory _LoginPageTestClient.mobile() {
    return _LoginPageTestClient._(
      providers: const <String>[],
      qrSessionResult: const QrLoginSessionResult(
        sessionId: '',
        qrContent: '',
        resultToken: '',
        status: '',
        checkInterval: 0,
        expiresAt: 0,
      ),
    );
  }

  @override
  Future<List<String>> listAuthProviders() async {
    return providers;
  }

  @override
  Future<QrLoginSessionResult> createQrLoginSession({
    required String clientType,
    required String clientName,
    required String scene,
    Map<String, dynamic>? deviceInfo,
  }) async {
    createQrCallCount += 1;
    return qrSessionResult;
  }

  @override
  Future<QrLoginSessionStatusResult> getQrLoginSessionStatus({
    required String sessionId,
  }) async {
    statusCallCount += 1;
    return const QrLoginSessionStatusResult(
      sessionId: 'qls_desktop',
      status: 'pending',
      checkInterval: 2,
      expiresAt: 1774593600,
      clientName: 'HE Music macOS',
      userHint: '等待扫码',
    );
  }
}
