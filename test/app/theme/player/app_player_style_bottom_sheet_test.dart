import 'package:flutter/cupertino.dart';
import 'package:he_music_flutter/shared/widgets/app_slider.dart';
import 'package:he_music_flutter/shared/widgets/app_button.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';

void main() {
  for (final mode in AppUiStyle.values) {
    testWidgets(
      '$mode player sheet uses an opaque surface and preserves result',
      (tester) async {
        int? result;
        final appTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          extensions: [AppUiTheme(style: mode)],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showPlayerStyledBottomSheet<int>(
                      context: context,
                      useAppAccent: true,
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.pop(context, 7),
                        child: const Text('Select solid'),
                      ),
                    );
                  },
                  child: const Text('Open solid'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open solid'));
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
        final sheetTheme = Theme.of(tester.element(find.text('Select solid')));
        expect(sheetTheme.colorScheme.primary, appTheme.colorScheme.primary);
        expect(
          sheetTheme.colorScheme.onPrimary,
          appTheme.colorScheme.onPrimary,
        );
        final surface = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(PlayerSheetSurface),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(surface.color.a, 1);
        expect(
          _playerSheetStyle(tester).topRadius,
          mode == AppUiStyle.cupertino ? 16 : 24,
        );
        expect(
          ModalRoute.of(tester.element(find.byType(PlayerSheetSurface))),
          isA<PopupRoute<dynamic>>(),
        );
        await tester.tap(find.text('Select solid'));
        await tester.pumpAndSettle();
        expect(result, 7);
      },
    );
  }

  testWidgets(
    'player sheet preserves result, colors, and system overlay style',
    (tester) async {
      final cases =
          <
            ({
              ThemeMode mode,
              String playerStageId,
              String playerBackdropId,
              String playerLyricsId,
              AppPlayerSheetStyle sheet,
            })
          >[
            (
              mode: ThemeMode.light,
              playerStageId: AppPlayerStageRegistry.vinylId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.light,
              playerStageId: AppPlayerStageRegistry.classicId,
              playerBackdropId: AppPlayerBackdropRegistry.artistPhotoId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.dark,
              playerStageId: AppPlayerStageRegistry.classicId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.dark,
            ),
            (
              mode: ThemeMode.dark,
              playerStageId: AppPlayerStageRegistry.cassetteId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.dark,
            ),
          ];

      for (final testCase in cases) {
        int? result;
        ColorScheme? sheetColorScheme;
        SliderThemeData? sheetSliderTheme;
        BottomSheetThemeData? sheetBottomSheetTheme;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(
                () => _PlayerConfigController(
                  playerStageId: testCase.playerStageId,
                  playerBackdropId: testCase.playerBackdropId,
                  playerLyricsId: testCase.playerLyricsId,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: testCase.mode,
              home: AppPlayerStyleBoundary(
                child: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () async {
                      result = await showPlayerStyledBottomSheet<int>(
                        context: context,
                        builder: (sheetContext) {
                          final theme = Theme.of(sheetContext);
                          sheetColorScheme = theme.colorScheme;
                          sheetSliderTheme = theme.sliderTheme;
                          sheetBottomSheetTheme = theme.bottomSheetTheme;
                          return TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(7),
                            child: const Text('Close'),
                          );
                        },
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final bottomSheet = tester.widget<BottomSheet>(
          find.byType(BottomSheet),
        );
        expect(bottomSheet.backgroundColor, Colors.transparent);
        expect(_playerSheetStyle(tester), testCase.sheet);
        expect(sheetColorScheme?.surface, testCase.sheet.backgroundColor);
        expect(
          sheetColorScheme?.surfaceContainerHighest,
          testCase.sheet.backgroundColor,
        );
        expect(sheetColorScheme?.onSurface, testCase.sheet.foregroundColor);
        expect(
          sheetColorScheme?.onSurfaceVariant,
          testCase.sheet.secondaryForegroundColor,
        );
        expect(
          sheetBottomSheetTheme?.dragHandleColor,
          testCase.sheet.handleColor,
        );
        expect(
          sheetSliderTheme?.activeTrackColor,
          testCase.sheet.foregroundColor,
        );
        expect(
          find.byKey(const ValueKey<String>('player-sheet-surface')),
          findsOne,
        );
        final overlayStyleGuard = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byKey(
                const ValueKey<String>('player-system-ui-overlay-style-guard'),
              ),
            );
        expect(overlayStyleGuard.value, appPlayerSystemOverlayStyle);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(result, 7);
        expect(
          find.byKey(
            const ValueKey<String>('player-system-ui-overlay-style-guard'),
          ),
          findsNothing,
        );
      }
    },
  );

  testWidgets('open player sheet follows app brightness changes', (
    tester,
  ) async {
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
    var sheetBuildCount = 0;
    addTearDown(themeMode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _PlayerConfigController(
              playerStageId: AppPlayerStageRegistry.classicId,
            ),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, child) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: AppPlayerStyleBoundary(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showPlayerStyledBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      sheetBuildCount += 1;
                      return TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Close'),
                      );
                    },
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.light);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFF151515));
    expect(
      _playerSheetHandleColor(tester),
      AppPlayerSheetStyle.light.handleColor,
    );
    final initialSheetBuildCount = sheetBuildCount;

    themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.dark);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFFF5F5F5));
    expect(
      _playerSheetHandleColor(tester),
      AppPlayerSheetStyle.dark.handleColor,
    );
    expect(sheetBuildCount, initialSheetBuildCount);
    expect(
      find.byKey(
        const ValueKey<String>('player-system-ui-overlay-style-guard'),
      ),
      findsOne,
    );

    themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.light);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFF151515));
    expect(sheetBuildCount, initialSheetBuildCount);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'open sheet keeps route, input focus and edits when interface style changes',
    (tester) async {
      final style = ValueNotifier(AppUiStyle.material);
      addTearDown(style.dispose);
      final childKey = GlobalKey<_EditableSheetState>();
      var builds = 0;
      int? result;
      await tester.pumpWidget(
        ValueListenableBuilder<AppUiStyle>(
          valueListenable: style,
          builder: (context, mode, child) => AppUiStyleScope(
            style: mode,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showPlayerStyledBottomSheet<int>(
                        context: context,
                        builder: (_) {
                          builds += 1;
                          return _EditableSheet(key: childKey);
                        },
                      );
                    },
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final state = childKey.currentState!;
      final route = ModalRoute.of(tester.element(find.byType(_EditableSheet)));
      await tester.drag(find.byType(AppSlider), const Offset(50, 0));
      await tester.pumpAndSettle();
      final edited = state.value;
      expect(edited, greaterThan(.5));
      await tester.enterText(find.byType(TextField), 'Remember this input');
      for (final next in [AppUiStyle.cupertino, AppUiStyle.material]) {
        style.value = next;
        await tester.pumpAndSettle();
        expect(childKey.currentState, same(state));
        expect(state.value, edited);
        expect(state.controller.text, 'Remember this input');
        expect(state.fieldFocus.hasFocus, isTrue);
        expect(
          ModalRoute.of(tester.element(find.byType(_EditableSheet))),
          same(route),
        );
        expect(
          find.byType(next == AppUiStyle.cupertino ? CupertinoSlider : Slider),
          findsOneWidget,
        );
        expect(
          _playerSheetStyle(tester).topRadius,
          next == AppUiStyle.cupertino ? 16 : 24,
        );
        expect(builds, 1);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Save edits'));
      await tester.pumpAndSettle();
      expect(result, 7);
      expect(state.mounted, isFalse);
    },
  );

  testWidgets(
    'nested player sheets retain style marker and follow app brightness',
    (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      int? nestedResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_PlayerConfigController.new),
          ],
          child: AppUiStyleScope(
            style: AppUiStyle.cupertino,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: mode,
              builder: (context, current, child) => MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: current,
                home: AppPlayerStyleBoundary(
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => showPlayerStyledBottomSheet<void>(
                          context: context,
                          builder: (outerContext) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  nestedResult =
                                      await showPlayerStyledBottomSheet<int>(
                                        context: outerContext,
                                        builder: (innerContext) => TextButton(
                                          onPressed: () =>
                                              Navigator.of(innerContext).pop(9),
                                          child: const Text('Close nested'),
                                        ),
                                      );
                                },
                                child: const Text('Open nested'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(outerContext).pop(),
                                child: const Text('Close outer'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Open outer'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open outer'));
      await tester.pumpAndSettle();
      final outer = tester.element(find.byType(PlayerSheetSurface));
      final outerRoute = ModalRoute.of(outer);
      expect(Theme.of(outer).extension<AppPlayerStyleTheme>(), isNotNull);
      await tester.tap(find.text('Open nested'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSheetSurface), findsNWidgets(2));
      final inner = tester.element(find.byType(PlayerSheetSurface).last);
      expect(Theme.of(inner).extension<AppPlayerStyleTheme>(), isNotNull);
      expect(ModalRoute.of(inner), isA<PopupRoute<dynamic>>());
      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      for (final element in tester.elementList(
        find.byType(PlayerSheetSurface),
      )) {
        expect(Theme.of(element).brightness, Brightness.dark);
        expect((element.widget as PlayerSheetSurface).style.topRadius, 16);
        expect(
          Theme.of(element).extension<AppPlayerStyleTheme>()!.sheetBrightness,
          Brightness.dark,
        );
      }
      await tester.tap(find.text('Close nested'));
      await tester.pumpAndSettle();
      expect(nestedResult, 9);
      expect(find.byType(PlayerSheetSurface), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(PlayerSheetSurface))),
        same(outerRoute),
      );
      expect(
        find.byKey(const ValueKey('player-system-ui-overlay-style-guard')),
        findsOneWidget,
      );
      await tester.tap(find.text('Close outer'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-system-ui-overlay-style-guard')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

AppPlayerSheetStyle _playerSheetStyle(WidgetTester tester) {
  return tester
      .widget<PlayerSheetSurface>(find.byType(PlayerSheetSurface))
      .style;
}

Color? _renderedTextColor(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return richText.text.style?.color;
}

Color? _playerSheetHandleColor(WidgetTester tester) {
  final handle = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey<String>('player-sheet-drag-handle')),
  );
  return (handle.decoration as BoxDecoration).color;
}

class _EditableSheet extends StatefulWidget {
  const _EditableSheet({super.key});
  @override
  State<_EditableSheet> createState() => _EditableSheetState();
}

class _EditableSheetState extends State<_EditableSheet> {
  final controller = TextEditingController();
  final fieldFocus = FocusNode();
  double value = .5;

  @override
  void dispose() {
    controller.dispose();
    fieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: controller, focusNode: fieldFocus),
        AppSlider(
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
        AppButton.filled(
          onPressed: () => Navigator.of(context).pop(7),
          child: const Text('Save edits'),
        ),
      ],
    ),
  );
}

class _PlayerConfigController extends AppConfigController {
  _PlayerConfigController({
    this.playerStageId = AppPlayerStageRegistry.classicId,
    this.playerBackdropId = AppPlayerBackdropRegistry.coverGradientId,
    this.playerLyricsId = AppPlayerLyricsRegistry.legacyId,
  });

  final String playerStageId;
  final String playerBackdropId;
  final String playerLyricsId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      playerStageId: playerStageId,
      playerBackdropId: playerBackdropId,
      playerLyricsId: playerLyricsId,
    );
  }
}
