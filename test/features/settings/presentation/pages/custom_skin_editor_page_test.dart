import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/settings/presentation/controllers/custom_skin_editor_controller.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/custom_skin_editor_page.dart';

void main() {
  testWidgets('focal drag stays local and commits once when released', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _CountingSkinEditorController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          customSkinEditorControllerProvider.overrideWith(() {
            controller = _CountingSkinEditorController();
            return controller;
          }),
        ],
        child: const MaterialApp(home: CustomSkinEditorPage()),
      ),
    );
    await tester.pump();

    final lightPreview = find.byKey(
      const ValueKey<String>('custom-preview-light'),
    );
    final darkPreview = find.byKey(
      const ValueKey<String>('custom-preview-dark'),
    );
    final dragTarget = find.descendant(
      of: lightPreview,
      matching: find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onPanUpdate != null,
      ),
    );
    await tester.ensureVisible(dragTarget);
    await tester.pump();
    final hitTarget = dragTarget.hitTestable();
    expect(hitTarget, findsOneWidget);
    await tester.timedDrag(
      hitTarget,
      const Offset(-60, 0),
      const Duration(milliseconds: 160),
    );
    await tester.pump();

    final lightAlignment = tester
        .widget<Image>(
          find.descendant(of: lightPreview, matching: find.byType(Image)),
        )
        .alignment
        .resolve(TextDirection.ltr);
    final darkAlignment = tester
        .widget<Image>(
          find.descendant(of: darkPreview, matching: find.byType(Image)),
        )
        .alignment
        .resolve(TextDirection.ltr);
    expect(controller.focalCommitCount, 1);
    expect(lightAlignment.x, greaterThan(0));
    expect(darkAlignment, lightAlignment);
    expect(
      controller.currentState.draft!.focalX,
      closeTo(lightAlignment.x, 0.0001),
    );
    expect(
      controller.currentState.draft!.focalY,
      closeTo(lightAlignment.y, 0.0001),
    );
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}

class _CountingSkinEditorController extends CustomSkinEditorController {
  int focalCommitCount = 0;

  CustomSkinEditorState get currentState => state;

  @override
  CustomSkinEditorState build() {
    return CustomSkinEditorState(
      phase: CustomSkinEditorPhase.ready,
      originalConfig: _draft.toConfig(),
      draft: _draft,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  void setFocalPoint(double x, double y) {
    focalCommitCount += 1;
    super.setFocalPoint(x, y);
  }
}

final _previewBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
  'AQUBAScY42YAAAAASUVORK5CYII=',
);

final _draft = CustomSkinEditorDraft(
  revision: 'test_revision',
  lightAssetPath: 'skins/custom_image/test_revision/wallpaper_light.png',
  darkAssetPath: 'skins/custom_image/test_revision/wallpaper_dark.png',
  candidateColors: const <int>[0xFF336699],
  seedColor: 0xFF336699,
  focalX: 0,
  focalY: 0,
  sourceWidth: 2000,
  sourceHeight: 800,
  lightPreviewBytes: _previewBytes,
  darkPreviewBytes: _previewBytes,
);
