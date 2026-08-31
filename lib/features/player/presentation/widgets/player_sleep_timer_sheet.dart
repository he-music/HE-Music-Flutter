import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../core/audio/audio_sleep_timer.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../providers/player_audio_provider.dart';
import '../providers/player_sleep_timer_provider.dart';

const List<int> _sleepTimerPresetMinutes = <int>[10, 30, 60, 90];

String formatSleepTimerSummary(
  AppConfigState config,
  SleepTimerState state,
  DateTime now,
) {
  if (!state.isActive) {
    return AppI18n.t(config, 'player.sleep_timer.off');
  }
  if (state.waitingForTrackEnd) {
    return AppI18n.t(config, 'player.sleep_timer.waiting_current');
  }
  final totalMinutes = _ceilMinutes(state.remainingFrom(now));
  if (totalMinutes <= 0) {
    return AppI18n.t(config, 'player.sleep_timer.soon');
  }
  final base = _formatRemaining(config, totalMinutes);
  if (!state.stopAfterCurrent) {
    return base;
  }
  return AppI18n.format(config, 'player.sleep_timer.summary_after_current', {
    'time': base,
  });
}

class PlayerSleepTimerSheet extends ConsumerStatefulWidget {
  const PlayerSleepTimerSheet({super.key});

  @override
  ConsumerState<PlayerSleepTimerSheet> createState() =>
      _PlayerSleepTimerSheetState();
}

