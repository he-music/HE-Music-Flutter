import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_surface.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final mode in [AppGlassMode.powerSaving, AppGlassMode.off]) {
    testWidgets('$mode sheets bypass glass and background filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppThemedBottomSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 150, child: Text('Solid sheet')),
              ),
              child: const Text('Open solid sheet'),
            ),
          ),
          mode: mode,
          enabled: mode != AppGlassMode.off,
        ),
      );
      await tester.tap(find.text('Open solid sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Solid sheet'), findsOneWidget);
      expect(find.byType(GlassModalSheet), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!.a,
        1,
      );
    });
  }

  testWidgets('off surfaces bypass skin blur and render opaque controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppGlassSurface(
          role: AppSkinSurfaceRole.miniPlayer,
          child: SizedBox(width: 200, height: 52),
        ),
        enabled: false,
        mode: AppGlassMode.off,
      ),
    );
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppSkinSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color!.a, 1);
  });

  testWidgets('glass uses skin fallback outside the main app scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppGlassSurface(
          role: AppSkinSurfaceRole.navigation,
          child: SizedBox(width: 200, height: 60),
        ),
        enabled: false,
      ),
    );
    expect(find.byType(AppSkinSurface), findsOneWidget);
    expect(find.byType(GlassContainer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled glass preserves control size with minimal quality', (
    tester,
  ) async {
    const key = ValueKey('control');
    await tester.pumpWidget(
      _app(
        const Center(
          child: AppGlassSurface(
            role: AppSkinSurfaceRole.miniPlayer,
            child: SizedBox(key: key, width: 200, height: 52),
          ),
        ),
      ),
    );
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(tester.getSize(find.byKey(key)), const Size(200, 52));
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast replaces glass with an opaque skin surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const AppGlassSurface(
            role: AppSkinSurfaceRole.navigation,
            child: SizedBox(width: 200, height: 60),
          ),
        ),
      ),
    );
    expect(find.byType(GlassContainer), findsNothing);
    final surface = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(AppGlassSurface),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(surface.color.a, 1);
  });

  testWidgets(
    'themed glass sheet keeps results and fits long scrollable content',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showAppThemedBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) => SizedBox(
                      height: 400,
                      child: ListView(
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, 'selected'),
                            child: const Text('Select'),
                          ),
                          for (var i = 0; i < 50; i++)
                            ListTile(title: Text('Track $i')),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassModalSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(result, 'selected');
      expect(find.byType(GlassModalSheet), findsNothing);
    },
  );
  testWidgets('glass sheet stays at medium, avoids keyboard and dismisses', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    String? result = 'pending';
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppThemedBottomSheet<String>(
                context: context,
                builder: (sheetContext) => Column(
                  children: [
                    const TextField(key: ValueKey('sheet-input')),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('sheet-close'),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<GlassModalSheet>(find.byType(GlassModalSheet));
    expect(sheet.initialState, GlassSheetState.half);
    expect(sheet.halfSize, 0.45);
    expect(sheet.quality, GlassQuality.premium);
    await tester.tap(find.byKey(const ValueKey('sheet-input')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('sheet-close'))).dy,
      lessThanOrEqualTo(
        (tester.view.physicalSize.height - 240) / tester.view.devicePixelRatio +
            1,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(GlassModalSheet), findsNothing);
  });
  testWidgets('online song menu scrolls at one height without expanding', (
    tester,
  ) async {
    var played = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSongActionsSheet(
              context: context,
              forceBottomSheet: true,
              coverUrl: null,
              title: 'Online song',
              subtitle: 'Artist',
              hasMv: false,
              sourceLabel: 'QQ Music',
              playActionLabel: 'Play regression song',
              onPlay: () => played = true,
              onPlayNext: () {},
              onAddToPlaylist: () {},
              onDownload: () {},
              onAddToUserPlaylist: () {},
              onWatchMv: () {},
              onViewDetail: () {},
              onViewComment: () {},
              onCopySongName: () {},
              onCopySongId: () {},
            ),
            child: const Text('Open online menu'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open online menu'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<GlassModalSheet>(find.byType(GlassModalSheet));
    expect(sheet.initialState, GlassSheetState.half);
    expect(sheet.halfSize, 0.72);
    expect(sheet.detents, {GlassSheetDetent.medium});
    final fill = find.byKey(const Key('glass_modal_sheet_fill'));
    final initialTop = tester.getTopLeft(fill).dy;
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(initialTop, closeTo(viewportHeight * (1 - sheet.halfSize), 24));
    expect(
      (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration).color!.a,
      0,
    );
    final list = find
        .descendant(
          of: find.byType(GlassModalSheet),
          matching: find.byType(ListView),
        )
        .first;
    await tester.drag(list, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(fill).dy, closeTo(initialTop, 1));
    expect(
      (tester.widget<DecoratedBox>(fill).decoration as BoxDecoration).color!.a,
      0,
    );
    expect(sheet.maintainContentGlass, isFalse);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Play regression song'),
      -150,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.text('Play regression song'));
    await tester.pumpAndSettle();
    expect(played, isTrue);
    expect(find.byType(GlassModalSheet), findsNothing);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'sheet material and foreground follow app $brightness over opposite system theme',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            brightness == Brightness.dark ? Brightness.light : Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        late ThemeData sourceTheme;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) {
                sourceTheme = Theme.of(context);
                return TextButton(
                  onPressed: () => showAppThemedBottomSheet<void>(
                    context: context,
                    builder: (_) => const Column(
                      children: [
                        Text('Sheet foreground'),
                        Icon(Icons.music_note),
                      ],
                    ),
                  ),
                  child: const Text('Open themed sheet'),
                );
              },
            ),
            brightness: brightness,
          ),
        );
        await tester.tap(find.text('Open themed sheet'));
        await tester.pumpAndSettle();
        final sheet = tester.widget<GlassModalSheet>(
          find.byType(GlassModalSheet),
        );
        final backer = sheet.settings!.backerColor!;
        expect(backer.a, closeTo(0.35, 0.01));
        expect(
          backer.computeLuminance(),
          brightness == Brightness.dark ? lessThan(0.2) : greaterThan(0.7),
        );
        final variant = brightness == Brightness.dark
            ? GlassThemeVariant.dark
            : GlassThemeVariant.light;
        expect(sheet.settings!.glassColor, variant.settings!.glassColor);
        expect(sheet.halfSettings, sheet.settings);
        expect(sheet.fullSettings, sheet.settings);
        expect(sheet.maintainContentGlass, isFalse);
        expect(
          sheet.dragIndicatorColor,
          sourceTheme.colorScheme.onSurfaceVariant,
        );
        final content = tester.element(find.text('Sheet foreground'));
        // App brightness controls the scrim even when the system theme differs.
        expect(
          ModalRoute.of(content)!.barrierColor,
          brightness == Brightness.light
              ? const Color(0x33000000)
              : GlassDefaults.barrierColor,
        );
        expect(Theme.of(content).brightness, brightness);
        expect(
          DefaultTextStyle.of(content).style.color,
          sourceTheme.textTheme.bodyMedium!.color,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(
  Widget child, {
  bool enabled = true,
  AppGlassMode mode = AppGlassMode.automatic,
  Brightness brightness = Brightness.light,
}) {
  final skin = AppSkinRegistry.builtIn(
    AppThemeAccent.forest,
  ).resolve(AppSkinRegistry.classicId);
  return AppGlassScope(
    enabled: enabled,
    mode: mode,
    child: GlassAdaptiveScope(
      minQuality: GlassQuality.minimal,
      maxQuality: GlassQuality.minimal,
      initialQuality: GlassQuality.minimal,
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark(skin)
            : AppTheme.light(skin),
        home: Scaffold(body: child),
      ),
    ),
  );
}
