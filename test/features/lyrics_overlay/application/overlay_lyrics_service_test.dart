import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/features/lyrics_overlay/application/overlay_lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('x-slayer/overlay_channel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'open waits for the displayed window rather than the start request',
    () async {
      var active = false;
      var completed = false;
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isOverlayActive':
            return active;
          case 'checkPermission':
            return true;
          case 'showOverlay':
            started.complete();
            return null;
        }
        return null;
      });
      final service = OverlayLyricsService(isSupportedPlatform: true);
      final opening = service.open().then((_) => completed = true);
      await started.future;
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      active = true;
      await _emitWindowStatus(true);
      await opening;
      expect(completed, isTrue);
    },
  );

  test('close queued during startup leaves no active window', () async {
    var active = false;
    final calls = <String>[];
    final started = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isOverlayActive':
          return active;
        case 'checkPermission':
          return true;
        case 'showOverlay':
          calls.add('open');
          started.complete();
          return null;
        case 'closeOverlay':
          calls.add('close');
          active = false;
          return true;
      }
      return null;
    });
    final service = OverlayLyricsService(isSupportedPlatform: true);
    final opening = service.open();
    await started.future;
    final closing = service.close();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['open']);
    active = true;
    await _emitWindowStatus(true);
    await Future.wait([opening, closing]);
    expect(calls, ['open', 'close']);
    expect(active, isFalse);
  });

  test(
    'close skips the native request when the window is already closed',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return false;
      });
      await OverlayLyricsService(isSupportedPlatform: true).close();
      expect(calls, ['isOverlayActive']);
    },
  );

  test('failed startup does not block a later open', () async {
    var attempts = 0;
    var active = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isOverlayActive':
          return active;
        case 'checkPermission':
          return true;
        case 'showOverlay':
          if (++attempts == 1) throw PlatformException(code: 'START_FAILED');
          active = true;
          return null;
      }
      return null;
    });
    final service = OverlayLyricsService(isSupportedPlatform: true);
    await expectLater(service.open(), throwsA(isA<PlatformException>()));
    await service.open();
    expect(attempts, 2);
    expect(active, isTrue);
  });

  testWidgets(
    'close accepts a missing reply only after confirming the window closed',
    (tester) async {
      var active = true;
      final nativeReply = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isOverlayActive') return active;
        if (call.method == 'closeOverlay') {
          active = false;
          return nativeReply.future;
        }
        return null;
      });
      final closing = OverlayLyricsService(isSupportedPlatform: true).close();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await closing;
      nativeReply.complete(false);
      await tester.pump();
      expect(active, isFalse);
    },
  );

  test('isActive returns false when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.isActive(), completion(isFalse));
  });

  test('close is a no-op when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.close(), completes);
  });

  test('auto highlight uses the color extracted from current artwork', () {
    final config = AppConfigState.initial.copyWith(
      lyricHighlightMode: AppLyricHighlightMode.auto,
    );

    final color = resolveOverlayLyricHighlightColor(
      config,
      autoHighlightColorValue: Colors.green.toARGB32(),
    );

    expect(color, Colors.green.toARGB32());
  });

  test('auto highlight falls back to sky when artwork has no color', () {
    final config = AppConfigState.initial.copyWith(
      lyricHighlightMode: AppLyricHighlightMode.auto,
    );

    final color = resolveOverlayLyricHighlightColor(config);

    expect(color, AppLyricHighlightColor.sky.color.toARGB32());
  });
}

Future<void> _emitWindowStatus(bool showing) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'x-slayer/overlay_messenger',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('isShowingOverlay', showing),
        ),
        (_) {},
      );
}
