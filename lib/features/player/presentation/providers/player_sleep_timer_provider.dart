import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_sleep_timer.dart';
import 'player_audio_provider.dart';

final sleepTimerStateProvider = StreamProvider.autoDispose<SleepTimerState>((
  ref,
) {
  final port = ref.watch(sleepTimerAudioPortProvider);
  if (port == null) {
    return Stream<SleepTimerState>.value(SleepTimerState.inactive);
  }
  final controller = StreamController<SleepTimerState>();
  final subscription = port.sleepTimerStateStream.listen(
    controller.add,
    onError: controller.addError,
  );
  controller.add(port.currentSleepTimerState);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

// Minute precision matches the preset labels; second ticks stay inside providers.
final sleepTimerRemainingMinutesProvider = Provider.autoDispose<int?>((ref) {
  final state = ref.watch(sleepTimerStateProvider).value;
  if (state == null || !state.isActive || state.waitingForTrackEnd) {
    return null;
  }
  final now = ref.watch(sleepTimerNowProvider).value ?? DateTime.now();
  final seconds = state.remainingFrom(now).inSeconds;
  return seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
});

final sleepTimerNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void emitNow() {
    if (!controller.isClosed) {
      controller.add(DateTime.now());
    }
  }

  emitNow();
  timer = Timer.periodic(const Duration(seconds: 1), (_) => emitNow());
  ref.onDispose(() {
    timer?.cancel();
    timer = null;
    unawaited(controller.close());
  });
  return controller.stream;
});
