import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/app_alert_dialog.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'glass confirmation centers full-width actions in $brightness at ${textScale}x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          bool? result;
          await tester.pumpWidget(
            AppGlassScope(
              enabled: true,
              mode: AppGlassMode.high,
              child: GlassAdaptiveScope(
                minQuality: GlassQuality.minimal,
                maxQuality: GlassQuality.minimal,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () async {
                          result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AppAlertDialog(
                              title: const Text('删除全部手动选择歌词？'),
                              content: const Text('所有歌曲将恢复默认歌词。此操作无法撤销。'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('全部删除'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          final dialog = tester.widget<GlassDialog>(find.byType(GlassDialog));
          expect(dialog.message, '所有歌曲将恢复默认歌词。此操作无法撤销。');
          expect(dialog.content, isNull);
          expect(dialog.actions.last.isDestructive, isTrue);
          expect(find.byType(GlassCard), findsOneWidget);
          expect(find.byType(GlassButton), findsNothing);
          final buttons = find.descendant(
            of: find.byType(GlassDialog),
            matching: find.byType(CupertinoButton),
          );
          expect(buttons, findsNWidgets(2));
          final cancelRect = tester.getRect(buttons.at(0));
          final deleteRect = tester.getRect(buttons.at(1));
          expect(cancelRect.width, closeTo(deleteRect.width, 0.01));
          expect(cancelRect.height, greaterThanOrEqualTo(44));
          expect(deleteRect.height, greaterThanOrEqualTo(44));
          for (final (index, label) in ['取消', '全部删除'].indexed) {
            final buttonRect = tester.getRect(buttons.at(index));
            final labelRect = tester.getRect(find.text(label));
            expect(labelRect.center.dx, closeTo(buttonRect.center.dx, 0.01));
            expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
            expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
            expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
            expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
          }
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(result, isFalse);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('全部删除'));
          await tester.pumpAndSettle();
          expect(result, isTrue);
          expect(find.byType(GlassDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('three glass dialog actions stretch without nested glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      GlassAdaptiveScope(
        minQuality: GlassQuality.minimal,
        maxQuality: GlassQuality.minimal,
        child: MaterialApp(
          home: Scaffold(
            body: GlassDialog(
              title: 'Save changes?',
              actions: [
                GlassDialogAction(label: 'Discard', onPressed: _noop),
                GlassDialogAction(label: 'Cancel', onPressed: _noop),
                GlassDialogAction(
                  label: 'Save',
                  isPrimary: true,
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final buttons = find.byType(CupertinoButton);
    expect(buttons, findsNWidgets(3));
    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(GlassButton), findsNothing);
    final firstRect = tester.getRect(buttons.first);
    for (var index = 1; index < 3; index++) {
      final rect = tester.getRect(buttons.at(index));
      expect(rect.width, closeTo(firstRect.width, 0.01));
      expect(rect.left, closeTo(firstRect.left, 0.01));
      expect(rect.top, greaterThan(firstRect.bottom));
    }
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
