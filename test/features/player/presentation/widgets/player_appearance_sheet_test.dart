import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_player_appearance.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_appearance_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_text_field.dart';

class _Config extends AppConfigController {
  _Config(this.initial);
  final AppConfigState initial;
  int changes = 0;
  @override
  AppConfigState build() => initial;
  @override
  void setPlayerAppearance(AppPlayerAppearance appearance) {
    state = state.copyWith(playerAppearance: appearance);
    changes++;
  }
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);
}

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('color overrides restore independently in ${style.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = _Config(
        AppConfigState.initial.copyWith(localeCode: 'en', uiStyle: style),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(() => config),
            playerControllerProvider.overrideWith(_Player.new),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: [AppUiTheme(style: style)],
            ),
            home: const Scaffold(body: PlayerAppearanceSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final background = find.byKey(const ValueKey('player-background-color'));
      final accent = find.byKey(const ValueKey('player-accent-color'));
      await tester.tap(
        find.descendant(of: background, matching: find.text('Custom')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: background, matching: find.byType(AppTextField)),
        '#AD7149',
      );
      await tester.pumpAndSettle();
      expect(config.state.playerAppearance.backgroundColor, 0xffad7149);
      final changesBeforeDrag = config.changes;
      final picker = find.descendant(
        of: background,
        matching: find.byKey(const ValueKey('color-picker-saturation-value')),
      );
      await tester.ensureVisible(picker);
      final plane = tester.getRect(picker);
      final gesture = await tester.startGesture(plane.center);
      await gesture.moveTo(
        plane.topLeft + Offset(plane.width * .7, plane.height * .2),
      );
      await tester.pump();
      expect(config.changes, changesBeforeDrag);
      expect(config.state.playerAppearance.backgroundColor, 0xffad7149);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(config.changes, changesBeforeDrag + 1);
      final customAccent = find.descendant(
        of: accent,
        matching: find.text('Custom'),
      );
      await tester.ensureVisible(customAccent);
      await tester.tap(customAccent);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: accent, matching: find.byType(AppTextField)),
        '#EDC968',
      );
      await tester.pumpAndSettle();
      final autoBackground = find.descendant(
        of: background,
        matching: find.text('Automatic'),
      );
      await tester.ensureVisible(autoBackground);
      await tester.tap(autoBackground);
      await tester.pumpAndSettle();
      expect(config.state.playerAppearance.backgroundColor, isNull);
      expect(config.state.playerAppearance.accentColor, 0xffedc968);
      expect(
        config.state.lyricHighlightMode,
        AppConfigState.initial.lyricHighlightMode,
      );
      expect(tester.takeException(), isNull);
      if (style == AppUiStyle.cupertino) {
        expect(find.byType(CupertinoTextField), findsOneWidget);
      }
      if (const bool.fromEnvironment('EXPORT_APPEARANCE_PREVIEW')) {
        // Export the actual settings widgets for visual inspection.
        await tester.runAsync(() async {
          await (FontLoader('AppearancePreview')..addFont(
                File(
                  'test/assets/fonts/Roboto-Regular.ttf',
                ).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        tester.view.physicalSize = const Size(390, 1100);
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('appearance-export-${style.name}'),
            overrides: [
              appConfigProvider.overrideWith(
                () => _Config(
                  AppConfigState.initial.copyWith(
                    localeCode: 'en',
                    playerAppearance: const AppPlayerAppearance(
                      backgroundColor: 0xffa0c8a2,
                    ),
                  ),
                ),
              ),
              playerControllerProvider.overrideWith(_Player.new),
            ],
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'AppearancePreview'),
              home: RepaintBoundary(
                key: const ValueKey('appearance-export'),
                child: const Scaffold(body: PlayerAppearanceSheet()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('appearance-export')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('.artifacts/player-appearance/color-picker.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    });
  }
}
