import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/auth/domain/entities/qr_login_state.dart';
import 'package:he_music_flutter/features/auth/presentation/controllers/qr_login_controller.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/qr_login_confirm_page.dart';
import 'package:he_music_flutter/features/auth/presentation/providers/qr_login_providers.dart';

void main() {
  testWidgets('confirm page shows back header and no cancel action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(authToken: 'token', state: _scannedState),
    );
    await tester.pump();

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.text('取消授权'), findsNothing);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets(
    'confirm page shows login action when session scanned but user is not logged in',
    (tester) async {
      await tester.pumpWidget(
        _buildPage(authToken: null, state: _scannedState),
      );
      await tester.pump();

      expect(find.widgetWithText(FilledButton, '先登录当前账号'), findsOneWidget);
      expect(find.text('确认登录这台设备'), findsNothing);
      expect(find.text('返回我的'), findsNothing);
    },
  );

  testWidgets('confirm page shows confirm action only for scanned session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(authToken: 'token', state: _scannedState),
    );
    await tester.pump();

    expect(find.text('确认登录这台设备'), findsOneWidget);
    expect(find.text('先登录当前账号'), findsNothing);
    expect(find.text('返回我的'), findsNothing);
  });

  testWidgets(
    'confirm page hides confirm action for expired session and shows back action',
    (tester) async {
      await tester.pumpWidget(
        _buildPage(authToken: 'token', state: _expiredState),
      );
      await tester.pump();

      expect(find.text('确认登录这台设备'), findsNothing);
      expect(find.text('先登录当前账号'), findsNothing);
      expect(find.text('返回我的'), findsOneWidget);
      expect(find.text('二维码已过期，请重新扫码'), findsOneWidget);
    },
  );

  testWidgets(
    'confirm page shows empty state when there is no pending session',
    (tester) async {
      await tester.pumpWidget(
        _buildPage(authToken: 'token', state: QrLoginState.initial),
      );
      await tester.pump();

      expect(find.text('暂无待确认的登录会话'), findsAtLeastNWidgets(1));
      expect(find.text('确认登录这台设备'), findsNothing);
      expect(find.text('先登录当前账号'), findsNothing);
      expect(find.text('返回我的'), findsOneWidget);
    },
  );

  testWidgets('confirm page back goes to my tab', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.loginQrConfirm,
      routes: <GoRoute>[
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => Text(
            state.uri.queryParameters['tab'] ?? 'home',
            textDirection: TextDirection.ltr,
          ),
        ),
        GoRoute(
          path: AppRoutes.loginQrConfirm,
          builder: (context, state) => const QrLoginConfirmPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildRouterPage(
        router: router,
        authToken: 'token',
        state: _scannedState,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('my'), findsOneWidget);
  });
}

Widget _buildPage({required String? authToken, required QrLoginState state}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(authToken: authToken),
      ),
      qrLoginControllerProvider.overrideWith(
        () => _TestQrLoginController(state),
      ),
    ],
    child: const MaterialApp(home: QrLoginConfirmPage()),
  );
}

Widget _buildRouterPage({
  required GoRouter router,
  required String? authToken,
  required QrLoginState state,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(authToken: authToken),
      ),
      qrLoginControllerProvider.overrideWith(
        () => _TestQrLoginController(state),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

const QrLoginState _scannedState = QrLoginState(
  status: QrLoginWorkflowStatus.scanned,
  isBusy: false,
  sessionId: 'qls_1',
  challenge: 'challenge',
  resultToken: '',
  qrContent: 'hemusic://auth/qr?sid=qls_1&c=challenge',
  clientName: 'HE Music macOS',
  scene: 'desktop_login',
  userHint: '请确认是否登录这台设备',
  checkInterval: 2,
  expiresAt: 1774593600,
);

const QrLoginState _expiredState = QrLoginState(
  status: QrLoginWorkflowStatus.expired,
  isBusy: false,
  sessionId: 'qls_1',
  challenge: 'challenge',
  resultToken: '',
  qrContent: 'hemusic://auth/qr?sid=qls_1&c=challenge',
  clientName: 'HE Music macOS',
  scene: 'desktop_login',
  userHint: '',
  checkInterval: 2,
  expiresAt: 1774593600,
);

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.authToken});

  final String? authToken;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(authToken: authToken);
  }
}

class _TestQrLoginController extends QrLoginController {
  _TestQrLoginController(this.value);

  final QrLoginState value;

  @override
  QrLoginState build() {
    return value;
  }
}
