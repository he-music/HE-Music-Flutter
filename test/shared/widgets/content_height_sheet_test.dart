import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/settings_single_choice_sheet.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final count in [1, 8, 50]) {
      testWidgets(
        '$style choice sheet fits $count choices and returns the last choice',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          int? selected;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appConfigProvider.overrideWith(_Config.new)],
              child: MaterialApp(
                theme: ThemeData(extensions: [AppUiTheme(style: style)]),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showSettingsSingleChoiceSheet<int>(
                        context: context,
                        title: 'Choose',
                        currentValue: 0,
                        options: [
                          for (var i = 0; i < count; i++)
                            SettingsChoiceOption(value: i, title: 'Choice $i'),
                        ],
                        onSelected: (value) => selected = value,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          if (count == 1) expect(tester.getSize(sheet).height, lessThan(250));
          await tester.scrollUntilVisible(
            find.text('Choice ${count - 1}'),
            200,
            scrollable: find.descendant(
              of: sheet,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Choice ${count - 1}'));
          await tester.pumpAndSettle();
          expect(selected, count - 1);
          expect(sheet, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}
