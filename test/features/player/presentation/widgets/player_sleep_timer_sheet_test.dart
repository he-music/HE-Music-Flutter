import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_button.dart';
import 'package:he_music_flutter/core/audio/audio_sleep_timer.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_sleep_timer_provider.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_sleep_timer_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';

void main() {
  testWidgets('second ticks preserve the list while preset selection updates', (
    tester,
  ) async {
    final now = DateTime.now();
    final port = _TimerPort(_activeTimer(now));
    final times = StreamController<DateTime>.broadcast();
    addTearDown(times.close);
    addTearDown(port.states.close);
    await tester.pumpWidget(_app(port, times.stream));
    await tester.pump();
    await tester.pump();
    times.add(now);
    await tester.pump();
    await tester.pump();

    final listFinder = find.byKey(
      const ValueKey('player-sleep-timer-sheet-list'),
    );
    final initialList = tester.widget<ListView>(listFinder);
    final switchFinder = find.byKey(
      const ValueKey('player-sleep-timer-after-current-switch'),
    );
    final initialSwitch = tester.widget<AppSwitchListTile>(switchFinder);
    final presetFinder = find.ancestor(
      of: find.text('30 min'),
      matching: find.byType(ListTile),
    );
    final otherPresetFinder = find.ancestor(
      of: find.text('10 min'),
      matching: find.byType(ListTile),
    );
    final initialPreset = tester.widget<ListTile>(presetFinder);
    final initialOtherPreset = tester.widget<ListTile>(otherPresetFinder);
    expect(initialPreset.trailing, isA<Icon>());
    for (var second = 1; second <= 5; second++) {
      times.add(now.add(Duration(seconds: second)));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ListView>(listFinder), same(initialList));
      expect(
        tester.widget<AppSwitchListTile>(switchFinder),
        same(initialSwitch),
      );
      expect(tester.widget<ListTile>(presetFinder), same(initialPreset));
    }
    times.add(now.add(const Duration(minutes: 1)));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ListTile>(presetFinder).trailing, isNull);
    expect(
      tester.widget<ListTile>(otherPresetFinder),
      same(initialOtherPreset),
    );
    expect(tester.widget<ListView>(listFinder), same(initialList));
    expect(tester.widget<AppSwitchListTile>(switchFinder), same(initialSwitch));

    port.emit(_activeTimer(now.add(const Duration(minutes: 1))));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ListTile>(presetFinder).trailing, isA<Icon>());
    port.emit(
      SleepTimerState(
        deadline: port.currentSleepTimerState.deadline,
        stopAfterCurrent: true,
        waitingForTrackEnd: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ListTile>(presetFinder).trailing, isNull);
    port.emit(SleepTimerState.inactive);
    await tester.pump();
    await tester.pump();
    final offTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Off'), matching: find.byType(ListTile)),
    );
    expect(offTile.trailing, isA<Icon>());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final style in AppUiStyle.values) {
    testWidgets(
      'custom duration uses current time instead of the last tick with $style',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime.now();
        final port = _TimerPort(_activeTimer(now));
        final times = StreamController<DateTime>.broadcast();
        addTearDown(times.close);
        addTearDown(port.states.close);
        await tester.pumpWidget(_app(port, times.stream, style: style));
        await tester.pump();
        await tester.pump();
        // An old clock emission must not supply the initial custom duration.
        times.add(now.subtract(const Duration(minutes: 5)));
        await tester.pump();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Custom'),
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('player-sleep-timer-sheet-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();
        if (style == AppUiStyle.cupertino) {
          final pickers = tester
              .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
              .toList();
          expect(pickers[0].scrollController!.selectedItem, 0);
          expect(pickers[1].scrollController!.selectedItem, 30);
        } else {
          final fields = tester
              .widgetList<DropdownButtonFormField<int>>(
                find.byType(DropdownButtonFormField<int>),
              )
              .toList();
          expect(fields[0].initialValue, 0);
          expect(fields[1].initialValue, 30);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'custom duration rejects zero and survives style changes before saving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final port = _TimerPort(SleepTimerState.inactive);
      addTearDown(port.states.close);
      final style = ValueNotifier(AppUiStyle.material);
      addTearDown(style.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<AppUiStyle>(
          valueListenable: style,
          builder: (context, current, child) =>
              _app(port, const Stream<DateTime>.empty(), style: current),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Custom'));
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      Future<void> choose(int column, String label) async {
        await tester.tap(find.byType(DropdownButtonFormField<int>).at(column));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(label).hitTestable(),
          -200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).hitTestable().last);
        await tester.pumpAndSettle();
      }

      await choose(1, '0');
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await choose(0, '1');
      await choose(1, '15');
      style.value = AppUiStyle.cupertino;
      await tester.pumpAndSettle();
      final pickers = tester
          .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
          .toList();
      expect(pickers[0].scrollController!.selectedItem, 1);
      expect(pickers[1].scrollController!.selectedItem, 15);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(port.requestedDuration, const Duration(hours: 1, minutes: 15));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preset action preserves the after-current choice', (
    tester,
  ) async {
    final port = _TimerPort(SleepTimerState.inactive);
    addTearDown(port.states.close);
    await tester.pumpWidget(_app(port, const Stream<DateTime>.empty()));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('player-sleep-timer-after-current-switch')),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tester.pump();
    expect(port.requestedDuration, const Duration(minutes: 30));
    expect(port.requestedStopAfterCurrent, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

SleepTimerState _activeTimer(DateTime now) => SleepTimerState(
  deadline: now.add(const Duration(minutes: 30)),
  stopAfterCurrent: false,
  waitingForTrackEnd: false,
);

Widget _app(
  _TimerPort port,
  Stream<DateTime> times, {
  AppUiStyle style = AppUiStyle.material,
}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWith(_Config.new),
    sleepTimerAudioPortProvider.overrideWithValue(port),
    sleepTimerNowProvider.overrideWith((ref) => times),
  ],
  child: AppUiStyleScope(
    style: style,
    child: const MaterialApp(home: Scaffold(body: PlayerSleepTimerSheet())),
  ),
);

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}

class _TimerPort implements SleepTimerAudioPort {
  _TimerPort(this.currentSleepTimerState);

  final states = StreamController<SleepTimerState>.broadcast();
  @override
  SleepTimerState currentSleepTimerState;
  Duration? requestedDuration;
  bool? requestedStopAfterCurrent;

  @override
  Stream<SleepTimerState> get sleepTimerStateStream => states.stream;

  void emit(SleepTimerState state) {
    currentSleepTimerState = state;
    states.add(state);
  }

  @override
  Future<void> cancelSleepTimer() async => emit(SleepTimerState.inactive);

  @override
  Future<void> setSleepTimer(
    Duration duration, {
    required bool stopAfterCurrent,
  }) async {
    requestedDuration = duration;
    requestedStopAfterCurrent = stopAfterCurrent;
  }
}
