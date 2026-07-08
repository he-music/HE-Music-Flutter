import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/startup/app_auto_update_gate.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/update_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  testWidgets('app auto update gate checks once when enabled', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppAutoUpdateGate(child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 1);
  });

  testWidgets('app auto update gate skips check when disabled', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: false),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppAutoUpdateGate(child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 0);
  });

  testWidgets('app auto update gate shows available release sheet', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_AvailableUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: AppAutoUpdateGate(
            navigatorKey: navigatorKey,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('1.1.0'), findsOneWidget);
    expect(find.text('前往 GitHub Release'), findsOneWidget);
  });

  testWidgets('app auto update gate can show sheet with external navigator', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_AvailableUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: Navigator(
                  key: navigatorKey,
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: SizedBox.shrink()),
                    );
                  },
                ),
              ),
              AppAutoUpdateGate(
                navigatorKey: navigatorKey,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('发现新版本'), findsOneWidget);
  });
}

class _FakeAppConfigDataSource extends AppConfigDataSource {
  const _FakeAppConfigDataSource({required this.autoCheckUpdates});

  final bool autoCheckUpdates;

  @override
  Future<AppConfigState> load() async {
    return AppConfigState.initial.copyWith(autoCheckUpdates: autoCheckUpdates);
  }
}

class _CountingUpdateController extends UpdateController {
  int checkCount = 0;

  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  @override
  Future<void> checkForUpdates() async {
    checkCount += 1;
  }
}

class _AvailableUpdateController extends UpdateController {
  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  @override
  Future<void> checkForUpdates() async {
    state = UpdateState(
      status: UpdateStatus.available,
      release: UpdateRelease(
        version: UpdateVersion.parse('1.1.0'),
        versionTag: 'v1.1.0',
        title: 'v1.1.0',
        releaseNotes: '更新内容',
        htmlUrl: 'https://example.com/release',
        publishedAt: DateTime(2026, 4, 24, 12),
      ),
    );
  }
}
