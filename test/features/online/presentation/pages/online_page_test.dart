import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_page.dart';

void main() {
  testWidgets('online page renders core entry cards in zh locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnlinePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('在线中心'), findsWidgets);
    expect(find.text('环境配置'), findsOneWidget);
    expect(find.text('账号与登录'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('歌单与收藏'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('歌单与收藏'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('运行结果'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('运行结果'), findsOneWidget);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(apiBaseUrl: 'https://example.com');
  }
}
