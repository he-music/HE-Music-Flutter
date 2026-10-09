import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics_overlay/data/overlay_message.dart';
import 'package:he_music_flutter/features/lyrics_overlay/presentation/overlay_lyrics_window.dart';

const _mainChannel = MethodChannel('x-slayer/overlay_channel');
const _flagChannel = MethodChannel('x-slayer/overlay');

Future<void> _send(MethodCall call) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'x-slayer/overlay_messenger',
        const JSONMethodCodec().encodeMethodCall(call),
        (_) {},
      );
}

void main() {
  testWidgets('lock waits for window readiness and applies the latest value', (
    tester,
  ) async {
    var active = false;
    final flags = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _mainChannel,
      (call) async => active,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _flagChannel,
      (call) async {
        flags.add((call.arguments as Map)['flag'] as String);
        return true;
      },
    );
    await tester.pumpWidget(const MaterialApp(home: OverlayLyricsWindow()));
    await tester.pump();
    await _send(
      MethodCall('message', const OverlayLockStateMessage(true).toJson()),
    );
    await tester.pump();
    expect(flags, isEmpty);
    await _send(
      MethodCall('message', const OverlayLockStateMessage(false).toJson()),
    );
    await _send(
      MethodCall('message', const OverlayLockStateMessage(true).toJson()),
    );
    await tester.pump();
    expect(flags, isEmpty);
    active = true;
    await _send(const MethodCall('isShowingOverlay', true));
    await tester.pump();
    expect(flags, ['clickThrough']);
    active = false;
    await _send(const MethodCall('isShowingOverlay', false));
    await _send(
      MethodCall('message', const OverlayLockStateMessage(false).toJson()),
    );
    await tester.pump();
    expect(flags, ['clickThrough']);
    active = true;
    await _send(const MethodCall('isShowingOverlay', true));
    await tester.pump();
    expect(flags, ['clickThrough', 'defaultFlag']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late active query cannot overwrite a newer displayed event', (
    tester,
  ) async {
    final query = Completer<bool>();
    final flags = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _mainChannel,
      (call) => query.future,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _flagChannel,
      (call) async {
        flags.add((call.arguments as Map)['flag'] as String);
        return true;
      },
    );
    await tester.pumpWidget(const MaterialApp(home: OverlayLyricsWindow()));
    await _send(
      MethodCall('message', const OverlayLockStateMessage(true).toJson()),
    );
    await _send(const MethodCall('isShowingOverlay', true));
    await tester.pump();
    expect(flags, ['clickThrough']);
    query.complete(false);
    await tester.pump();
    await _send(
      MethodCall('message', const OverlayLockStateMessage(false).toJson()),
    );
    await tester.pump();
    expect(flags, ['clickThrough', 'defaultFlag']);
  });

  for (final error in <Exception>[
    MissingPluginException('overlay was detached'),
    PlatformException(code: 'WINDOW_CLOSED'),
  ]) {
    testWidgets('flag failure $error does not escape the overlay listener', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _mainChannel,
        (call) async => false,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _flagChannel,
        (call) async => throw error,
      );
      await tester.pumpWidget(const MaterialApp(home: OverlayLyricsWindow()));
      await tester.pump();
      await _send(const MethodCall('isShowingOverlay', true));
      await _send(
        MethodCall('message', const OverlayLockStateMessage(true).toJson()),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
