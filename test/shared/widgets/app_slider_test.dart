import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_slider.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('Cupertino buffer follows $direction track direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppUiStyle.cupertino,
          Directionality(
            textDirection: direction,
            child: AppSlider(
              value: .1,
              secondaryTrackValue: .25,
              onChanged: _noop,
            ),
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('app-slider-secondary-track')),
          )
          .painter!;
      final pixels = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(ui.Canvas(recorder), const Size(200, 48));
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 48);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
      final leftAlpha = pixels!.getUint8((24 * 200 + 20) * 4 + 3);
      final rightAlpha = pixels.getUint8((24 * 200 + 180) * 4 + 3);
      expect(
        direction == TextDirection.ltr ? leftAlpha : rightAlpha,
        greaterThan(0),
      );
      expect(direction == TextDirection.ltr ? rightAlpha : leftAlpha, 0);
    });
  }
  for (final style in AppUiStyle.values) {
    testWidgets('$style dragging edits then commits the final value', (
      tester,
    ) async {
      final value = ValueNotifier<double>(.5);
      addTearDown(value.dispose);
      final events = <(String, double)>[];
      await tester.pumpWidget(
        _app(
          style,
          ValueListenableBuilder<double>(
            valueListenable: value,
            builder: (context, current, child) => AppSlider(
              value: current,
              divisions: 20,
              onChangeStart: (next) => events.add(('start', next)),
              onChanged: (next) {
                events.add(('change', next));
                value.value = next;
              },
              onChangeEnd: (next) => events.add(('end', next)),
            ),
          ),
        ),
      );
      expect(
        find.byType(style == AppUiStyle.cupertino ? CupertinoSlider : Slider),
        findsOneWidget,
      );
      await tester.drag(find.byType(AppSlider), const Offset(75, 0));
      await tester.pumpAndSettle();
      expect(value.value, greaterThan(.5));
      expect(events.first, ('start', .5));
      expect(events.last, ('end', value.value));
      expect(events.where((event) => event.$1 == 'start'), hasLength(1));
      expect(events.where((event) => event.$1 == 'end'), hasLength(1));
      expect(events.where((event) => event.$1 == 'change'), isNotEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$style disabled slider ignores pointer edits', (tester) async {
      final events = <double>[];
      await tester.pumpWidget(
        _app(
          style,
          AppSlider(
            value: .5,
            onChanged: null,
            onChangeStart: events.add,
            onChangeEnd: events.add,
          ),
        ),
      );
      await tester.drag(find.byType(AppSlider), const Offset(75, 0));
      await tester.pumpAndSettle();
      expect(events, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cupertino thumb defaults to the theme primary color', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.orange);
    await tester.pumpWidget(
      AppUiStyleScope(
        style: AppUiStyle.cupertino,
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const Scaffold(body: AppSlider(value: .5, onChanged: _noop)),
        ),
      ),
    );
    final slider = tester.widget<CupertinoSlider>(find.byType(CupertinoSlider));
    expect(slider.thumbColor, scheme.primary);
    expect(slider.activeColor, scheme.primary);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'Cupertino keyboard edits respect $direction and range limits',
      (tester) async {
        final value = ValueNotifier<double>(1);
        addTearDown(value.dispose);
        final events = <(String, double)>[];
        await tester.pumpWidget(
          _app(
            AppUiStyle.cupertino,
            Directionality(
              textDirection: direction,
              child: ValueListenableBuilder<double>(
                valueListenable: value,
                builder: (context, current, child) => AppSlider(
                  value: current,
                  min: .5,
                  max: 2,
                  divisions: 6,
                  onChangeStart: (next) => events.add(('start', next)),
                  onChanged: (next) {
                    events.add(('change', next));
                    value.value = next;
                  },
                  onChangeEnd: (next) => events.add(('end', next)),
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        final next = direction == TextDirection.ltr ? 1.25 : .75;
        expect(events, [('start', 1.0), ('change', next), ('end', next)]);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(value.value, .5);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(value.value, 2);
        events.clear();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(events, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cupertino accessibility edits announce formatted values and commit',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final value = ValueNotifier<double>(1);
        addTearDown(value.dispose);
        final committed = <double>[];
        await tester.pumpWidget(
          _app(
            AppUiStyle.cupertino,
            ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, current, child) => AppSlider(
                value: current,
                min: .5,
                max: 2,
                divisions: 6,
                onChanged: (next) => value.value = next,
                onChangeEnd: committed.add,
                semanticFormatterCallback: (next) =>
                    '${next.toStringAsFixed(2)}x',
              ),
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(AppSlider));
        expect(node.getSemanticsData().value, '1.00x');
        expect(node.getSemanticsData().increasedValue, '1.25x');
        expect(node.getSemanticsData().decreasedValue, '0.75x');
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          node.id,
          ui.SemanticsAction.increase,
        );
        await tester.pump();
        expect(value.value, 1.25);
        expect(committed, [1.25]);
        expect(
          tester.getSemantics(find.byType(AppSlider)).getSemanticsData().value,
          '1.25x',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

void _noop(double value) {}

Widget _app(AppUiStyle style, Widget child) => AppUiStyleScope(
  style: style,
  child: MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  ),
);
