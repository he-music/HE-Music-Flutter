import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skins/orbital_observatory_skin.dart';

const _size = Size(390, 844);
const _key = ValueKey('orbital-motion-visibility');

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('orbital ${brightness.name} motion is visible at phone size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _size;
      addTearDown(tester.view.reset);
      final skin = orbitalObservatorySkin();
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark(skin)
              : AppTheme.light(skin),
          home: MediaQuery(
            data: const MediaQueryData(size: _size),
            child: RepaintBoundary(
              key: _key,
              child: AppSkinBackgroundLayer(skin: skin, enableAnimation: true),
            ),
          ),
        ),
      );
      final rive = find.byKey(const ValueKey('app-skin-rive-widget'));
      final wallpaper = find.descendant(
        of: find.byKey(const ValueKey('app-skin-wallpaper')),
        matching: find.byType(RawImage),
      );
      for (var attempt = 0; attempt < 150; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (rive.evaluate().isNotEmpty &&
            wallpaper.evaluate().isNotEmpty &&
            tester.widget<RawImage>(wallpaper).image != null) {
          break;
        }
      }
      expect(rive, findsOneWidget);
      expect(wallpaper, findsOneWidget);
      final before = await _capture(tester);
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(microseconds: 33333));
      }
      final after = await _capture(tester);
      final dark = brightness == Brightness.dark;
      final region = dark
          ? const Rect.fromLTWH(0, 140, 390, 180)
          : const Rect.fromLTWH(0, 390, 390, 300);
      final changed = _changedFraction(before, after, region);
      // A visible animation must change a substantial local area within two
      // seconds. This is a rendering regression guard, not aesthetic approval.
      expect(
        changed,
        greaterThan(dark ? 0.08 : 0.04),
        reason:
            '${brightness.name}: only ${(changed * 100).toStringAsFixed(2)}% '
            'of the motion area changed by more than 3% luminance in 2 seconds',
      );
      if (dark) {
        expect(
          _changedFraction(before, after, const Rect.fromLTWH(280, 0, 110, 80)),
          0,
          reason: 'The open star field must remain steady',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  return pixels!;
}

double _changedFraction(Uint8List before, Uint8List after, Rect region) {
  var changed = 0;
  var total = 0;
  for (var y = region.top.toInt(); y < region.bottom.toInt(); y++) {
    for (var x = region.left.toInt(); x < region.right.toInt(); x++) {
      final index = (y * _size.width.toInt() + x) * 4;
      final delta =
          (0.2126 * (before[index] - after[index]) +
                  0.7152 * (before[index + 1] - after[index + 1]) +
                  0.0722 * (before[index + 2] - after[index + 2]))
              .abs();
      if (delta > 255 * 0.03) changed++;
      total++;
    }
  }
  return changed / total;
}
