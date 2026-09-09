import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/audio_cache_bootstrap.dart';
import 'package:he_music_flutter/app/audio_cache_simulator_guard.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';

import '../../integration_test/support/cache_ui_fixture.dart';
import '../core/audio/cache/phase4_cache_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native identity requires simulator and exact independent bundle', () {
    expect(
      audioCacheSimulatorIdentityAllowed({
        'simulator': true,
        'bundle': audioCacheSimulatorBundle,
      }),
      isTrue,
    );
    for (final value in <Object?>[
      null,
      true,
      {},
      {'simulator': 'true', 'bundle': audioCacheSimulatorBundle},
      {'simulator': false, 'bundle': audioCacheSimulatorBundle},
      for (final suffix in [
        '',
        '.debug',
        '.cacheui',
        '.cacheharness',
        '.cachesim.other',
      ])
        {'simulator': true, 'bundle': 'com.hemusic.music.flutter$suffix'},
    ]) {
      expect(audioCacheSimulatorIdentityAllowed(value), isFalse);
    }
  });

  test('simulator bundle cannot pass the existing Release UI guard', () {
    for (final release in [true, false]) {
      expect(
        cacheUiIsolationAllowed(
          release: release,
          supportedPlatform: true,
          packageName: audioCacheSimulatorBundle,
        ),
        isFalse,
      );
    }
    expect(
      cacheUiIsolationAllowed(
        release: true,
        supportedPlatform: true,
        packageName: cacheUiBundle,
      ),
      isTrue,
    );
    expect(
      cacheUiIsolationAllowed(
        release: false,
        supportedPlatform: true,
        packageName: cacheUiBundle,
      ),
      isFalse,
    );
  });

  test(
    'default production iOS bootstrap still creates no cache runtime',
    () async {
      final source = RecordingCacheConfigDataSource(AppConfigState.initial);
      final audio = await prepareAudioBootstrap(
        platform: TargetPlatform.iOS,
        dataSource: source,
        createStore: () => throw StateError('must_not_create'),
      );
      expect(audio.runtime, isNull);
      expect(
        playbackAudioCacheCapability.supports(TargetPlatform.iOS),
        isFalse,
      );
      expect(source.loads, 1);
    },
  );

  test(
    'test opt-in refuses host before config load or store construction',
    () async {
      final source = RecordingCacheConfigDataSource(AppConfigState.initial);
      await expectLater(
        prepareAudioBootstrap(
          debugIosSimulatorCache: true,
          platform: TargetPlatform.iOS,
          dataSource: source,
          createStore: () => throw StateError('must_not_create'),
        ),
        throwsStateError,
      );
      expect(source.loads, 0);
      expect(source.saved, isEmpty);
    },
  );
}
