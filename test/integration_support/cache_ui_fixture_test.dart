import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';

import '../../integration_test/support/cache_ui_fixture.dart';

void main() {
  test('UI isolation requires Release, supported OS and exact new bundle', () {
    expect(
      cacheUiIsolationAllowed(
        release: true,
        supportedPlatform: true,
        packageName: cacheUiBundle,
      ),
      isTrue,
    );
    for (final bundle in [
      'com.hemusic.music.flutter',
      'com.hemusic.music.flutter.debug',
      'com.hemusic.music.flutter.cacheharness',
      '$cacheUiBundle.extra',
      '',
    ]) {
      expect(
        cacheUiIsolationAllowed(
          release: true,
          supportedPlatform: true,
          packageName: bundle,
        ),
        isFalse,
      );
    }
    expect(
      cacheUiIsolationAllowed(
        release: false,
        supportedPlatform: true,
        packageName: cacheUiBundle,
      ),
      isFalse,
    );
    expect(
      cacheUiIsolationAllowed(
        release: true,
        supportedPlatform: false,
        packageName: cacheUiBundle,
      ),
      isFalse,
    );
  });

  test('fixture origin accepts only credential-free private IP HTTP roots', () {
    for (final host in [
      '127.0.0.1',
      '10.0.0.1',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.1',
      '[::1]',
    ]) {
      expect(cacheUiOrigin('http://$host:8765/').port, 8765);
    }
    for (final value in [
      'https://127.0.0.1',
      'http://user:secret@127.0.0.1',
      'http://127.0.0.1/?token=secret',
      'http://127.0.0.1/#secret',
      'http://127.0.0.1/audio',
      'http://example.com',
      'http://8.8.8.8',
      'http://172.15.0.1',
      'http://172.32.0.1',
      'http://192.169.0.1',
      'http://10.example.com',
      'http://[fd00::1]',
    ]) {
      expect(() => cacheUiOrigin(value), throwsA(isA<StateError>()));
    }
  });

  test('injected classification is explicit and emits changes', () async {
    final network = CacheUiNetwork(offline: true);
    expect(await network.current(), NetworkConnectionType.offline);
    final next = network.changes.first;
    network.setOffline(false);
    expect(await next, NetworkConnectionType.wifi);
    expect(network.lastKnown, NetworkConnectionType.wifi);
  });

  test(
    'offline resolver attempts persist before refusal and survive restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cache-ui-counter-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final network = CacheUiNetwork(offline: true);
      final fixture = CacheUiFixture(root, network);
      await fixture.initialize();
      expect(fixture.base, isNull);
      await expectLater(
        fixture.resolve(
          songId: 'ui1_a',
          platform: 'fixture',
          quality: 320,
          format: 'wav',
        ),
        throwsStateError,
      );
      expect(fixture.resolverCalls, 1);
      expect(
        jsonDecode(
          await File('${root.path}/resolver-count.json').readAsString(),
        ),
        1,
      );
      final restarted = CacheUiFixture(root, network);
      await restarted.initialize();
      expect(restarted.resolverCalls, 1);
      expect(restarted.base, isNull);
      await expectLater(
        restarted.resolve(
          songId: 'ui1_a',
          platform: 'fixture',
          quality: 128,
          format: 'wav',
        ),
        throwsStateError,
      );
      expect(
        jsonDecode(
          await File('${root.path}/resolver-count.json').readAsString(),
        ),
        2,
      );
    },
  );

  test(
    'invalid persisted resolver count fails closed without origin start',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cache-ui-invalid-counter-',
      );
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/resolver-count.json').writeAsString('-1');
      final fixture = CacheUiFixture(root, CacheUiNetwork(offline: true));
      await expectLater(fixture.initialize(), throwsStateError);
      expect(fixture.base, isNull);
    },
  );
}
