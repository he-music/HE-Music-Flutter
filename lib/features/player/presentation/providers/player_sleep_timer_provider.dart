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
