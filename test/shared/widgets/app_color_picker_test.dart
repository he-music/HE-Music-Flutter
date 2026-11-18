import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/app_color_picker.dart';

void main() {
  testWidgets('drag previews colors and commits only once on release', (
    tester,
  ) async {
    final previews = <Color>[];
    final commits = <Color>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AppColorPicker(
              color: Colors.red,
              onChanged: previews.add,
              onChangeEnd: commits.add,
              hueLabel: 'Hue',
              saturationLabel: 'Saturation',
              brightnessLabel: 'Brightness',
            ),
          ),
        ),
      ),
    );
    final plane = tester.getRect(
      find.byKey(const ValueKey('color-picker-saturation-value')),
    );
    final gesture = await tester.startGesture(plane.center);
    await gesture.moveTo(
      plane.topLeft + Offset(plane.width * .7, plane.height * .25),
    );
    await tester.pump();
    await gesture.moveTo(
      plane.topLeft + Offset(plane.width * .8, plane.height * .2),
    );
    await tester.pump();
    expect(previews.length, greaterThan(1));
    expect(commits, isEmpty);
    final hsv = HSVColor.fromColor(previews.last);
    expect(hsv.saturation, closeTo(.8, .01));
    expect(hsv.value, closeTo(.8, .01));
    await gesture.up();
    await tester.pump();
    expect(commits, [previews.last]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hue chosen on black survives restoring brightness and keyboard editing',
    (tester) async {
      final commits = <Color>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AppColorPicker(
                color: Colors.black,
                onChanged: (_) {},
                onChangeEnd: commits.add,
                hueLabel: 'Hue',
                saturationLabel: 'Saturation',
                brightnessLabel: 'Brightness',
              ),
            ),
          ),
        ),
      );
      final hue = tester.getRect(
        find.byKey(const ValueKey('color-picker-hue')),
      );
      await tester.tapAt(
        hue.topLeft + Offset(hue.width * 2 / 3, hue.height / 2),
      );
      await tester.pump();
      expect(commits.last, Colors.black);
      final plane = tester.getRect(
        find.byKey(const ValueKey('color-picker-saturation-value')),
      );
      await tester.tapAt(
        plane.topLeft + Offset(plane.width * .6, plane.height * .3),
      );
      await tester.pump();
      var color = HSVColor.fromColor(commits.last);
      expect(color.hue, closeTo(240, 1));
      expect(color.value, closeTo(.7, .01));
      final before = color.saturation;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      color = HSVColor.fromColor(commits.last);
      expect(color.saturation, greaterThan(before));
      expect(tester.takeException(), isNull);
    },
  );
}
