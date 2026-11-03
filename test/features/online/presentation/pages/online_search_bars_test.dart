import 'dart:ui' show Tristate;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';

void main() {
  testWidgets(
    'Material source pills stay compact inside centered 48dp targets',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPlatformBar(
              loading: false,
              platforms: [
                for (final label in ['小黄', '小鹅'])
                  SearchPlatform(
                    id: label,
                    label: label,
                    available: true,
                    featureSupportFlag: PlatformFeatureSupportFlag.searchSong,
                  ),
              ],
              requiredFeatureFlag: PlatformFeatureSupportFlag.searchSong,
              selectedPlatformId: '小黄',
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      final label = find.text('小黄');
      final target = find.ancestor(of: label, matching: find.byType(InkWell));
      final pill = find.ancestor(of: label, matching: find.byType(Ink));
      final hitRect = tester.getRect(target);
      final pillRect = tester.getRect(pill);
      expect(hitRect.height, 48);
      expect(pillRect.height, 36);
      expect(pillRect.width, greaterThan(pillRect.height));
      expect(pillRect.center.dy, hitRect.center.dy);
      expect(tester.getCenter(label).dy, closeTo(pillRect.center.dy, 0.01));
      await tester.tapAt(Offset(hitRect.center.dx, hitRect.top + 1));
      expect(selected, '小黄');
      expect(tester.takeException(), isNull);
    },
  );
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style search sources keep independent accessible targets at large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final feature = PlatformFeatureSupportFlag.searchSong;
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SearchPlatformBar(
                  loading: false,
                  platforms: [
                    SearchPlatform(
                      id: 'a',
                      label: 'A',
                      available: true,
                      featureSupportFlag: feature,
                    ),
                    SearchPlatform(
                      id: 'b',
                      label: 'B',
                      available: true,
                      featureSupportFlag: feature,
                    ),
                    SearchPlatform(
                      id: 'disabled',
                      label: 'Unavailable',
                      available: false,
                      featureSupportFlag: feature,
                    ),
                  ],
                  requiredFeatureFlag: feature,
                  selectedPlatformId: 'a',
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        final targetType = style == AppUiStyle.cupertino
            ? CupertinoButton
            : InkWell;
        Finder target(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byType(targetType),
        );
        final first = tester.getRect(target('A'));
        final second = tester.getRect(target('B'));
        final extent = style == AppUiStyle.cupertino ? 44 : 48;
        expect(first.height, greaterThanOrEqualTo(extent));
        expect(first.width, greaterThanOrEqualTo(extent));
        expect(first.overlaps(second), isFalse);
        final selectedNode = tester
            .getSemantics(find.text('A'))
            .getSemanticsData();
        expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);
        expect(selectedNode.flagsCollection.isButton, isTrue);
        expect(find.text('Unavailable'), findsNothing);
        await tester.tapAt(Offset(first.right - 1, first.center.dy));
        expect(selected, 'a');
        await tester.tapAt(Offset(second.left + 1, second.center.dy));
        expect(selected, 'b');
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
