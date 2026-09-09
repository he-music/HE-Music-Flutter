import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/app_message_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_provider.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/widgets/audio_cache_settings_tile.dart';
import 'package:path/path.dart' as p;
import 'package:toastification/toastification.dart';

import '../../../../core/audio/cache/cache_test_support.dart';
import '../../../../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  for (final failure in ['root', 'metadata', 'data']) {
    testWidgets(
      'real store $failure failure reports clear error without success or deferral',
      (tester) async {
        // Real filesystem Futures and the mutation queue must share the real zone.
        await tester.runAsync(() async {
          AppMessageService.showInfo('clear-test-$failure');
          final directory = await Directory.systemTemp.createTemp(
            'cache-clear-ui-',
          );
          final deletion = CacheFileDeletionFault();
          final store = FileAudioCacheStore(
            capacity: FakeCapacity(),
            applicationCacheDirectory: () async {
              if (failure == 'root') {
                throw const FileSystemException('private root');
              }
              return directory;
            },
            deleteFile: deletion.delete,
          );
          final runtime = AudioCacheRuntime(
            store: store,
            capabilityEnabled: true,
          );
          final container = ProviderContainer(
            overrides: [
              audioCacheRuntimeProvider.overrideWithValue(runtime),
              appConfigDataSourceProvider.overrideWithValue(
                RecordingCacheConfigDataSource(
                  AppConfigState.initial.copyWith(localeCode: 'en'),
                ),
              ),
            ],
          );
          try {
            await runtime.initialize();
            await container
                .read(appConfigProvider.notifier)
                .waitUntilHydrated();
            if (failure != 'root') {
              final lease = await publish(store);
              await lease.dispose();
              deletion.blockedPath = failure == 'data'
                  ? lease.path
                  : p.join(
                      directory.path,
                      'he_music',
                      'audio',
                      'v1',
                      'entries',
                      '${cacheKey().digest}.json',
                    );
            }
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  navigatorKey: rootNavigatorKey,
                  home: Scaffold(
                    body: AudioCacheSettingsTile(
                      item: settingsItems.firstWhere(
                        (item) => item.id == SettingsItemIds.clearAudioCache,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Clear Audio Cache'));
            await tester.pumpAndSettle();
            final clearing = store.snapshots.firstWhere(
              (snapshot) => snapshot.clearEpoch > 0,
            );
            await tester.tap(find.text('Confirm'));
            await clearing.timeout(const Duration(seconds: 5));
            // This operation always queues, including when read health is fused.
            await store.setLimitBytes(runtime.policy.limitBytes);
            await Future<void>.delayed(Duration.zero);
            await tester.pumpAndSettle();
            expect(
              find.text('Unable to clear audio cache. Please retry.'),
              findsOneWidget,
            );
            expect(find.text('Audio cache cleared'), findsNothing);
            expect(
              find.text(
                'Audio cache cleared. Data in use will be removed after playback releases it.',
              ),
              findsNothing,
            );
            expect(find.text('Available cache: 0 MB'), findsOneWidget);
            if (deletion.blockedPath != null) {
              expect(await File(deletion.blockedPath!).exists(), isTrue);
            }
          } finally {
            toastification.dismissAll(delayForAnimation: false);
            toastification.managers.clear();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            container.dispose();
            await store.dispose();
            await directory.delete(recursive: true);
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
