import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/auth/presentation/pages/qr_login_scan_page.dart';

void main() {
  testWidgets('scan page shows back header', (tester) async {
    await tester.pumpWidget(_buildRouterApp(const QrLoginScanPage()));
    await tester.pump();

    expect(find.byTooltip('返回'), findsOneWidget);
  });
}

Widget _buildRouterApp(Widget page) {
  final router = GoRouter(
    initialLocation: '/scan',
    routes: <GoRoute>[
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(path: '/scan', builder: (context, state) => page),
    ],
  );

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(() => _TestAppConfigController()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}
