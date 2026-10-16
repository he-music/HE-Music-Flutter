import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'cache_sheet_images.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/core/error/failure.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_info.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_not_implemented_exception.dart';
import 'package:he_music_flutter/features/sheet_music/domain/repositories/sheet_music_repository.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/pages/sheet_music_page.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/providers/sheet_music_providers.dart';
import 'package:he_music_flutter/features/sheet_music/domain/repositories/sheet_music_download_repository.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/widgets/sheet_music_reader.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_player_scaffold.dart';
import 'package:he_music_flutter/shared/helpers/detail_song_action_handler.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/widgets/sheet_music_loading.dart';

void main() {
  testWidgets('list loading resolves to a genuine empty state', (tester) async {
    final pending = Completer<List<SheetMusicInfo>>();
    final repository = _Repository()..listResult = () => pending.future;
    await _pump(tester, repository);
    expect(find.byType(SheetMusicListSkeleton), findsOneWidget);
    expect(find.text('暂无曲谱'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('暂无曲谱'), findsOneWidget);
    expect(repository.listCalls, [(platform: 'qq', songId: '000123')]);
  });

  for (final detail in [false, true]) {
    for (final skinAnimation in [false, true]) {
      for (final reducedMotion in [false, true]) {
        testWidgets(
          'loading skeleton respects system motion independently of skin animation (detail=$detail skin=$skinAnimation reduced=$reducedMotion)',
          (tester) async {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(disableAnimations: reducedMotion);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
            final list = Completer<List<SheetMusicInfo>>();
            final sheet = Completer<SheetMusicInfo>();
            final repository = _Repository();
            repository.listResult = () => list.future;
            repository.detailResult = () => sheet.future;
            await _pump(
              tester,
              repository,
              detail: detail,
              skinAnimation: skinAnimation,
            );
            await tester.pump();
            final skeleton = find.byType(
              detail ? SheetMusicDetailSkeleton : SheetMusicListSkeleton,
            );
            expect(skeleton, findsOneWidget);
            expect(find.byType(SkeletonBox), findsWidgets);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            final box = tester.element(find.byType(SkeletonBox).first);
            expect(MediaQuery.disableAnimationsOf(box), reducedMotion);
            expect(TickerMode.valuesOf(box).enabled, !reducedMotion);
            expect(
              ProviderScope.containerOf(
                box,
              ).read(appConfigProvider).enableSkinAnimation,
              skinAnimation,
            );
            await tester.pump(const Duration(seconds: 1));
            expect(tester.binding.hasScheduledFrame, !reducedMotion);

            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(disableAnimations: !reducedMotion);
            await tester.pump();
            expect(MediaQuery.disableAnimationsOf(box), !reducedMotion);
            expect(TickerMode.valuesOf(box).enabled, reducedMotion);

            list.complete([]);
            sheet.complete(const SheetMusicInfo());
            await tester.pumpAndSettle();
            expect(skeleton, findsNothing);
            expect(find.byType(SkeletonBox), findsNothing);
            expect(find.text(detail ? '曲谱资源暂不可用' : '暂无曲谱'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final detail in [false, true]) {
    testWidgets(
      'NotImplemented shows unopened state and supports explicit retry (detail=$detail)',
      (tester) async {
        final repository = _Repository();
        repository.listResult = () async =>
            throw const SheetMusicNotImplementedException();
        repository.detailResult = () async =>
            throw const SheetMusicNotImplementedException();
        await _pump(tester, repository, detail: detail);
        await tester.pumpAndSettle();
        expect(find.text('曲谱功能暂未开放'), findsOneWidget);
        expect(find.text('暂无曲谱'), findsNothing);
        expect(find.text('曲谱资源暂不可用'), findsNothing);
        // 平台尚未实现时不会后台自动重试；只在点击重试后请求。
        await tester.pump(const Duration(seconds: 5));
        expect(
          detail ? repository.detailCalls.length : repository.listCalls.length,
          1,
        );
        repository.listResult = () async => [];
        repository.detailResult = () async => const SheetMusicInfo(title: '详情');
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(
          detail ? repository.detailCalls.length : repository.listCalls.length,
          2,
        );
        expect(find.text(detail ? '曲谱资源暂不可用' : '暂无曲谱'), findsOneWidget);
      },
    );

    testWidgets('ordinary request failure can recover (detail=$detail)', (
      tester,
    ) async {
      final repository = _Repository();
      repository.listResult = () async =>
          throw const AppException(NetworkFailure('连接失败'));
      repository.detailResult = () async =>
          throw const AppException(NetworkFailure('连接失败'));
      await _pump(tester, repository, detail: detail);
      await tester.pumpAndSettle();
      expect(find.text('连接失败'), findsOneWidget);
      repository.listResult = () async => [
        const SheetMusicInfo(id: '001', title: '恢复曲谱'),
      ];
      repository.detailResult = () async => const SheetMusicInfo(title: '恢复详情');
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text(detail ? '恢复详情' : '恢复曲谱'), findsOneWidget);
    });
  }

  testWidgets(
    'opening a list item fetches detail with original song identity, ignoring list pages',
    (tester) async {
      final repository = _Repository()
        ..listResult = () async => [
          const SheetMusicInfo(
            id: '0009007199254740993',
            title: '列表曲谱',
            uploader: '编曲者',
            instruments: ['吉他'],
            notationTypes: ['简谱', '六线谱'],
            arrangementType: '弹唱版',
            difficulty: '初级',
            pageUrls: ['https://example.com/list-only.jpg'],
            platform: 'netease',
            originalKey: 'C',
            pageCount: 3,
          ),
        ];
      repository.detailResult = () async =>
          const SheetMusicInfo(title: '接口详情', pageCount: 7, bpm: 0);
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      expect(find.textContaining('上传者：编曲者'), findsNothing);
      expect(find.textContaining('C调 · 3页'), findsOneWidget);
      expect(find.textContaining('吉他 · 简谱 · 六线谱 · 弹唱版 · 初级'), findsOneWidget);
      expect(repository.detailCalls, isEmpty);
      await tester.tap(find.text('列表曲谱'));
      await tester.pumpAndSettle();
      expect(repository.detailCalls, [
        (platform: 'qq', songId: '000123', id: '0009007199254740993'),
      ]);
      expect(find.text('接口详情'), findsOneWidget);
      expect(find.text('曲谱资源暂不可用'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('BPM'), findsNothing);
    },
  );

  testWidgets('list shows compact key and page count and hides absent values', (
    tester,
  ) async {
    final repository = _Repository()
      ..listResult = () async => const [
        SheetMusicInfo(
          id: 'one',
          title: '完整',
          originalKey: 'C',
          pageCount: 10,
          uploader: '上传者',
        ),
        SheetMusicInfo(id: 'two', title: '只有页数', pageCount: 10),
        SheetMusicInfo(id: 'three', title: '只有调', originalKey: 'G'),
        SheetMusicInfo(id: 'four', title: '都没有'),
      ];
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    for (final item in [
      ('完整', 'C调 · 10页'),
      ('只有页数', '10页'),
      ('只有调', 'G调'),
      ('都没有', ''),
    ]) {
      final row = find.widgetWithText(ListTile, item.$1);
      expect(
        find.descendant(of: row, matching: find.text(item.$2)),
        findsOneWidget,
      );
    }
    expect(find.textContaining('上传者'), findsNothing);
  });

  testWidgets(
    'single-page reader swipes in API order and preserves fullscreen page',
    (tester) async {
      final repository = _Repository()
        ..detailResult = () async => const SheetMusicInfo(
          title: '详情',
          originalKey: 'C',
          bpm: 120,
          pageCount: 99,
          pageUrls: ['https://example.com/z.jpg', 'https://example.com/a.jpg'],
        );
      await cacheSheetImages(tester, [
        'https://example.com/z.jpg',
        'https://example.com/a.jpg',
      ]);
      await _pump(tester, repository, detail: true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('曲谱信息'), findsNothing);
      expect(find.textContaining('速度：120 BPM'), findsOneWidget);
      expect(find.textContaining('总页数：99'), findsOneWidget);
      final normalPager = find.byKey(const ValueKey('sheet-reader-pager'));
      expect(
        tester.widget<PhotoViewGallery>(normalPager).pageController!.page,
        0,
      );
      await tester.drag(normalPager, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PhotoViewGallery>(normalPager).pageController!.page,
        1,
      );
      final gallery = tester.widget<PhotoViewGallery>(normalPager);
      final context = tester.element(normalPager);
      expect(
        (gallery.builder!(context, 0).imageProvider as NetworkImage).url,
        'https://example.com/z.jpg',
      );
      expect(
        (gallery.builder!(context, 1).imageProvider as NetworkImage).url,
        'https://example.com/a.jpg',
      );
      await tester.tap(find.byTooltip('全屏阅读'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final fullscreen = find.byKey(const ValueKey('sheet-fullscreen-pager'));
      expect(
        tester.widget<PhotoViewGallery>(fullscreen).pageController!.page,
        1,
      );
      await tester.drag(fullscreen, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PhotoViewGallery>(fullscreen).pageController!.page,
        0,
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PhotoViewGallery>(normalPager).pageController!.page,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page number opens thumbnails and selects a page', (
    tester,
  ) async {
    final repository = _Repository()
      ..detailResult = () async => const SheetMusicInfo(
        title: '曲谱',
        pageUrls: [
          'https://example.com/1.png',
          'https://example.com/2.png',
          'https://example.com/3.png',
        ],
      );
    await _pump(tester, repository, detail: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 / 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-thumbnail-2')));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
      tester
          .widget<PhotoViewGallery>(
            find.byKey(const ValueKey('sheet-reader-pager')),
          )
          .pageController!
          .page,
      2,
    );
  });

  testWidgets('list-only capability leaves detail actions disabled', (
    tester,
  ) async {
    final repository = _Repository()
      ..listResult = () async => [
        const SheetMusicInfo(id: '001', title: '只读列表'),
      ];
    await _pump(
      tester,
      repository,
      flags: PlatformFeatureSupportFlag.listSheetMusic,
    );
    await tester.pumpAndSettle();
    final row = tester.widget<ListTile>(find.widgetWithText(ListTile, '只读列表'));
    expect(row.onTap, isNull);
    expect(repository.detailCalls, isEmpty);
  });

  for (final detail in [false, true]) {
    testWidgets(
      'direct routes cannot bypass missing capability (detail=$detail)',
      (tester) async {
        final repository = _Repository();
        await _pump(tester, repository, detail: detail, flags: BigInt.zero);
        await tester.pumpAndSettle();
        expect(find.text('当前平台不支持此曲谱操作'), findsOneWidget);
        expect(repository.listCalls, isEmpty);
        expect(repository.detailCalls, isEmpty);
      },
    );
  }

  testWidgets(
    'switching songs does not reuse another song list or late response',
    (tester) async {
      final first = Completer<List<SheetMusicInfo>>();
      final repository = _Repository()..listResult = () => first.future;
      final router = await _pump(tester, repository);
      repository.listResult = () async => [
        const SheetMusicInfo(id: 'new', title: '另一首的曲谱'),
      ];
      router.go('${AppRoutes.songSheetMusic}?platform=qq&song_id=other');
      await tester.pumpAndSettle();
      first.complete([const SheetMusicInfo(id: 'old', title: '旧曲谱')]);
      await tester.pumpAndSettle();
      expect(find.text('另一首的曲谱'), findsOneWidget);
      expect(find.text('旧曲谱'), findsNothing);
      expect(repository.listCalls.map((request) => request.songId), [
        '000123',
        'other',
      ]);
    },
  );

  for (final enabled in [false, true]) {
    testWidgets(
      'song action entry follows list capability (enabled=$enabled)',
      (tester) async {
        final repository = _Repository();
        await _pump(
          tester,
          repository,
          flags: enabled
              ? PlatformFeatureSupportFlag.listSheetMusic
              : BigInt.zero,
          actionHost: true,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('歌曲操作'));
        await tester.pumpAndSettle();
        expect(
          find.text('View Sheet Music'),
          enabled ? findsOneWidget : findsNothing,
        );
        if (enabled) {
          await tester.ensureVisible(find.text('View Sheet Music'));
          await tester.tap(find.text('View Sheet Music'));
          await tester.pumpAndSettle();
          expect(find.text('暂无曲谱'), findsOneWidget);
          expect(repository.listCalls, [(platform: 'qq', songId: '000123')]);
        }
      },
    );
  }
  for (final mode in [AppGlassMode.standard, AppGlassMode.powerSaving]) {
    testWidgets('sheet music keeps only the shared shell glass in $mode', (
      tester,
    ) async {
      final repository = _Repository();
      repository.listResult = () async =>
          throw const SheetMusicNotImplementedException();
      await _pump(tester, repository, glassMode: mode);
      await tester.pumpAndSettle();
      expect(find.byType(GlassScaffold), findsOneWidget);
      expect(find.byType(GlassAppBar), findsNothing);
      expect(find.text('曲谱功能暂未开放'), findsOneWidget);
      expect(find.byType(GlassButton), findsNothing);
      expect(find.byType(GlassIconButton), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '重试'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reader actions and panels stay Material when global glass is enabled',
    (tester) async {
      final repository = _Repository()
        ..detailResult = () async => const SheetMusicInfo(
          title: '曲谱',
          pageUrls: ['https://example.com/1.png', 'https://example.com/2.png'],
        );
      await cacheSheetImages(tester, [
        'https://example.com/1.png',
        'https://example.com/2.png',
      ]);
      await _pump(
        tester,
        repository,
        detail: true,
        glassMode: AppGlassMode.standard,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, '下载全部'), findsOneWidget);
      expect(find.byType(GlassButton), findsNothing);
      expect(find.byType(GlassIconButton), findsNothing);
      expect(find.byType(GlassAppBar), findsNothing);
      expect(find.byTooltip('曲谱信息'), findsNothing);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
      await tester.tap(find.text('1 / 2'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(GlassModalSheet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sheet-thumbnail-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全屏阅读'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final fullscreen = find.byWidgetPredicate(
        (widget) => widget is SheetMusicReader && widget.fullscreen,
      );
      expect(
        find.descendant(of: fullscreen, matching: find.byType(GlassScaffold)),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, '保存当前页'), findsOneWidget);
      expect(find.byType(GlassButton), findsNothing);
      expect(find.byType(GlassIconButton), findsNothing);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('invalid detail route does not send a request', (tester) async {
    final repository = _Repository();
    final router = await _pump(tester, repository);
    router.go('${AppRoutes.sheetMusicDetail}?platform=qq&id=001');
    await tester.pumpAndSettle();
    expect(find.text('曲谱请求缺少必要信息，请返回歌曲后重试'), findsOneWidget);
    expect(repository.detailCalls, isEmpty);
  });
  testWidgets(
    'download progress and failed-page retry leave the reader subtree unchanged',
    (tester) async {
      final repository = _Repository()
        ..detailResult = () async => const SheetMusicInfo(
          title: '曲谱',
          pageUrls: ['https://example.com/1.png', 'https://example.com/2.png'],
        );
      final downloads = _Downloads()..failures.add(1);
      final first = Completer<void>();
      final second = Completer<void>();
      downloads.waiters.addAll({0: first, 1: second});
      await _pump(
        tester,
        repository,
        detail: true,
        downloadRepository: downloads,
      );
      await tester.pumpAndSettle();
      var readerBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (element.widget is SheetMusicReader) readerBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      await tester.tap(find.text('下载全部'));
      await tester.pumpAndSettle();
      expect(find.text('下载中 0/2'), findsOneWidget);
      first.complete();
      await tester.pumpAndSettle();
      expect(find.text('下载中 1/2'), findsOneWidget);
      second.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('已保存 1 页，1 页失败'), findsOneWidget);
      expect(find.text('重试失败项'), findsOneWidget);
      downloads.failures.clear();
      await tester.tap(find.text('重试失败项'));
      await tester.pumpAndSettle();
      expect(downloads.pages, [0, 1, 1]);
      expect(downloads.prepareCalls, 1);
      expect(find.text('已保存 2 页到相册'), findsOneWidget);
      expect(readerBuilds, 0);
    },
  );

  testWidgets(
    'empty resources disable download all and fullscreen save targets the visible page',
    (tester) async {
      final repository = _Repository();
      final downloads = _Downloads();
      final router = await _pump(
        tester,
        repository,
        detail: true,
        downloadRepository: downloads,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '下载全部'))
            .onPressed,
        isNull,
      );
      repository.detailResult = () async => const SheetMusicInfo(
        title: '新曲谱',
        pageUrls: ['https://example.com/1.png', 'https://example.com/2.png'],
      );
      await cacheSheetImages(tester, [
        'https://example.com/1.png',
        'https://example.com/2.png',
      ]);
      router.go(
        '${AppRoutes.sheetMusicDetail}?platform=qq&song_id=000123&id=002',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全屏阅读'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存当前页'));
      await tester.pumpAndSettle();
      expect(downloads.pages, [1]);
      expect(find.text('已保存 1 页到相册'), findsAtLeastNWidgets(1));
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    },
  );
  for (final glassMode in [AppGlassMode.off, AppGlassMode.standard]) {
    for (final bottomInset in [0.0, 24.0]) {
      testWidgets(
        'reading controls clear the mini player with glass=$glassMode inset=$bottomInset',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
          tester.view.padding = FakeViewPadding(bottom: bottomInset);
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final player = _LayoutPlayer();
          const urls = [
            'https://example.com/layout-one.png',
            'https://example.com/layout-two.png',
          ];
          await cacheSheetImages(tester, urls);
          final repository = _Repository()
            ..detailResult = () async => const SheetMusicInfo(
              title: '曲谱',
              songName: '示例歌曲',
              uploader: '示例上传者',
              notationTypes: ['六线谱'],
              instruments: ['吉他'],
              originalKey: 'G',
              bpm: 120,
              pageCount: 2,
              pageUrls: urls,
            );
          await _pump(
            tester,
            repository,
            detail: true,
            glassMode: glassMode,
            layoutPlayer: player,
          );
          await tester.pumpAndSettle();
          final reader = find.byType(SheetMusicReader);
          final readerElement = tester.element(reader);
          final mini = find.byType(MiniPlayerBar);
          final fit = find.byKey(const ValueKey('sheet-fit-toggle'));
          final next = find.byTooltip('下一页');
          final fullscreen = find.byTooltip('全屏阅读');
          final download = find.byKey(const ValueKey('sheet-download-all'));

          void expectClearControls() {
            final miniTop = tester.getTopLeft(mini).dy;
            for (final control in [fit, next, download]) {
              expect(
                tester.getBottomLeft(control).dy,
                lessThanOrEqualTo(miniTop),
              );
              expect(control.hitTestable(), findsOneWidget);
            }
            // The shell's reserved space is consumed once, without a second gap.
            expect(tester.getBottomLeft(reader).dy, closeTo(miniTop, 0.01));
          }

          expectClearControls();
          final normalMiniHeight = tester.getSize(mini).height;
          tester.platformDispatcher.textScaleFactorTestValue = 1.8;
          await tester.pumpAndSettle();
          expect(tester.getSize(mini).height, greaterThan(normalMiniHeight));
          expectClearControls();
          expect(tester.element(reader), same(readerElement));
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(find.text('2 / 2'), findsOneWidget);
          await tester.tap(fit);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: fit, matching: find.text('整页')),
            findsOneWidget,
          );

          await tester.tap(fullscreen);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          final fullscreenReader = find.byWidgetPredicate(
            (widget) => widget is SheetMusicReader && widget.fullscreen,
          );
          final fullscreenFit = find.descendant(
            of: fullscreenReader,
            matching: fit,
          );
          // Fullscreen overlays the player and only retains the system safe area.
          expect(
            tester.getBottomLeft(fullscreenFit).dy,
            greaterThan(tester.getTopLeft(mini).dy),
          );
          expect(
            tester.getBottomLeft(fullscreenFit).dy,
            lessThanOrEqualTo(844 - bottomInset),
          );
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          expectClearControls();
          expect(find.text('2 / 2'), findsOneWidget);
          player.setHasTrack(false);
          await tester.pumpAndSettle();
          if (glassMode == AppGlassMode.off) {
            expect(tester.getSize(mini).height, 0);
          } else {
            expect(mini, findsNothing);
          }
          final bottomWithoutPlayer = tester.getBottomLeft(reader).dy;
          player.setHasTrack(true);
          await tester.pumpAndSettle();
          expectClearControls();
          expect(
            tester.getBottomLeft(reader).dy,
            lessThan(bottomWithoutPlayer),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'compact neutral reading layout keeps metadata in one bar and preserves reading modes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const capture = bool.fromEnvironment('GENERATE_SHEET_MUSIC_PREVIEWS');
      if (capture) {
        await tester.runAsync(() async {
          final latin = FontLoader('SheetPreview')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    'test/assets/fonts/Roboto-Regular.ttf',
                  ).readAsBytes(),
                ),
              ),
            );
          final cjk = FontLoader('SheetPreviewCjk')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    Platform.isMacOS
                        ? '/System/Library/Fonts/STHeiti Light.ttc'
                        : 'test/assets/fonts/DroidSansFallback-PreviewSubset.ttf',
                  ).readAsBytes(),
                ),
              ),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await Future.wait([latin.load(), cjk.load(), icons.load()]);
        });
      }
      const urls = [
        'https://example.com/layout-1.png',
        'https://example.com/layout-2.png',
      ];
      await cacheSheetImages(tester, urls);
      final repository = _Repository()
        ..detailResult = () async => const SheetMusicInfo(
          title: '反方向的钟',
          songName: '反方向的钟',
          uploader: '乐谱分享者',
          bpm: 92,
          notationTypes: ['简谱', '六线谱'],
          arrangementType: '弹唱版',
          originalKey: 'G',
          pageCount: 2,
          pageUrls: urls,
        );
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff2c6d7c));
      await _pump(
        tester,
        repository,
        detail: true,
        capturePreview: true,
        theme: ThemeData(
          colorScheme: scheme,
          scaffoldBackgroundColor: Colors.transparent,
          fontFamily: capture ? 'SheetPreview' : null,
          fontFamilyFallback: capture ? ['SheetPreviewCjk'] : null,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byType(AppBar);
      expect(
        tester.widget<AppBar>(bar).backgroundColor,
        scheme.surfaceContainerLow,
      );
      expect(
        find.descendant(of: bar, matching: find.text('简谱 · 六线谱 · 弹唱版')),
        findsOneWidget,
      );
      final pager = find.byKey(const ValueKey('sheet-reader-pager'));
      final gallery = tester.widget<PhotoViewGallery>(pager);
      expect(
        gallery.builder!(tester.element(pager), 0).initialScale,
        PhotoViewComputedScale.contained,
      );
      final metadata = find.byKey(const ValueKey('sheet-music-metadata'));
      final download = find.byKey(const ValueKey('sheet-download-all'));
      final fit = find.byKey(const ValueKey('sheet-fit-toggle'));
      expect(find.text('反方向的钟'), findsOneWidget);
      expect(find.textContaining('上传者：乐谱分享者'), findsOneWidget);
      expect(find.textContaining('速度：92 BPM'), findsOneWidget);
      expect(tester.getBottomLeft(metadata).dy, tester.getTopLeft(pager).dy);
      expect(
        tester.getTopLeft(download).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(pager).dy),
      );
      expect(tester.getBottomLeft(download).dy, tester.getBottomLeft(fit).dy);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
      if (capture) await _saveSheetLayout(tester, 'fit-page');
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-fit-toggle')));
      await tester.pumpAndSettle();
      final fitted = tester.widget<PhotoViewGallery>(pager);
      expect(fitted.pageController!.page, 1);
      expect(
        fitted.builder!(tester.element(pager), 1).initialScale,
        PhotoViewComputedScale.covered,
      );
      if (capture) await _saveSheetLayout(tester, 'reading');
      await tester.tap(find.byTooltip('全屏阅读'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final full = find.byKey(const ValueKey('sheet-fullscreen-pager'));
      final fullGallery = tester.widget<PhotoViewGallery>(full);
      expect(
        fullGallery.builder!(tester.element(full), 1).initialScale,
        PhotoViewComputedScale.covered,
      );
      await tester.tap(find.byKey(const ValueKey('sheet-fit-toggle')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(tester.widget<PhotoViewGallery>(pager).pageController!.page, 1);
      expect(
        tester
            .widget<PhotoViewGallery>(pager)
            .builder!(tester.element(pager), 1)
            .initialScale,
        PhotoViewComputedScale.contained,
      );
      if (capture) {
        final theme = Theme.of(tester.element(find.byType(SheetMusicReader)));
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          repository,
          detail: true,
          glassMode: AppGlassMode.standard,
          layoutPlayer: _LayoutPlayer(),
          capturePreview: true,
          theme: theme,
        );
        await tester.pumpAndSettle();
        await _saveSheetLayout(tester, 'with-mini-player');
      }
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _saveSheetLayout(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('sheet-layout-preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final output = File('build/sheet_music_previews/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Repository repository, {
  bool detail = false,
  BigInt? flags,
  bool actionHost = false,
  AppGlassMode glassMode = AppGlassMode.off,
  SheetMusicDownloadRepository? downloadRepository,
  ThemeData? theme,
  bool capturePreview = false,
  bool skinAnimation = true,
  _LayoutPlayer? layoutPlayer,
}) async {
  Widget shell(Widget page) =>
      layoutPlayer == null ? page : _LayoutPlayerShell(child: page);
  final router = GoRouter(
    initialLocation: actionHost
        ? '/'
        : '${detail ? AppRoutes.sheetMusicDetail : AppRoutes.songSheetMusic}?platform=qq&song_id=000123&id=001',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _ActionHost()),
      GoRoute(
        path: AppRoutes.songSheetMusic,
        builder: (_, state) => shell(
          SheetMusicListPage(
            platform: state.uri.queryParameters['platform'] ?? '',
            songId: state.uri.queryParameters['song_id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.sheetMusicDetail,
        builder: (_, state) => shell(
          SheetMusicDetailPage(
            platform: state.uri.queryParameters['platform'] ?? '',
            songId: state.uri.queryParameters['song_id'] ?? '',
            id: state.uri.queryParameters['id'] ?? '',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(
          () => _Config(skinAnimation: skinAnimation),
        ),
        if (layoutPlayer != null)
          playerControllerProvider.overrideWith(() => layoutPlayer),
        onlinePlatformsProvider.overrideWith(
          () => _Platforms(
            flags ??
                (PlatformFeatureSupportFlag.listSheetMusic |
                    PlatformFeatureSupportFlag.getSheetMusic),
          ),
        ),
        sheetMusicRepositoryProvider.overrideWithValue(repository),
        if (downloadRepository != null)
          sheetMusicDownloadRepositoryProvider.overrideWithValue(
            downloadRepository,
          ),
      ],
      child: AppGlassScope(
        enabled: glassMode != AppGlassMode.off,
        mode: glassMode,
        child: GlassAdaptiveScope(
          minQuality: GlassQuality.minimal,
          maxQuality: GlassQuality.minimal,
          child: MaterialApp.router(
            routerConfig: router,
            theme: theme,
            builder: capturePreview
                ? (_, child) => RepaintBoundary(
                    key: const ValueKey('sheet-layout-preview'),
                    child: ColoredBox(color: Colors.lightBlue, child: child!),
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

// Mirrors the router's root content shell with the real mini player and its
// inherited bottom clearance, including the native Scaffold fallback.
class _LayoutPlayerShell extends StatelessWidget {
  const _LayoutPlayerShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mini = MiniPlayerBar(
      bottomSafeArea: !AppGlassScope.isEnabled(context),
      onOpenFullPlayer: () {},
    );
    if (AppGlassScope.isEnabled(context)) {
      return AppGlassPlayerScaffold(body: child, miniPlayer: mini);
    }
    return Scaffold(body: child, bottomNavigationBar: mini);
  }
}

class _LayoutPlayer extends PlayerController {
  @override
  PlayerPlaybackState build() => _playback(true);

  void setHasTrack(bool hasTrack) => state = _playback(hasTrack);

  PlayerPlaybackState _playback(bool hasTrack) => PlayerPlaybackState.initial(
    hasTrack ? const [PlayerTrack(id: 'playing', title: '正在播放')] : const [],
  );
}

class _Config extends AppConfigController {
  _Config({required this.skinAnimation});

  final bool skinAnimation;
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: 'zh',
    enableSkinAnimation: skinAnimation,
  );
}

class _Platforms extends OnlinePlatformsController {
  _Platforms(this.flags);
  final BigInt flags;

  @override
  Future<List<OnlinePlatform>> build() async => [
    OnlinePlatform(
      id: 'qq',
      name: 'QQ',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag: flags,
    ),
  ];
}

class _Repository implements SheetMusicRepository {
  final listCalls = <SheetMusicSongRequest>[];
  final detailCalls = <SheetMusicDetailRequest>[];
  Future<List<SheetMusicInfo>> Function() listResult = () async => [];
  Future<SheetMusicInfo> Function() detailResult = () async =>
      const SheetMusicInfo();

  @override
  Future<List<SheetMusicInfo>> fetchList({
    required String platform,
    required String songId,
  }) {
    listCalls.add((platform: platform, songId: songId));
    return listResult();
  }

  @override
  Future<SheetMusicInfo> fetchDetail({
    required String platform,
    required String songId,
    required String id,
  }) {
    detailCalls.add((platform: platform, songId: songId, id: id));
    return detailResult();
  }
}

class _ActionHost extends ConsumerWidget {
  const _ActionHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(onlinePlatformsProvider);
    return Scaffold(
      body: Center(
        child: TextButton(
          child: const Text('歌曲操作'),
          onPressed: () => DetailSongActionHandler(ref: ref).showSongActions(
            context: context,
            forceBottomSheet: true,
            song: const SongInfo(
              id: '000123',
              name: '歌曲',
              subtitle: '',
              duration: 0,
              mvId: '',
              album: null,
              artists: [],
              links: [],
              platform: 'qq',
              cover: '',
            ),
            coverUrl: '',
          ),
        ),
      ),
    );
  }
}

class _Downloads implements SheetMusicDownloadRepository {
  int prepareCalls = 0;
  final pages = <int>[];
  final failures = <int>{};
  final waiters = <int, Completer<void>>{};
  @override
  Future<SheetMusicDownloadDestination?> prepare(String title) async {
    prepareCalls++;
    return _SaveDestination();
  }

  @override
  Future<void> downloadPage({
    required SheetMusicDownloadDestination destination,
    required String url,
    required String title,
    required int pageIndex,
  }) async {
    pages.add(pageIndex);
    await waiters[pageIndex]?.future;
    if (failures.contains(pageIndex)) throw StateError('失败页');
  }
}

class _SaveDestination extends SheetMusicDownloadDestination {
  @override
  String? get directoryPath => null;
  @override
  Future<void> save(Uint8List bytes, String fileName) async {}
}
