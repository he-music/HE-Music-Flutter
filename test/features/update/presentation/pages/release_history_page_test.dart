import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_current_app_info.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_check_result.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_page.dart';
import 'package:he_music_flutter/features/update/domain/repositories/update_repository.dart';
import 'package:he_music_flutter/features/update/presentation/pages/release_history_page.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  testWidgets('glass navigation stays above the expandable version list', (
    tester,
  ) async {
    await _pump(tester, _History(), glass: true);
    expect(find.byType(GlassScaffold), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('v1.5.0')).dy,
      greaterThan(tester.getBottomLeft(find.byType(GlassAppBar)).dy),
    );
    await tester.tap(find.text('v1.4.0'));
    await tester.pumpAndSettle();
    expect(find.text('Notes 1.4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only one release expands and the open release can be collapsed',
    (tester) async {
      final repository = _History();
      await _pump(tester, repository, latest: '1.5.0');
      expect(find.text('Notes 1.5.0'), findsOneWidget);
      expect(find.text('Notes 1.4.0'), findsNothing);
      expect(find.text('v1.1.0'), findsNothing);
      expect(find.text('当前'), findsOneWidget);
      await tester.tap(find.text('v1.4.0'));
      await tester.pumpAndSettle();
      expect(find.text('Notes 1.4.0'), findsOneWidget);
      expect(find.text('Notes 1.5.0'), findsNothing);
      await tester.tap(find.text('v1.4.0'));
      await tester.pumpAndSettle();
      expect(find.text('Notes 1.4.0'), findsNothing);
      expect(find.text('Notes 1.5.0'), findsNothing);
      await tester.ensureVisible(find.text('查看更早版本'));
      await tester.tap(find.text('查看更早版本'));
      await tester.pumpAndSettle();
      expect(find.text('v1.1.0'), findsOneWidget);
      expect(find.text('Notes 1.5.0'), findsNothing);
      expect(repository.calls, [1]);
    },
  );

  testWidgets('failed next page preserves logs and can be retried', (
    tester,
  ) async {
    final repository = _History(failSecondPage: true);
    await _pump(tester, repository);
    await tester.ensureVisible(find.text('加载更多版本'));
    await tester.tap(find.text('加载更多版本'));
    await tester.pumpAndSettle();
    expect(find.text('Notes 1.5.0'), findsOneWidget);
    expect(find.text('版本记录加载失败'), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(repository.calls, [1, 2, 2]);
  });

  testWidgets('small screen and large text keep full width expandable rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pump(tester, _History(), scale: 2);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('v1.4.0'));
    await tester.tap(find.text('v1.4.0'));
    await tester.pumpAndSettle();
    expect(find.text('Notes 1.4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching from a long release keeps the tapped heading visible',
    (tester) async {
      await _pump(tester, _History(longNotes: true));
      final heading = find.text('v1.4.0');
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      await tester.tap(heading);
      await tester.pumpAndSettle();
      final y = tester.getTopLeft(heading).dy;
      expect(
        y,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      expect(
        y,
        lessThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
      expect(find.text('Notes 1.4.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('filtered empty pages do not hide later matching versions', (
    tester,
  ) async {
    final repository = _History(emptyFirst: true);
    await _pump(tester, repository, latest: '1.5.0');
    expect(find.text('Notes 1.3.0'), findsOneWidget);
    expect(repository.calls, [1, 2]);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _History repository, {
  String? latest,
  double scale = 1,
  bool glass = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateRepositoryProvider.overrideWithValue(repository),
        currentAppInfoProvider.overrideWith(
          (ref) async => const UpdateCurrentAppInfo(
            appName: 'HE Music',
            version: '1.2.0',
            buildNumber: '1',
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AppGlassScope(
            enabled: glass,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              initialQuality: GlassQuality.minimal,
              child: child!,
            ),
          ),
        ),
        home: ReleaseHistoryPage(latestVersion: latest),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _History implements UpdateRepository {
  _History({
    this.failSecondPage = false,
    this.emptyFirst = false,
    this.longNotes = false,
  });
  final bool longNotes;
  bool failSecondPage;
  final bool emptyFirst;
  final calls = <int>[];

  @override
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  }) async {
    throw UnimplementedError('History does not trigger an update check.');
  }

  @override
  Future<UpdateReleasePage> fetchReleaseHistory(int page) async {
    calls.add(page);
    if (page == 2 && failSecondPage) {
      failSecondPage = false;
      throw StateError('offline');
    }
    return UpdateReleasePage(
      releases:
          (page == 1
                  ? (emptyFirst
                        ? <String>[]
                        : ['1.5.0', '1.4.0', '1.2.0', '1.1.0'])
                  : ['1.3.0', '1.0.0'])
              .map(
                (version) => UpdateRelease(
                  version: UpdateVersion.parse(version),
                  versionTag: 'v$version',
                  title: version,
                  releaseNotes: longNotes && version == '1.5.0'
                      ? List.generate(
                          60,
                          (index) => '- Update item $index',
                        ).join('\n')
                      : 'Notes $version',
                  htmlUrl: 'https://example.com/$version',
                  publishedAt: DateTime(2026, 7, 18),
                ),
              )
              .toList(),
      hasMore: page == 1,
    );
  }
}
