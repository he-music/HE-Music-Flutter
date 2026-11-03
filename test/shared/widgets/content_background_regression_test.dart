import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';
import 'package:he_music_flutter/features/online/presentation/widgets/online_cards.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_quality_selection_sheet.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/settings_single_choice_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_cupertino_content_section.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final playerStyled in [false, true]) {
      for (final quality in [false, true]) {
        if (quality && !playerStyled) continue;
        testWidgets(
          '$brightness player=$playerStyled quality=$quality open sheet follows backgrounds and keeps scroll and selection',
          (tester) async {
            tester.view.physicalSize = const Size(320, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final config = _Config();
            var selections = 0;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appConfigProvider.overrideWith(() => config)],
                child: MaterialApp(
                  theme: _theme(brightness, AppUiStyle.cupertino, false),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () {
                          if (quality) {
                            showPlayerStyledBottomSheet<void>(
                              context: context,
                              fitContent: true,
                              showDragHandle: false,
                              builder: (context) => PlayerQualitySelectionSheet(
                                title: 'Quality',
                                qualities: [
                                  for (var i = 0; i < 18; i++)
                                    PlayerQualityOption(
                                      name: 'Choice $i',
                                      quality: i,
                                      format: 'FLAC',
                                      url: '',
                                    ),
                                ],
                                selectedQualityName: 'Choice 17',
                                onSelected: (_) {
                                  selections++;
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          } else {
                            showSettingsSingleChoiceSheet<int>(
                              context: context,
                              title: 'Choose',
                              playerStyled: playerStyled,
                              currentValue: 17,
                              options: [
                                for (var i = 0; i < 18; i++)
                                  SettingsChoiceOption(
                                    value: i,
                                    title: 'Choice $i',
                                    section: i < 9
                                        ? 'First group'
                                        : 'Second group',
                                  ),
                              ],
                              onSelected: (_) => selections++,
                            );
                          }
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            if (playerStyled || quality) {
              expect(
                Theme.of(
                  tester.element(find.byType(AppCupertinoContentSection).first),
                ).extension<AppSkinTheme>(),
                isNull,
              );
            }
            final scrollable = find
                .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('Choice 17'),
              180,
              scrollable: scrollable,
            );
            await tester.pumpAndSettle();
            final scrollState = tester.state<ScrollableState>(scrollable);
            final offset = scrollState.position.pixels;
            expect(offset, greaterThan(0));
            for (final enabled in [false, true, false]) {
              config.updateBackground(enabled);
              await tester.pumpAndSettle();
              expect(tester.state(scrollable), same(scrollState));
              expect(scrollState.position.pixels, closeTo(offset, 0.01));
              for (final group in tester.widgetList<CupertinoListSection>(
                find.byType(CupertinoListSection),
              )) {
                expect(
                  group.decoration!.color!.a,
                  enabled ? greaterThan(0) : 0,
                );
              }
              // The surrounding modal remains opaque while internal fills change.
              final opaqueShells = find.ancestor(
                of: find.byType(AppCupertinoContentSection).first,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      (widget is Material && widget.color?.a == 1) ||
                      (widget is ColoredBox && widget.color.a == 1) ||
                      (widget is DecoratedBox &&
                          widget.decoration is BoxDecoration &&
                          (widget.decoration as BoxDecoration).color?.a == 1),
                ),
              );
              expect(opaqueShells, findsWidgets);
              expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
            }
            await tester.tap(find.text('Choice 17'));
            await tester.pumpAndSettle();
            expect(selections, 1);
            expect(find.byType(BottomSheet), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    for (final style in AppUiStyle.values) {
      testWidgets(
        '$style $brightness nested online cards follow content fill',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var calls = 0;
          for (final enabled in [false, true, false]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: _theme(brightness, style, enabled),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        QuickActionsCard(
                          onOpenSearchPage: () => calls++,
                          onFetchProfile: () {},
                        ),
                        ConfigCard(config: AppConfigState.initial),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final inks = tester.widgetList<Ink>(
              find.descendant(
                of: find.byType(QuickActionsCard),
                matching: find.byType(Ink),
              ),
            );
            expect(inks, hasLength(2));
            final chips = tester.widgetList<Container>(
              find.descendant(
                of: find.byType(ConfigCard),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).borderRadius ==
                          BorderRadius.circular(999),
                ),
              ),
            );
            expect(chips, hasLength(2));
            for (final decoration in [
              ...inks.map((widget) => widget.decoration as BoxDecoration),
              ...chips.map((widget) => widget.decoration as BoxDecoration),
            ]) {
              expect(
                decoration.color!.a,
                style == AppUiStyle.cupertino && !enabled ? 0 : greaterThan(0),
              );
            }
            await tester.tap(find.byIcon(Icons.search_rounded));
          }
          expect(calls, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'only background changes rebuild a modal group and retain input focus',
    (tester) async {
      final config = _Config();
      final field = TextEditingController();
      final focus = FocusNode();
      addTearDown(field.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWith(() => config)],
          child: MaterialApp(
            home: Scaffold(
              body: AppCupertinoContentSection(
                children: [TextField(controller: field, focusNode: focus)],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep this text');
      final state = tester.state(find.byType(EditableText));
      final initialGroup = tester.widget(find.byType(CupertinoListSection));
      config.updateUnrelated();
      await tester.pump();
      expect(
        tester.widget(find.byType(CupertinoListSection)),
        same(initialGroup),
      );
      for (final enabled in [true, false]) {
        config.updateBackground(enabled);
        await tester.pump();
        expect(tester.state(find.byType(EditableText)), same(state));
        expect(field.text, 'Keep this text');
        expect(focus.hasFocus, isTrue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

ThemeData _theme(Brightness brightness, AppUiStyle style, bool background) {
  final skin = AppSkinRegistry.builtIn(
    AppThemeAccent.appleBlue,
  ).resolve('classic');
  return brightness == Brightness.light
      ? AppTheme.light(skin, uiStyle: style, showContentBackground: background)
      : AppTheme.dark(skin, uiStyle: style, showContentBackground: background);
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(showContentBackground: false);

  void updateBackground(bool value) =>
      state = state.copyWith(showContentBackground: value);
  void updateUnrelated() => state = state.copyWith(lyricPhotoBrightness: 0.8);
}
