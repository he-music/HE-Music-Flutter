import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final glass in [true, false]) {
    testWidgets('search focus feedback follows Tab navigation (glass=$glass)', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'abc');
      final focus = FocusNode();
      final before = FocusNode();
      final after = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(before.dispose);
      addTearDown(after.dispose);
      final changes = <String>[];
      String? submitted;
      await tester.pumpWidget(
        _app(
          controller: controller,
          focus: focus,
          before: before,
          after: after,
          glass: glass,
          onChanged: changes.add,
          onSubmitted: (value) => submitted = value,
        ),
      );
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(_showsRing(tester, glass: glass), isFalse);

      // An editing key switches Flutter to keyboard highlight mode, but must
      // not turn automatic focus into a navigation indicator.
      controller.selection = TextSelection.collapsed(offset: 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(controller.text, 'ab');
      expect(changes.last, 'ab');
      expect(_showsRing(tester, glass: glass), isFalse);
      await _capturePreview(tester, glass: glass, state: 'editing');

      before.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(_showsRing(tester, glass: glass), isTrue);
      await _capturePreview(tester, glass: glass, state: 'tab');

      // Editing after Tab hides the navigation indicator without replacing
      // the editable or losing its selection.
      final editable = tester.state(find.byType(EditableText));
      controller.selection = TextSelection.collapsed(offset: 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(controller.text, 'a');
      expect(controller.selection.baseOffset, 1);
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(_showsRing(tester, glass: glass), isFalse);

      after.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      // Reverse traversal first visits the clear button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(_showsRing(tester, glass: glass), isTrue);

      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(_showsRing(tester, glass: glass), isFalse);
      await tester.enterText(find.byType(EditableText), 'query');
      await tester.pumpAndSettle();
      expect(_showsRing(tester, glass: glass), isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submitted, 'query');

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(changes.last, isEmpty);
      expect(focus.hasFocus, isTrue);
      expect(_showsRing(tester, glass: glass), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'ordinary glass inputs retain their default keyboard focus ring',
    (tester) async {
      final controller = TextEditingController(text: 'abc');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        GlassAdaptiveScope(
          minQuality: GlassQuality.minimal,
          maxQuality: GlassQuality.minimal,
          child: MaterialApp(
            home: Scaffold(
              body: GlassTextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editable = tester.state(find.byType(EditableText));
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(_showsRing(tester, glass: true), isTrue);
      expect(controller.text, 'ab');
      expect(tester.state(find.byType(EditableText)), same(editable));
    },
  );
}

bool _showsRing(WidgetTester tester, {required bool glass}) {
  if (!glass) {
    final field = tester.widget<TextField>(find.byType(TextField));
    return field.focusNode!.hasFocus &&
        field.decoration!.focusedBorder!.borderSide.style != BorderStyle.none;
  }
  // Inspect the painted ring, without importing the dependency's private API.
  return find
      .byWidgetPredicate((widget) {
        return widget is CustomPaint &&
            widget.painter.runtimeType.toString() == 'GlassFocusRingPainter';
      })
      .evaluate()
      .isNotEmpty;
}

Future<void> _capturePreview(
  WidgetTester tester, {
  required bool glass,
  required String state,
}) async {
  if (!const bool.fromEnvironment('CAPTURE_SEARCH_FOCUS_PREVIEWS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '/tmp/he-music-search-focus-${glass ? 'glass' : 'material'}-$state.png',
      ).writeAsBytes(png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget _app({
  required TextEditingController controller,
  required FocusNode focus,
  required FocusNode before,
  required FocusNode after,
  required bool glass,
  required ValueChanged<String> onChanged,
  required ValueChanged<String> onSubmitted,
}) => AppGlassScope(
  enabled: true,
  mode: glass ? AppGlassMode.high : AppGlassMode.powerSaving,
  child: GlassAdaptiveScope(
    minQuality: GlassQuality.minimal,
    maxQuality: GlassQuality.minimal,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  focusNode: before,
                  onPressed: () {},
                  child: const Text('Before'),
                ),
                AppSearchField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  placeholderPrimary: 'Search',
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
                TextButton(
                  focusNode: after,
                  onPressed: () {},
                  child: const Text('After'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
