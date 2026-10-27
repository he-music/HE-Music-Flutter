import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/playback/controllers/video_picture_in_picture_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hemusic/video_pip');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'unsupported platforms never query native PiP or offer the action',
    () async {
      final pip = VideoPictureInPictureController(platform: TargetPlatform.iOS);
      addTearDown(pip.dispose);
      await pip.initialize();
      expect(pip.available, isFalse);
      expect(await pip.enter(aspectRatio: 16 / 9, playing: true), isFalse);
      expect(calls, isEmpty);
    },
  );

  test('missing Android handler degrades to unavailable', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    final pip = VideoPictureInPictureController(
      platform: TargetPlatform.android,
    );
    addTearDown(pip.dispose);
    await pip.initialize();
    expect(pip.available, isFalse);
  });

  test(
    'native callbacks control playback and dismissal without losing session state',
    () async {
      final pip = VideoPictureInPictureController(
        platform: TargetPlatform.android,
      );
      addTearDown(pip.dispose);
      int toggles = 0;
      int stops = 0;
      pip.onTogglePlayback = () {
        toggles++;
      };
      pip.onStopped = () {
        stops++;
      };
      await pip.initialize();
      expect(await pip.enter(aspectRatio: 9 / 16, playing: false), isTrue);
      expect(pip.active, isTrue);
      await _native(channel, const MethodCall('togglePlayback'));
      await _native(channel, const MethodCall('stopped'));
      await _native(channel, const MethodCall('modeChanged', false));
      expect(toggles, 1);
      expect(stops, 1);
      expect(pip.active, isFalse);
      expect(pip.entering, isFalse);
    },
  );

  test('PiP updates playback controls only while active', () async {
    final pip = VideoPictureInPictureController(
      platform: TargetPlatform.android,
    );
    addTearDown(pip.dispose);
    await pip.initialize();
    await pip.updatePlayback(playing: false, aspectRatio: 16 / 9);
    expect(calls.map((call) => call.method), ['isSupported']);
    await pip.enter(aspectRatio: 16 / 9, playing: true);
    await pip.updatePlayback(playing: false, aspectRatio: 16 / 9);
    expect(calls.last.method, 'update');
    expect(calls.last.arguments['playing'], isFalse);
  });

  test(
    'duplicate entry is ignored and entering resets after native failure',
    () async {
      final gate = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        return gate.future;
      });
      final pip = VideoPictureInPictureController(
        platform: TargetPlatform.android,
      );
      addTearDown(pip.dispose);
      await pip.initialize();
      final first = pip.enter(aspectRatio: 16 / 9, playing: true);
      expect(pip.entering, isTrue);
      expect(await pip.enter(aspectRatio: 16 / 9, playing: true), isFalse);
      gate.completeError(PlatformException(code: 'denied'));
      expect(await first, isFalse);
      expect(pip.entering, isFalse);
      expect(pip.active, isFalse);
    },
  );
}

Future<void> _native(MethodChannel channel, MethodCall call) async {
  final complete = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(call),
        (_) => complete.complete(),
      );
  await complete.future;
}
