import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  group('SectionTitleSkeleton', () {
    testWidgets('应渲染 SkeletonBox', (tester) async {
      await tester.pumpWidget(_wrap(const SectionTitleSkeleton(width: 100)));

      expect(find.byType(SkeletonBox), findsOneWidget);
    });
  });

  group('PlazaPlatformTabsSkeleton', () {
    testWidgets('应渲染 4 个 SkeletonBox', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(height: 50, child: PlazaPlatformTabsSkeleton())),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(4));
    });
  });

  group('PlazaFilterPanelSkeleton', () {
    testWidgets('默认应渲染 2 行', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(height: 200, child: PlazaFilterPanelSkeleton())),
      );

      // 每行 4 个 SkeletonBox
      expect(find.byType(SkeletonBox), findsNWidgets(8));
    });

    testWidgets('trailingButton 为 true 时每行多一个按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            height: 200,
            child: PlazaFilterPanelSkeleton(trailingButton: true),
          ),
        ),
      );

      // 2 行 × (4 chip + 1 button) = 10
      expect(find.byType(SkeletonBox), findsNWidgets(10));
    });

    testWidgets('rowCount 可自定义', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            height: 300,
            child: PlazaFilterPanelSkeleton(rowCount: 3),
          ),
        ),
      );

      // 3 行 × 4 = 12
      expect(find.byType(SkeletonBox), findsNWidgets(12));
    });
  });

  group('GridCardSkeleton', () {
    testWidgets('应渲染 3 个 SkeletonBox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: SizedBox(width: 200, height: 300, child: GridCardSkeleton()),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(3));
    });

    testWidgets('高度接近实际电台 grid 单元格时不应溢出', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 164.8,
            height: 196.2,
            child: GridCardSkeleton(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('PlazaGridSkeleton', () {
    testWidgets('应渲染 GridView', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 400,
            child: PlazaGridSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('PlazaVideoGridSkeleton', () {
    testWidgets('应渲染 GridView', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 400,
            child: PlazaVideoGridSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('VideoGridCardSkeleton', () {
    testWidgets('应渲染 5 个 SkeletonBox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 180,
            height: 150,
            child: VideoGridCardSkeleton(),
          ),
        ),
      );

      // 封面 1 + 覆盖角标 2 + 标题/作者 2 = 5
      expect(find.byType(SkeletonBox), findsNWidgets(5));
    });
  });

  group('VideoCardSkeleton', () {
    testWidgets('应渲染 6 个 SkeletonBox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(width: 400, height: 120, child: VideoCardSkeleton()),
        ),
      );

      // 封面 1 + 时长覆盖 2 + 文字 3 = 6
      expect(find.byType(SkeletonBox), findsNWidgets(6));
    });
  });

  group('KeywordWrapSkeleton', () {
    testWidgets('默认应渲染 6 个 SkeletonBox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(width: 400, height: 100, child: KeywordWrapSkeleton()),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(6));
    });
  });

  group('HotKeywordListSkeleton', () {
    testWidgets('默认应渲染 8 行', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 600,
            child: HotKeywordListSkeleton(),
          ),
        ),
      );

      // 每行 2 个 SkeletonBox（序号 + 关键词）
      expect(find.byType(SkeletonBox), findsNWidgets(16));
    });

    testWidgets('itemCount 可自定义', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 300,
            child: HotKeywordListSkeleton(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(6));
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
