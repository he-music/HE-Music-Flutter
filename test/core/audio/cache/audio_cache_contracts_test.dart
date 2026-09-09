import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';

import 'cache_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'key normalizes identity without resolver, account, or delimiter aliases',
    () {
      final key = cacheKey();
      expect(cacheKey(platform: ' QQ ', track: ' song ', format: ' MP3 '), key);
      expect(key.digest, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect({
        key.digest,
        cacheKey(schema: 2).digest,
        cacheKey(platform: 'wy').digest,
        cacheKey(track: 'other').digest,
        cacheKey(quality: 128).digest,
        cacheKey(format: 'flac').digest,
      }, hasLength(6));
      expect(
        cacheKey(platform: 'a|b', track: 'c').digest,
        isNot(cacheKey(platform: 'a', track: 'b|c').digest),
      );
      expect(jsonDecode(key.canonicalIdentity), [
        'audio-cache:v1',
        'qq',
        'song',
        320,
        'mp3',
      ]);
      expect(
        key.toJson().keys,
        unorderedEquals([
          'platform',
          'track_id',
          'quality',
          'requested_format',
        ]),
      );
    },
  );

  test(
    'missing and invalid identity never acquires default playback values',
    () {
      for (final field in [
        'platform',
        'track',
        'quality',
        'format',
        'schema',
      ]) {
        expect(
          AudioCacheKey.tryCreate(
            schema: field == 'schema' ? 0 : 1,
            platform: field == 'platform' ? null : 'qq',
            trackId: field == 'track' ? '' : 'a',
            quality: field == 'quality' ? 0 : 320,
            requestedFormat: field == 'format' ? ' ' : 'mp3',
          ),
          isNull,
        );
      }
    },
  );

  test('metadata decoder rejects path traversal and inconsistent identity', () {
    final key = cacheKey();
    final value = AudioCacheMetadata(
      key: key,
      fileName: '${key.digest}.session.mp3',
      resolvedFormat: 'mp3',
      actualBytes: 10,
      completedAtMs: 0,
    ).toJson();
    expect(
      AudioCacheMetadata.tryParse(jsonDecode(jsonEncode(value)))?.key,
      key,
    );
    for (final mutation in <Map<String, Object?>>[
      {'file_name': '../outside.mp3'},
      {'file_name': '${cacheKey(track: 'other').digest}.session.mp3'},
      {'actual_bytes': 0},
      {'actual_bytes': 1.5},
      {'resolved_format': 'flac'},
      {'completed_at_ms': -1},
      {'schema': 2},
      {
        'key': {'platform': 'qq'},
      },
    ]) {
      expect(AudioCacheMetadata.tryParse({...value, ...mutation}), isNull);
    }
    expect(jsonEncode(value), isNot(contains('url')));
  });

  test(
    'policy freezes independent write switches and binary capacity targets',
    () {
      const policy = AudioCachePolicy();
      expect(policy.enabled, isTrue);
      expect(policy.allowCellular, isFalse);
      expect(policy.limitBytes, 2147483648);
      expect(AudioCachePolicy.limits, [
        524288000,
        1073741824,
        2147483648,
        5368709120,
      ]);
      expect(AudioCachePolicy.physicalFloorBytes, 536870912);
      expect(policy.allowsWrite(NetworkConnectionType.wifi), isTrue);
      expect(policy.allowsWrite(NetworkConnectionType.cellular), isFalse);
      expect(policy.allowsWrite(NetworkConnectionType.offline), isFalse);
      expect(
        const AudioCachePolicy(
          allowCellular: true,
        ).allowsWrite(NetworkConnectionType.cellular),
        isTrue,
      );
      expect(
        const AudioCachePolicy(
          enabled: false,
          allowCellular: true,
        ).allowsWrite(NetworkConnectionType.wifi),
        isFalse,
      );
    },
  );

  test('capability is independent per Release gate and iOS stays disabled', () {
    const none = AudioCacheCapability();
    const android = AudioCacheCapability(androidReleaseVerified: true);
    const mac = AudioCacheCapability(macosReleaseVerified: true);
    const both = AudioCacheCapability(
      androidReleaseVerified: true,
      macosReleaseVerified: true,
    );
    for (final platform in TargetPlatform.values) {
      expect(none.supports(platform), isFalse);
      expect(android.supports(platform), platform == TargetPlatform.android);
      expect(mac.supports(platform), platform == TargetPlatform.macOS);
      expect(both.supports(platform, isWeb: true), isFalse);
    }
    expect(both.supports(TargetPlatform.iOS), isFalse);
  });

  test(
    'channel forwards fresh cache path and accepts only nonnegative integers',
    () async {
      const port = MethodChannelAudioCacheDiskCapacityPort();
      final calls = <MethodCall>[];
      Object? response = 100;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(port.channel, (call) async {
            calls.add(call);
            return response;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(port.channel, null),
      );
      expect(await port.availableBytes('/private/cache/v1'), 100);
      response = 0;
      expect(await port.availableBytes('/private/cache/v1'), 0);
      for (final invalid in <Object?>[null, -1, '100', 1.5, true]) {
        response = invalid;
        expect(await port.availableBytes('/private/cache/v1'), isNull);
      }
      expect(calls, hasLength(7));
      expect(
        calls.every(
          (call) =>
              call.method == 'availableBytes' &&
              (call.arguments as Map)['cachePath'] == '/private/cache/v1',
        ),
        isTrue,
      );
    },
  );

  test(
    'missing native channel remains an error for transient admission bypass',
    () async {
      const port = MethodChannelAudioCacheDiskCapacityPort(
        channel: MethodChannel('missing/cache'),
      );
      await expectLater(
        port.availableBytes('/cache'),
        throwsA(isA<MissingPluginException>()),
      );
    },
  );
}