class _PlayerSleepTimerSheetState extends ConsumerState<PlayerSleepTimerSheet> {
  bool _stopAfterCurrent = false;
  bool _syncedInitialState = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final port = ref.watch(sleepTimerAudioPortProvider);
    final sleepTimer =
        ref.watch(sleepTimerStateProvider).value ?? SleepTimerState.inactive;
    var now = DateTime.now();
    if (sleepTimer.isActive && !sleepTimer.waitingForTrackEnd) {
      now = ref.watch(sleepTimerNowProvider).value ?? now;
    }
    if (!_syncedInitialState) {
      _stopAfterCurrent = sleepTimer.stopAfterCurrent;
      _syncedInitialState = true;
    }
    final enabled = port != null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height *
              LayoutTokens.actionSheetMaxHeightFactor,
        ),
        child: ListView(
          key: const ValueKey<String>('player-sleep-timer-sheet-list'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppI18n.t(config, 'player.sleep_timer.title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey<String>(
                'player-sleep-timer-after-current-switch',
              ),
              value: _stopAfterCurrent,
              title: Text(
                AppI18n.t(config, 'player.sleep_timer.after_current'),
              ),
              onChanged: enabled
                  ? (value) => setState(() => _stopAfterCurrent = value)
                  : null,
            ),
            const Divider(height: 8),
            ListTile(
              enabled: enabled,
              leading: const Icon(Icons.not_interested_rounded),
              title: Text(AppI18n.t(config, 'player.sleep_timer.off')),
              trailing: !sleepTimer.isActive
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: enabled ? () => unawaited(_cancelTimer()) : null,
            ),
            for (final minutes in _sleepTimerPresetMinutes)
              ListTile(
                enabled: enabled,
                leading: const Icon(Icons.timer_outlined),
                title: Text(_formatDurationOption(config, minutes)),
                trailing: _isSelectedPreset(sleepTimer, now, minutes)
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: enabled
                    ? () => unawaited(_setTimer(Duration(minutes: minutes)))
                    : null,
              ),
            ListTile(
              enabled: enabled,
              leading: const Icon(Icons.tune_rounded),
              title: Text(AppI18n.t(config, 'player.sleep_timer.custom')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: enabled
                  ? () => unawaited(_openCustomDurationPicker(sleepTimer, now))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelTimer() async {
    final port = ref.read(sleepTimerAudioPortProvider);
    if (port == null) {
      return;
    }
    await port.cancelSleepTimer();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _setTimer(Duration duration) async {
    final port = ref.read(sleepTimerAudioPortProvider);
    if (port == null) {
      return;
    }
    await port.setSleepTimer(duration, stopAfterCurrent: _stopAfterCurrent);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openCustomDurationPicker(
    SleepTimerState sleepTimer,
    DateTime now,
  ) async {
    final currentRemaining =
        sleepTimer.isActive && !sleepTimer.waitingForTrackEnd
        ? sleepTimer.remainingFrom(now)
        : const Duration(minutes: 30);
    final selected = await showPlayerStyledBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SleepTimerCustomDurationSheet(
        config: ref.read(appConfigProvider),
        initialDuration: currentRemaining,
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    await _setTimer(selected);
  }

  bool _isSelectedPreset(
    SleepTimerState sleepTimer,
    DateTime now,
    int minutes,
  ) {
    if (!sleepTimer.isActive || sleepTimer.waitingForTrackEnd) {
      return false;
    }
    return _ceilMinutes(sleepTimer.remainingFrom(now)) == minutes;
  }
}

class _SleepTimerCustomDurationSheet extends StatefulWidget {
  const _SleepTimerCustomDurationSheet({
    required this.config,
    required this.initialDuration,
  });

  final AppConfigState config;
  final Duration initialDuration;

  @override
  State<_SleepTimerCustomDurationSheet> createState() =>
      _SleepTimerCustomDurationSheetState();
}

class _SleepTimerCustomDurationSheetState
    extends State<_SleepTimerCustomDurationSheet> {
  static const _maxHours = 23;
  static const _maxMinutes = 59;
  static const _pickerItemExtent = 40.0;

  late int _hours;
  late int _minutes;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  bool get _hasDuration => _hours > 0 || _minutes > 0;

  @override
  void initState() {
    super.initState();
    final totalMinutes = _ceilMinutes(
      widget.initialDuration,
    ).clamp(1, _maxHours * 60 + _maxMinutes).toInt();
    _hours = totalMinutes ~/ 60;
    _minutes = totalMinutes % 60;
    _hourController = FixedExtentScrollController(initialItem: _hours);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppI18n.t(config, 'player.sleep_timer.custom'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _buildPicker(
                      controller: _hourController,
                      childCount: _maxHours + 1,
                      onSelectedItemChanged: (value) {
                        setState(() => _hours = value);
                      },
                    ),
                  ),
                  _PickerUnitLabel(
                    label: AppI18n.t(config, 'player.sleep_timer.hour_unit'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPicker(
                      controller: _minuteController,
                      childCount: _maxMinutes + 1,
                      onSelectedItemChanged: (value) {
                        setState(() => _minutes = value);
                      },
                    ),
                  ),
                  _PickerUnitLabel(
                    label: AppI18n.t(config, 'player.sleep_timer.minute_unit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppI18n.t(config, 'common.cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _hasDuration
                        ? () {
                            Navigator.of(
                              context,
                            ).pop(Duration(hours: _hours, minutes: _minutes));
                          }
                        : null,
                    child: Text(AppI18n.t(config, 'common.confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int childCount,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: _pickerItemExtent,
      useMagnifier: true,
      magnification: 1.08,
      looping: true,
      onSelectedItemChanged: onSelectedItemChanged,
      children: List<Widget>.generate(
        childCount,
        (index) => Center(child: Text('$index', style: textStyle)),
      ),
    );
  }
}

class _PickerUnitLabel extends StatelessWidget {
  const _PickerUnitLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _formatDurationOption(AppConfigState config, int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) {
    return AppI18n.format(config, 'player.sleep_timer.option_minutes', {
      'count': '$minutes',
    });
  }
  if (minutes <= 0) {
    return AppI18n.format(config, 'player.sleep_timer.option_hours', {
      'count': '$hours',
    });
  }
  return AppI18n.format(config, 'player.sleep_timer.option_hours_minutes', {
    'hours': '$hours',
    'minutes': '$minutes',
  });
}

String _formatRemaining(AppConfigState config, int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) {
    return AppI18n.format(config, 'player.sleep_timer.remaining_minutes', {
      'count': '$minutes',
    });
  }
  if (minutes <= 0) {
    return AppI18n.format(config, 'player.sleep_timer.remaining_hours', {
      'count': '$hours',
    });
  }
  return AppI18n.format(config, 'player.sleep_timer.remaining_hours_minutes', {
    'hours': '$hours',
    'minutes': '$minutes',
  });
}

int _ceilMinutes(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds <= 0) {
    return 0;
  }
  return (seconds + 59) ~/ 60;
}
