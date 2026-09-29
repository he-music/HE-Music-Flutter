import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/widgets/plaza_widgets.dart';

import '../../helpers/expect_text_height_fits.dart';

void main() {
  testWidgets('platform error and retry grow with large text', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWith(_Config.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(3)),
              child: Align(
                alignment: Alignment.topCenter,
                child: PlazaPlatformsErrorView(
                  i18nKey: 'ranking.no_platform',
                  onRetry: () => retried = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expectTextHeightFits(tester, find.byType(PlazaPlatformsErrorView));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(TextButton));
    expect(retried, isTrue);
  });
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');
}
