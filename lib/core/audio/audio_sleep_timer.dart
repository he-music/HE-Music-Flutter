abstract final class AudioSleepTimerActions {
  static const set = 'he.sleepTimer.set';
  static const cancel = 'he.sleepTimer.cancel';
}

abstract final class AudioSleepTimerEventTypes {
  static const state = 'sleepTimerState';
}

abstract final class AudioSleepTimerFields {
  static const type = 'type';
  static const durationMs = 'durationMs';
  static const deadlineEpochMs = 'deadlineEpochMs';
  static const stopAfterCurrent = 'stopAfterCurrent';
  static const waitingForTrackEnd = 'waitingForTrackEnd';
}

class SleepTimerState {
  const SleepTimerState({
    required this.deadline,
    required this.stopAfterCurrent,
    required this.waitingForTrackEnd,
  });

  static const inactive = SleepTimerState(
    deadline: null,
    stopAfterCurrent: false,
    waitingForTrackEnd: false,
  );

  final DateTime? deadline;
  final bool stopAfterCurrent;
  final bool waitingForTrackEnd;

  bool get isActive => deadline != null;

  Duration remainingFrom(DateTime now) {
    final target = deadline;
    if (target == null || waitingForTrackEnd) {
      return Duration.zero;
    }
    final remaining = target.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toCustomEvent() {
    return <String, dynamic>{
      AudioSleepTimerFields.type: AudioSleepTimerEventTypes.state,
      AudioSleepTimerFields.deadlineEpochMs: deadline?.millisecondsSinceEpoch,
      AudioSleepTimerFields.stopAfterCurrent: stopAfterCurrent,
      AudioSleepTimerFields.waitingForTrackEnd: waitingForTrackEnd,
    };
  }

  static SleepTimerState? fromCustomEvent(dynamic event) {
    if (event is! Map) {
      return null;
    }
    final type = '${event[AudioSleepTimerFields.type] ?? ''}'.trim();
    if (type != AudioSleepTimerEventTypes.state) {
      return null;
    }
    final deadlineMs = event[AudioSleepTimerFields.deadlineEpochMs];
    if (deadlineMs != null && (deadlineMs is! int || deadlineMs <= 0)) {
      return null;
    }
    final stopAfterCurrent = event[AudioSleepTimerFields.stopAfterCurrent];
    final waitingForTrackEnd = event[AudioSleepTimerFields.waitingForTrackEnd];
    if (stopAfterCurrent is! bool || waitingForTrackEnd is! bool) {
      return null;
    }
    if (deadlineMs == null && (stopAfterCurrent || waitingForTrackEnd)) {
      return null;
    }
    return SleepTimerState(
      deadline: deadlineMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deadlineMs),
      stopAfterCurrent: stopAfterCurrent,
      waitingForTrackEnd: waitingForTrackEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SleepTimerState &&
            deadline?.millisecondsSinceEpoch ==
                other.deadline?.millisecondsSinceEpoch &&
            stopAfterCurrent == other.stopAfterCurrent &&
            waitingForTrackEnd == other.waitingForTrackEnd;
  }

  @override
  int get hashCode => Object.hash(
    deadline?.millisecondsSinceEpoch,
    stopAfterCurrent,
    waitingForTrackEnd,
  );
}

abstract interface class SleepTimerAudioPort {
  SleepTimerState get currentSleepTimerState;
  Stream<SleepTimerState> get sleepTimerStateStream;
  Future<void> setSleepTimer(
    Duration duration, {
    required bool stopAfterCurrent,
  });
  Future<void> cancelSleepTimer();
}
