import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/widgets/sheet_music_reader.dart';

import 'cache_sheet_images.dart';

void main() {
  const urls = [
    'https://example.com/first.png',
    'https://example.com/second.png',
  ];

  Future<void> pumpReader(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await cacheSheetImages(tester, urls);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(
            body: SheetMusicReader(
              pageUrls: urls,
              title: '测试曲谱',
              locale: 'zh',
              initialFitPage: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PhotoViewGallery gallery(WidgetTester tester, String key) =>
      tester.widget<PhotoViewGallery>(find.byKey(ValueKey(key)));
  double scale(WidgetTester tester, Finder scope) => tester
      .widget<Image>(
        find.descendant(of: scope, matching: find.byType(Image)).first,
      )
      .width!;

  testWidgets(
    'PhotoViewGallery owns double-tap zoom and permits paging after reset',
    (tester) async {
      await pumpReader(tester);
      final pager = find.byKey(const ValueKey('sheet-reader-pager'));
      final point = tester.getCenter(pager);
      final initialScale = scale(tester, pager);
      Future<void> doubleTap() async {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(point);
        await tester.pumpAndSettle();
      }

      expect(find.byType(PhotoView), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);
      await doubleTap();
      expect(scale(tester, pager), greaterThan(initialScale));
      // 恢复画廊的初始缩放状态，再确认横向翻页。
      await doubleTap();
      await doubleTap();
      await tester.drag(pager, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery handles pinch and panning without turning an interior zoomed page',
    (tester) async {
      await pumpReader(tester);
      final pager = find.byKey(const ValueKey('sheet-reader-pager'));
      final before = scale(tester, pager);
      final center = tester.getCenter(pager);
      final left = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      await left.moveTo(center - const Offset(120, 0));
      await right.moveTo(center + const Offset(120, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(scale(tester, pager), greaterThan(before));
      await tester.drag(pager, const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 0);
    },
  );

  testWidgets('retrying a failed image keeps its page selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SheetMusicReader(
            pageUrls: [
              'https://example.com/missing-1.png',
              'https://example.com/missing-2.png',
            ],
            title: '曲谱',
            locale: 'zh',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 1);
    await tester.tap(find.text('重试').last);
    await tester.pumpAndSettle();
    expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 1);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('system reduce-motion makes explicit page changes immediate', (
    tester,
  ) async {
    await pumpReader(tester, reduceMotion: true);
    await tester.tap(find.byTooltip('下一页'));
    await tester.pump();
    expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 1);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'gallery tap opens fullscreen, toggles controls, and preserves the exit page',
    (tester) async {
      await pumpReader(tester);
      final pager = find.byKey(const ValueKey('sheet-reader-pager'));
      await tester.tapAt(tester.getCenter(pager));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final fullscreen = find.byKey(const ValueKey('sheet-fullscreen-pager'));
      expect(fullscreen, findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
      final point = tester.getCenter(fullscreen);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭'), findsNothing);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(gallery(tester, 'sheet-fullscreen-pager').pageController!.page, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(fullscreen, findsNothing);
      expect(gallery(tester, 'sheet-reader-pager').pageController!.page, 1);
    },
  );
}
