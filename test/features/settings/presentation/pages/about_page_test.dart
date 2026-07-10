import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/about_page.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_current_app_info.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/update_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('about page shows centered logo section', (tester) async {
    await _pumpAboutPage(tester);

    expect(find.byKey(const ValueKey<String>('about-logo')), findsOneWidget);
  });

  testWidgets('latest update status shows a toastification message', (
    tester,
  ) async {
    await _pumpAboutPage(tester);

    _controller(tester).emit(const UpdateState(status: UpdateStatus.latest));
    await _pumpToast(tester);

    expect(find.text('当前已是最新版本'), findsOneWidget);
    await _dismissToasts(tester);
  });

  testWidgets('failed update status shows a toastification error', (
    tester,
  ) async {
    await _pumpAboutPage(tester);

    _controller(tester).emit(
      const UpdateState(status: UpdateStatus.failure, errorMessage: '检查更新测试失败'),
    );
    await _pumpToast(tester);

    expect(find.text('检查更新测试失败'), findsOneWidget);
    await _dismissToasts(tester);
  });
}

Future<void> _pumpAboutPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppInfoProvider.overrideWith(
          (ref) async => const UpdateCurrentAppInfo(
            appName: 'HE Music',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
        updateControllerProvider.overrideWith(_TestUpdateController.new),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const AboutPage(),
      ),
    ),
  );
  await tester.pump();
}

_TestUpdateController _controller(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AboutPage)),
    listen: false,
  );
  return container.read(updateControllerProvider.notifier)
      as _TestUpdateController;
}

Future<void> _pumpToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _dismissToasts(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

class _TestUpdateController extends UpdateController {
  void emit(UpdateState next) {
    state = next;
  }
}
