import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native cache-volume capacity Release gate', (_) async {
    expect(
      Platform.isAndroid || Platform.isMacOS,
      isTrue,
      reason: 'iOS remains disabled and has no capacity channel',
    );
    final cache = await getApplicationCacheDirectory();
    final fixture = await Directory(
      '${cache.path}/audio-capacity-gate',
    ).create(recursive: true);
    const port = MethodChannelAudioCacheDiskCapacityPort();
    final store = FileAudioCacheStore(
      capacity: port,
      applicationCacheDirectory: () async => fixture,
    );
    try {
      final first = await port
          .availableBytes(fixture.path)
          .timeout(const Duration(seconds: 1));
      expect(first, isNotNull);
      expect(first, greaterThanOrEqualTo(0));
      final file = File('${fixture.path}/probe.bin');
      await file.writeAsBytes(List.filled(4 * 1024 * 1024, 1), flush: true);
      final second = await port
          .availableBytes(fixture.path)
          .timeout(const Duration(seconds: 1));
      expect(second, isNotNull);
      expect(second, greaterThanOrEqualTo(0));
      // External apps and opportunistic reclaim can move capacity either way.
      await file.delete();
      final third = await port
          .availableBytes(fixture.path)
          .timeout(const Duration(seconds: 1));
      expect(third, isNotNull);
      await expectLater(
        port.availableBytes('/'),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        port.channel.invokeMethod<void>('unknown'),
        throwsA(isA<MissingPluginException>()),
      );
      await store.initialize();
      expect(store.readHealth, AudioCacheReadHealth.ready);
      final key = AudioCacheKey.tryCreate(
        platform: 'fixture',
        trackId: 'capacity',
        quality: 320,
        requestedFormat: 'mp3',
      )!;
      final lease = await store.admitAndBeginWrite(
        key: key,
        resolvedFormat: 'mp3',
        expectedBytes: 1,
        limitBytes: AudioCachePolicy.defaultLimitBytes,
      );
      if (third! > AudioCachePolicy.physicalFloorBytes + 4 * 1024 * 1024) {
        expect(lease, isNotNull);
      }
      await lease?.dispose();
      debugPrint(
        'AUDIO_CACHE_CAPACITY result=go platform=${Platform.operatingSystem} queries=3 storeReady=true',
      );
    } finally {
      await store.dispose();
      await fixture.delete(recursive: true);
    }
    if (const bool.fromEnvironment('AUDIO_CACHE_CAPACITY_EXIT_AFTER_RUN')) {
      exit(0);
    }
  });
}
