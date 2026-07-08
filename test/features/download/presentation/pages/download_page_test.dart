import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_state.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/download/presentation/controllers/download_controller.dart';
import 'package:he_music_flutter/features/download/presentation/pages/download_page.dart';
import 'package:he_music_flutter/features/download/presentation/providers/download_providers.dart';

void main() {
  testWidgets('download page shows empty state without overview summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          downloadControllerProvider.overrideWith(_EmptyDownloadController.new),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DownloadPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('下载'), findsOneWidget);
    expect(find.text('暂无下载任务。'), findsOneWidget);
  });

  testWidgets('download page renders newest tasks first as compact rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          downloadControllerProvider.overrideWith(
            _FilledDownloadController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: <Locale>[Locale('zh'), Locale('en')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DownloadPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('下载'), findsOneWidget);
    expect(find.text('夜曲 - 周杰伦.mp3'), findsOneWidget);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('MP3'), findsWidgets);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('daoxiang.mp3'), findsOneWidget);
    expect(find.text('-'), findsNothing);
    expect(find.text('4.0 MB / 10.0 MB'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.getTopLeft(find.text('反方向的钟.mp3')).dy,
      lessThan(tester.getTopLeft(find.text('夜曲 - 周杰伦.mp3')).dy),
    );
  });

  testWidgets('more menu shows pause for downloading task', (tester) async {
    await _pumpDownloadPage(tester, size: const Size(390, 844));
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('移除任务'), findsOneWidget);
    expect(find.text('移除任务和文件'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('more menu shows resume for paused task', (tester) async {
    await _pumpDownloadPage(tester, size: const Size(390, 844));
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('继续'), findsOneWidget);
    expect(find.text('移除任务'), findsOneWidget);
    expect(find.text('移除任务和文件'), findsOneWidget);
    expect(find.text('暂停'), findsNothing);
  });

  testWidgets('more menu shows retry for failed task', (tester) async {
    await _pumpDownloadPage(tester, size: const Size(390, 844));
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('重试'), findsOneWidget);
    expect(find.text('移除任务'), findsOneWidget);
    expect(find.text('移除任务和文件'), findsOneWidget);
  });

  testWidgets('more menu shows completed actions for finished task', (
    tester,
  ) async {
    await _pumpDownloadPage(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('重新下载'), findsOneWidget);
    expect(find.text('打开文件'), findsOneWidget);
    expect(find.text('导出文件'), findsOneWidget);
    expect(find.text('移除任务'), findsOneWidget);
    expect(find.text('移除任务和文件'), findsOneWidget);
  });

  testWidgets('more menu shows open file for completed task on ios', (
    tester,
  ) async {
    await _pumpDownloadPage(
      tester,
      size: const Size(390, 844),
      platform: TargetPlatform.iOS,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('重新下载'), findsOneWidget);
    expect(find.text('打开文件'), findsOneWidget);
    expect(find.text('导出文件'), findsOneWidget);
    expect(find.text('打开所在位置'), findsNothing);
  });

  testWidgets('download page more menu uses previous mobile list tile style', (
    tester,
  ) async {
    await _pumpDownloadPage(tester, size: const Size(390, 844));
    await tester.pump();

    await tester.tap(find.byKey(const Key('download_more_button_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ListTile), findsWidgets);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets(
    'desktop layout shows anchored context menu instead of bottom sheet',
    (tester) async {
      await _pumpDownloadPage(
        tester,
        size: const Size(1280, 900),
        platform: TargetPlatform.macOS,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('download_more_button_4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsWidgets);
      expect(find.text('重新下载'), findsOneWidget);
      expect(find.text('打开所在位置'), findsOneWidget);
      expect(find.text('移除任务'), findsOneWidget);
      expect(find.text('移除任务和文件'), findsOneWidget);
    },
  );
}

Future<void> _pumpDownloadPage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  TargetPlatform? platform,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        downloadControllerProvider.overrideWith(_FilledDownloadController.new),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(platform: platform),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const DownloadPage(),
        ),
      ),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _EmptyDownloadController extends DownloadController {
  @override
  DownloadState build() {
    return DownloadState.initial;
  }
}

class _FilledDownloadController extends DownloadController {
  @override
  DownloadState build() {
    return DownloadState(
      tasks: <DownloadTask>[
        DownloadTask(
          id: '1',
          title: '夜曲',
          url: 'https://example.com/1.mp3',
          artist: '周杰伦',
          album: '十一月的萧邦',
          status: DownloadTaskStatus.downloading,
          progress: 0.42,
          downloadedBytes: 4194304,
          totalBytes: 10485760,
          quality: DownloadTaskQuality(
            label: 'hq',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.pending,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9, 12, 0, 0),
          filePath: '/tmp/夜曲 - 周杰伦.mp3',
        ),
        DownloadTask(
          id: '2',
          title: '稻香',
          url: 'https://example.com/2.mp3',
          status: DownloadTaskStatus.paused,
          progress: 0.18,
          downloadedBytes: 1887437,
          totalBytes: 10485760,
          quality: DownloadTaskQuality(
            label: 'sq',
            bitrate: 192,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.pending,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9, 12, 1, 0),
          filePath: '/tmp/稻香.mp3',
        ),
        DownloadTask(
          id: '3',
          title: '晴天',
          url: 'https://example.com/3.mp3',
          status: DownloadTaskStatus.failed,
          progress: 0.7,
          downloadedBytes: 7340032,
          totalBytes: 10485760,
          quality: DownloadTaskQuality(
            label: 'hq',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.failed,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9, 12, 2, 0),
          errorMessage: '网络错误',
          filePath: '/tmp/晴天.mp3',
        ),
        DownloadTask(
          id: '4',
          title: '稻香（完成）',
          url: 'https://example.com/4.mp3',
          status: DownloadTaskStatus.completed,
          progress: 1,
          downloadedBytes: 10485760,
          totalBytes: 10485760,
          quality: DownloadTaskQuality(
            label: 'lossless',
            bitrate: 999,
            fileExtension: 'flac',
          ),
          tagWriteStatus: DownloadTagWriteStatus.success,
          lyricFormat: DownloadLyricFormat.timed,
          createdAt: DateTime(2026, 4, 9, 12, 3, 0),
          resolvedFileExtension: 'mp3',
          filePath: '/tmp/daoxiang.mp3',
        ),
        DownloadTask(
          id: '5',
          title: '反方向的钟',
          url: 'https://example.com/5.mp3',
          status: DownloadTaskStatus.preparing,
          progress: 0,
          downloadedBytes: 0,
          quality: DownloadTaskQuality(
            label: 'hq',
            bitrate: 320,
            fileExtension: 'mp3',
          ),
          tagWriteStatus: DownloadTagWriteStatus.pending,
          lyricFormat: DownloadLyricFormat.none,
          createdAt: DateTime(2026, 4, 9, 12, 4, 0),
          filePath: '/tmp/反方向的钟.mp3',
        ),
      ],
      maxConcurrent: 3,
      isProcessing: true,
    );
  }
}
