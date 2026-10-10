import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/domain/services/update_download_resolver.dart';
import 'package:he_music_flutter/features/update/presentation/widgets/update_available_release_sheet.dart';

void main() {
  testWidgets(
    'history opens above the sheet and returns to its download action',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => showUpdateAvailableReleaseSheet(
                  context: context,
                  config: AppConfigState.initial,
                  release: UpdateRelease(
                    version: UpdateVersion.parse('1.5.0'),
                    versionTag: 'v1.5.0',
                    title: 'v1.5.0',
                    releaseNotes: 'notes',
                    htmlUrl: 'https://example.com/release',
                    publishedAt: DateTime(2026),
                  ),
                  downloadTarget: const UpdateDownloadTarget(
                    officialUrl: 'https://example.com/app.apk',
                    acceleratedUrl: 'https://proxy.example.com/app.apk',
                  ),
                  onOpenUrl: (_) async {},
                ),
                child: const Text('show'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.releaseHistory,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: Text('history ${state.uri.queryParameters['latest']}'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看其他版本的更新'));
      await tester.pumpAndSettle();
      expect(find.text('history 1.5.0'), findsOneWidget);
      await tester.tap(find.text('history 1.5.0'));
      await tester.pumpAndSettle();
      expect(find.text('加速下载'), findsOneWidget);
      expect(find.text('普通下载'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback layout keeps the original GitHub Release action', (
    tester,
  ) async {
    final openedUrls = <String>[];
    await _pumpSheetHost(tester, openedUrls: openedUrls, downloadUrl: null);

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('前往 GitHub Release'), findsOneWidget);
    expect(find.text('普通下载'), findsNothing);
    expect(find.text('加速下载'), findsNothing);
    expect(find.byTooltip('查看 GitHub Release'), findsNothing);

    await tester.tap(find.text('前往 GitHub Release'));
    await tester.pumpAndSettle();
    expect(openedUrls, <String>[
      'https://github.com/owner/repo/releases/tag/v1.1.0',
    ]);
  });

  testWidgets('download layout exposes separate official and APK actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetPhysicalSize);
    final openedUrls = <String>[];
    const downloadUrl =
        'https://proxy.example.com/https://github.com/owner/repo/releases/download/v1.1.0/app.apk';
    await _pumpSheetHost(
      tester,
      openedUrls: openedUrls,
      downloadUrl:
          'https://github.com/owner/repo/releases/download/v1.1.0/app.apk',
      acceleratedUrl: downloadUrl,
    );

    expect(find.text('稍后'), findsOneWidget);
    expect(find.text('加速下载'), findsOneWidget);
    expect(find.text('普通下载'), findsOneWidget);
    expect(find.byTooltip('查看 GitHub Release'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('加速下载'));
    await tester.pumpAndSettle();
    expect(openedUrls, <String>[downloadUrl]);
  });

  testWidgets('regular download always opens the original package URL', (
    tester,
  ) async {
    final openedUrls = <String>[];
    const officialUrl =
        'https://github.com/owner/repo/releases/download/v1.1.0/app.apk';
    await _pumpSheetHost(
      tester,
      openedUrls: openedUrls,
      downloadUrl: officialUrl,
      acceleratedUrl: 'https://proxy.example.com/$officialUrl',
    );
    await tester.tap(find.text('普通下载'));
    await tester.pumpAndSettle();
    expect(openedUrls, [officialUrl]);
  });

  testWidgets(
    'unavailable acceleration leaves regular download and later actions',
    (tester) async {
      final openedUrls = <String>[];
      const officialUrl =
          'https://github.com/owner/repo/releases/download/v1.1.0/app.apk';
      await _pumpSheetHost(
        tester,
        openedUrls: openedUrls,
        downloadUrl: officialUrl,
      );
      expect(find.text('加速下载'), findsNothing);
      expect(find.text('稍后'), findsOneWidget);
      await tester.tap(find.text('普通下载'));
      await tester.pumpAndSettle();
      expect(openedUrls, [officialUrl]);
    },
  );

  testWidgets('later dismisses both download choices without opening a URL', (
    tester,
  ) async {
    final openedUrls = <String>[];
    await _pumpSheetHost(
      tester,
      openedUrls: openedUrls,
      downloadUrl: 'https://example.com/app.apk',
      acceleratedUrl: 'https://proxy.example.com/app.apk',
    );
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(openedUrls, isEmpty);
    expect(find.text('加速下载'), findsNothing);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final locale in ['zh', 'en']) {
      testWidgets(
        '$platform $locale download actions fit a narrow screen with large text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final openedUrls = <String>[];
          final officialUrl = platform == TargetPlatform.iOS
              ? 'https://example.com/app-ios.ipa'
              : 'https://example.com/app-android-arm64-v8a.apk';
          await _pumpSheetHost(
            tester,
            openedUrls: openedUrls,
            downloadUrl: officialUrl,
            acceleratedUrl: 'https://proxy.example.com/$officialUrl',
            config: AppConfigState.initial.copyWith(localeCode: locale),
            platform: platform,
            textScale: 2,
          );
          final accelerated = find.text(
            locale == 'en' ? 'Accelerated Download' : '加速下载',
          );
          final regular = find.text(
            locale == 'en' ? 'Regular Download' : '普通下载',
          );
          final later = find.text(locale == 'en' ? 'Later' : '稍后');
          expect(accelerated, findsOneWidget);
          expect(regular, findsOneWidget);
          expect(later, findsOneWidget);
          expect(
            tester.getRect(accelerated).bottom,
            lessThan(tester.getRect(regular).top),
          );
          expect(
            tester.getRect(later).center.dx,
            lessThan(tester.getRect(regular).center.dx),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(regular);
          await tester.pumpAndSettle();
          expect(regular.hitTestable(), findsOneWidget);
          expect(later.hitTestable(), findsOneWidget);
          await tester.ensureVisible(accelerated);
          await tester.pumpAndSettle();
          await tester.tap(accelerated);
          await tester.pumpAndSettle();
          expect(openedUrls, ['https://proxy.example.com/$officialUrl']);
        },
      );
    }
  }

  testWidgets('official icon always opens the unproxied release page', (
    tester,
  ) async {
    final openedUrls = <String>[];
    await _pumpSheetHost(
      tester,
      openedUrls: openedUrls,
      downloadUrl: 'https://proxy.example.com/official-url',
    );

    await tester.tap(find.byTooltip('查看 GitHub Release'));
    await tester.pumpAndSettle();

    expect(openedUrls, <String>[
      'https://github.com/owner/repo/releases/tag/v1.1.0',
    ]);
  });

  testWidgets('release notes render GitHub Markdown without loading images', (
    tester,
  ) async {
    await _pumpSheetHost(
      tester,
      openedUrls: <String>[],
      downloadUrl: null,
      releaseNotes: '''
### 新增

- `home` 优化布局 (abc1234)

![版本预览](https://example.com/release.png)
''',
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
    expect(find.textContaining('###'), findsNothing);
    expect(find.text('版本预览'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('release notes open only absolute web links', (tester) async {
    final openedUrls = <String>[];
    await _pumpSheetHost(
      tester,
      openedUrls: openedUrls,
      downloadUrl: null,
      releaseNotes: '''
[Full Changelog](https://github.com/owner/repo/compare/v1.0.0...v1.1.0)

[本地文件](file:///tmp/release.txt)
''',
    );

    await tester.tap(find.text('Full Changelog', findRichText: true));
    await tester.pump();
    expect(openedUrls, <String>[
      'https://github.com/owner/repo/compare/v1.0.0...v1.1.0',
    ]);

    await tester.tap(find.text('本地文件', findRichText: true));
    await tester.pump();
    expect(openedUrls, hasLength(1));
  });
}

Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required List<String> openedUrls,
  required String? downloadUrl,
  String releaseNotes = '更新内容',
  String? acceleratedUrl,
  AppConfigState? config,
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showUpdateAvailableReleaseSheet(
              context: context,
              config: config ?? AppConfigState.initial,
              release: UpdateRelease(
                version: UpdateVersion.parse('1.1.0'),
                versionTag: 'v1.1.0',
                title: 'v1.1.0',
                releaseNotes: releaseNotes,
                htmlUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
                publishedAt: DateTime.parse('2026-07-27T12:00:00Z'),
              ),
              downloadTarget: downloadUrl == null
                  ? null
                  : UpdateDownloadTarget(
                      officialUrl: downloadUrl,
                      acceleratedUrl: acceleratedUrl,
                    ),
              onOpenUrl: (url) async {
                openedUrls.add(url);
              },
            ),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}
