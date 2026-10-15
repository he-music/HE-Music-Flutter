import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('high quality keeps search standard and honors the skin radius', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, mode: AppGlassMode.high));
    await tester.pumpAndSettle();
    final field = tester.widget<GlassTextField>(find.byType(GlassTextField));
    expect(field.quality, GlassQuality.standard);
    final context = tester.element(find.byType(AppSearchField));
    expect(
      (field.shape as LiquidRoundedRectangle).borderRadius,
      AppSearchField.radiusFor(context),
    );
  });

  for (final highContrast in [false, true]) {
    testWidgets(
      'search fallback is opaque and focusable with highContrast=$highContrast',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          _app(
            controller,
            focus: focus,
            highContrast: highContrast,
            mode: highContrast
                ? AppGlassMode.automatic
                : AppGlassMode.powerSaving,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GlassTextField), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration!.fillColor!.a, 1);
        expect(
          field.decoration!.focusedBorder!.borderSide.style,
          highContrast ? BorderStyle.solid : BorderStyle.none,
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        expect(
          tester.getSize(find.byType(AppSearchField)).height,
          greaterThanOrEqualTo(48),
        );
      },
    );
  }
}

Widget _app(
  TextEditingController controller, {
  required AppGlassMode mode,
  bool highContrast = false,
  FocusNode? focus,
}) => AppGlassScope(
  enabled: true,
  mode: mode,
  child: GlassAdaptiveScope(
    minQuality: GlassQuality.minimal,
    maxQuality: GlassQuality.minimal,
    child: MaterialApp(
      theme: AppTheme.light(citySoundCreatorSkin()),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Center(
            child: SizedBox(
              width: 300,
              child: AppSearchField(
                controller: controller,
                focusNode: focus,
                placeholderPrimary: '搜索',
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
