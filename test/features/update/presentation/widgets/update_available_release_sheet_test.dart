import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/presentation/widgets/update_available_release_sheet.dart';

void main() {
  testWidgets('fallback layout keeps the original GitHub Release action', (
    tester,
  ) async {
    final openedUrls = <String>[];
    await _pumpSheetHost(tester, openedUrls: openedUrls, downloadUrl: null);

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('前往 GitHub Release'), findsOneWidget);
    expect(find.text('下载更新'), findsNothing);
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
      downloadUrl: downloadUrl,
    );

    expect(find.text('稍后'), findsOneWidget);
    expect(find.text('下载更新'), findsOneWidget);
    expect(find.byTooltip('查看 GitHub Release'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('下载更新'));
    await tester.pumpAndSettle();
    expect(openedUrls, <String>[downloadUrl]);
  });

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
}

Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required List<String> openedUrls,
  required String? downloadUrl,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showUpdateAvailableReleaseSheet(
              context: context,
              config: AppConfigState.initial,
              release: UpdateRelease(
                version: UpdateVersion.parse('1.1.0'),
                versionTag: 'v1.1.0',
                title: 'v1.1.0',
                releaseNotes: '更新内容',
                htmlUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
                publishedAt: DateTime.parse('2026-07-27T12:00:00Z'),
              ),
              downloadUrl: downloadUrl,
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
