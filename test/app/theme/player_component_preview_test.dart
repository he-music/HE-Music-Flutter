import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_style_live_preview.dart';

void main() {
  const enabled = bool.fromEnvironment('GENERATE_PLAYER_PREVIEWS');
  const axisFilter = String.fromEnvironment('PREVIEW_AXIS');
  final registries = {
    'stage': AppPlayerStageRegistry.instance.options.map((e) => e.metadata),
    'backdrop': AppPlayerBackdropRegistry.instance.options.map(
      (e) => e.metadata,
    ),
    'lyrics': AppPlayerLyricsRegistry.instance.options.map((e) => e.metadata),
  };
  for (final axis in registries.entries) {
    for (final option in axis.value) {
      testWidgets(
        'export ${axis.key} ${option.id} with background',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
            await (FontLoader('PreviewRoboto')..addFont(
                  File(
                    'test/assets/fonts/Roboto-Regular.ttf',
                  ).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
            if (option.id == AppPlayerLyricsRegistry.kineticId) {
              // Flutter tests have no platform serif fonts; use a deterministic
              // Latin substitute while keeping the shared CJK fallback.
              await (FontLoader('Songti SC')..addFont(
                    File(
                      'test/assets/fonts/Roboto-Regular.ttf',
                    ).readAsBytes().then(ByteData.sublistView),
                  ))
                  .load();
            }
            await (FontLoader('PreviewCjk')..addFont(
                  File(
                    'test/assets/fonts/DroidSansFallback-PreviewSubset.ttf',
                  ).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
          });
          const key = ValueKey('component-export');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appConfigProvider.overrideWith(_PreviewConfig.new)],
              child: MaterialApp(
                theme: ThemeData.dark().copyWith(
                  textTheme: ThemeData.dark().textTheme.apply(
                    fontFamily: 'PreviewRoboto',
                    fontFamilyFallback: ['PreviewCjk'],
                  ),
                ),
                home: RepaintBoundary(
                  key: key,
                  child: Material(
                    child: PlayerStyleComponentPreview(
                      axis: axis.key,
                      optionId: option.id,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (axis.key == 'lyrics') {
            expect(find.text('暂无歌词'), findsNothing);
            expect(find.byType(CustomPaint), findsWidgets);
          }
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final rgba = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              for (var i = 3; i < rgba.lengthInBytes; i += 4) {
                expect(
                  rgba.getUint8(i),
                  255,
                  reason: 'Previews must include an opaque background',
                );
              }
              final png = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                option.previewAsset,
              ).writeAsBytes(png.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
          await tester.pumpWidget(const SizedBox.shrink());
        },
        skip: !enabled || (axisFilter.isNotEmpty && axisFilter != axis.key),
      );
    }
  }
}

class _PreviewConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');
}
