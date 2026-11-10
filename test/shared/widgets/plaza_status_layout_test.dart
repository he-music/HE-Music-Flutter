import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/plaza_widgets.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style platform failure keeps the full message on narrow screens',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          _wrap(
            style: style,
            size: const Size(280, 400),
            textScale: 3,
            child: Align(
              alignment: Alignment.topCenter,
              child: PlazaPlatformsErrorView(
                i18nKey: 'ranking.no_platform',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        final message = tester.widget<Text>(
          find.text('No available platforms'),
        );
        expect(message.maxLines, isNull);
        expect(message.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Retry'));
        expect(retried, isTrue);
      },
    );

    testWidgets('$style empty state wraps long text within the viewport', (
      tester,
    ) async {
      const label =
          'No matching music. Try selecting a different platform or filter.';
      await tester.pumpWidget(
        _wrap(
          style: style,
          size: const Size(280, 400),
          textScale: 2,
          child: const PlazaEmptyState(label: label),
        ),
      );

      final textRect = tester.getRect(find.text(label));
      final viewportRect = tester.getRect(find.byType(PlazaEmptyState));
      expect(textRect.left, greaterThanOrEqualTo(viewportRect.left + 24));
      expect(textRect.right, lessThanOrEqualTo(viewportRect.right - 24));
      expect(tester.widget<Text>(find.text(label)).textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$style error retry remains reachable in a short viewport', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          style: style,
          size: const Size(280, 180),
          textScale: 3,
          child: PlazaErrorView(
            message:
                'Unable to load music. Please check your connection and try again.',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Retry'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$style desktop error message has a readable line width', (
      tester,
    ) async {
      const message = 'Unable to load music. Please try again later.';
      await tester.pumpWidget(
        _wrap(
          style: style,
          size: const Size(800, 600),
          child: PlazaErrorView(message: message, onRetry: () {}),
        ),
      );

      expect(tester.getSize(find.text(message)).width, lessThanOrEqualTo(420));
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _wrap({
  required AppUiStyle style,
  required Size size,
  required Widget child,
  double textScale = 1,
}) => ProviderScope(
  overrides: [appConfigProvider.overrideWith(_Config.new)],
  child: MaterialApp(
    theme: ThemeData(extensions: [AppUiTheme(style: style)]),
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}
