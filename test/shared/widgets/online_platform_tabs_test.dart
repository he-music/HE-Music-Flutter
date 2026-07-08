import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/shared/widgets/online_platform_tabs.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';

void main() {
  final platforms = [
    OnlinePlatform(
      id: 'qq',
      name: 'QQ Music',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag: BigInt.from(0x7FFFFFFFFF),
    ),
    OnlinePlatform(
      id: 'netease',
      name: 'NetEase Music',
      shortName: '网易',
      status: 1,
      featureSupportFlag: BigInt.from(0x3),
    ),
  ];

  group('OnlinePlatformTabs', () {
    testWidgets('应渲染所有平台标签', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnlinePlatformTabs(
            platforms: platforms,
            selectedId: 'qq',
            requiredFeatureFlag: BigInt.one,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('QQ'), findsOneWidget);
      expect(find.text('网易'), findsOneWidget);
    });

    testWidgets('platforms 为空时应显示无平台提示', (tester) async {
      await tester.pumpWidget(
        _wrapWithProvider(
          OnlinePlatformTabs(
            platforms: const [],
            selectedId: null,
            requiredFeatureFlag: BigInt.one,
            onSelected: (_) {},
          ),
        ),
      );

      // 应显示 i18n 的 ranking.no_platform
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('点击平台应触发 onSelected', (tester) async {
      String? selectedId;
      await tester.pumpWidget(
        _wrap(
          OnlinePlatformTabs(
            platforms: platforms,
            selectedId: 'qq',
            requiredFeatureFlag: BigInt.one,
            onSelected: (id) => selectedId = id,
          ),
        ),
      );

      await tester.tap(find.text('网易'));
      expect(selectedId, 'netease');
    });

    testWidgets('不支持的平台应禁用', (tester) async {
      // netease 的 featureSupportFlag 只有 bit 0 和 1
      // 要求 bit 5（BigInt.from(32)）→ netease 不支持
      String? selectedId;
      await tester.pumpWidget(
        _wrap(
          OnlinePlatformTabs(
            platforms: platforms,
            selectedId: 'qq',
            requiredFeatureFlag: BigInt.from(32),
            onSelected: (id) => selectedId = id,
          ),
        ),
      );

      await tester.tap(find.text('网易'));
      expect(selectedId, isNull);
    });
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 50, child: child)),
    ),
  );
}

Widget _wrapWithProvider(Widget child) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}
