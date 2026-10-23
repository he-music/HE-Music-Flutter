import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_offset_control.dart';

void main() {
  const song = LyricRequest(trackId: 'song', platform: 'qq');
  late _Store store;
  setUp(() => store = _Store());
  tearDown(() => store.events.close());

  Widget app({bool manual = false, bool enabled = true, double scale = 1}) =>
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_Config.new),
          lyricStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: LyricOffsetControl(
                request: song,
                manual: manual,
                enabled: enabled,
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'advance, delay and reset adjust by 100 ms and update the value',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('未调整 · 0.0 秒'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('提前 0.1 秒'));
        await tester.pumpAndSettle();
      }
      expect(find.text('已提前 0.2 秒'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('延后 0.1 秒'));
        await tester.pumpAndSettle();
      }
      expect(find.text('已延后 0.1 秒'), findsOneWidget);
      expect(await store.readOffset(song, manual: false), -100);
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(find.text('未调整 · 0.0 秒'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('lyric-offset-reset')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('source changes keep manual and default adjustments separate', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('提前 0.1 秒'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(manual: true));
    await tester.pumpAndSettle();
    expect(find.text('未调整 · 0.0 秒'), findsOneWidget);
    await tester.tap(find.text('延后 0.1 秒'));
    await tester.pumpAndSettle();
    expect(await store.readOffset(song, manual: true), -100);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('已提前 0.1 秒'), findsOneWidget);
  });

  for (final manual in [false, true]) {
    testWidgets(
      'external reset all refreshes the displayed offset: manual=$manual',
      (tester) async {
        await store.adjustOffset(song, 100, manual: manual);
        await tester.pumpWidget(app(manual: manual));
        await tester.pumpAndSettle();
        expect(find.text('已提前 0.1 秒'), findsOneWidget);
        await store.resetAllOffsets();
        await tester.pumpAndSettle();
        expect(find.text('未调整 · 0.0 秒'), findsOneWidget);
      },
    );
  }

  testWidgets('unavailable lyrics disable adjustments', (tester) async {
    await tester.pumpWidget(app(enabled: false));
    await tester.pumpAndSettle();
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(store.values, isEmpty);
  });

  testWidgets('large text wraps at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(scale: 2));
    await tester.pumpAndSettle();
    expect(find.text('提前 0.1 秒'), findsOneWidget);
    expect(find.text('延后 0.1 秒'), findsOneWidget);
    final advance = tester.getCenter(
      find.byKey(const ValueKey('lyric-offset-advance')),
    );
    final reset = tester.getCenter(
      find.byKey(const ValueKey('lyric-offset-reset')),
    );
    final delay = tester.getCenter(
      find.byKey(const ValueKey('lyric-offset-delay')),
    );
    expect(advance.dx, lessThan(reset.dx));
    expect(reset.dx, lessThan(delay.dx));
    expect(reset.dx, closeTo((advance.dx + delay.dx) / 2, 0.01));
    expect(tester.takeException(), isNull);
  });
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

class _Store extends LyricStore {
  _Store()
    : super(
        manualDirectory: () async => Directory('/unused/manual'),
        automaticDirectory: () async => Directory('/unused/automatic'),
      );
  final values = <(String, bool), int>{};
  final events = StreamController<LyricOffsetChange>.broadcast(sync: true);

  @override
  Stream<LyricOffsetChange> get offsetChanges => events.stream;

  @override
  Future<int> readOffset(LyricRequest target, {required bool manual}) async =>
      values[(lyricStorageKey(target), manual)] ?? 0;

  @override
  Future<int> adjustOffset(
    LyricRequest target,
    int deltaMilliseconds, {
    required bool manual,
  }) async {
    final key = lyricStorageKey(target);
    final value = (values[(key, manual)] ?? 0) + deltaMilliseconds;
    values[(key, manual)] = value;
    events.add(LyricOffsetChange(key, manual, value));
    return value;
  }

  @override
  Future<int> resetOffset(LyricRequest target, {required bool manual}) async {
    final key = lyricStorageKey(target);
    values[(key, manual)] = 0;
    events.add(LyricOffsetChange(key, manual, 0));
    return 0;
  }

  @override
  Future<void> resetAllOffsets() async {
    values.clear();
    events.add(const LyricOffsetChange.resetAll());
  }
}
