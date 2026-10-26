import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_handler_player_adapter.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_history_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/audio/native_audio_test_support.dart';

const _source = PlayerQueueSource(
  routePath: '/playlist',
  queryParameters: {'id': 'one'},
  title: 'One',
);
const _queue = [
  PlayerTrack(id: 'A', title: 'A', platform: 'local', path: '/tmp/A.mp3'),
  PlayerTrack(id: 'B', title: 'B', platform: 'local', path: '/tmp/B.mp3'),
  PlayerTrack(id: 'C', title: 'C', platform: 'local', path: '/tmp/C.mp3'),
];
List<IdPlatformInfo> get _reversedSongs => [
  for (final track in _queue.reversed)
    IdPlatformInfo(id: track.id, platform: 'local'),
];

Future<void> _waitForState(
  ProviderContainer container,
  bool Function(PlayerPlaybackState) matches,
) {
  final ready = Completer<void>();
  final subscription = container.listen(playerControllerProvider, (_, next) {
    if (!ready.isCompleted && matches(next)) ready.complete();
  }, fireImmediately: true);
  return ready.future
      .timeout(const Duration(seconds: 3))
      .whenComplete(subscription.close);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
    ({
      ProviderContainer container,
      _HeldHandlerAdapter audio,
      HeAudioHandler handler,
      NativeAudioTestPlatform native,
    })
  >
  harness() async {
    final original = JustAudioPlatform.instance;
    final native = NativeAudioTestPlatform();
    JustAudioPlatform.instance = native;
    const channel = MethodChannel('com.ryanheise.audio_session');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() {
      JustAudioPlatform.instance = original;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final player = AudioPlayer(handleAudioSessionActivation: false);
    final handler = HeAudioHandler(player: player);
    final audio = _HeldHandlerAdapter(handler);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_Config.new),
        audioPlayerPortProvider.overrideWithValue(audio),
        playerHistoryDataSourceProvider.overrideWithValue(_MemoryHistory()),
      ],
    );
    addTearDown(handler.disposeHandler);
    addTearDown(() async {
      // Index callbacks persist progress/history after publishing the visible state.
      await Future<void>.delayed(Duration.zero);
      container.dispose();
    });
    await container
        .read(playerControllerProvider.notifier)
        .replaceQueue(_queue, queueSource: _source, autoplay: false);
    return (
      container: container,
      audio: audio,
      handler: handler,
      native: native,
    );
  }

  for (final next in [true, false]) {
    test(
      'real ${next ? 'next' : 'previous'} pending and debounced load finish before source reorder',
      () async {
        final h = await harness();
        final controller = h.container.read(playerControllerProvider.notifier);
        final target = next ? 'B' : 'C';
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        Future<void> holdLoad(LoadRequest _) async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        }

        h.native.beforeLoad = holdLoad;
        h.native.current.beforeLoad = holdLoad;
        final pending = _waitForState(
          h.container,
          (s) => s.requestedTrack?.id == target,
        );
        await (next ? controller.playNext() : controller.playPrevious());
        await pending;
        var sorted = false;
        final sorting = controller
            .reorderQueueForSource(_reversedSongs, source: _source)
            .then((value) {
              sorted = true;
              return value;
            });
        await Future<void>.delayed(Duration.zero);
        expect(sorted, isFalse);
        expect(
          h.container.read(playerControllerProvider).requestedTrack?.id,
          target,
        );
        expect(
          h.container.read(playerControllerProvider).queue.map((t) => t.id),
          ['A', 'B', 'C'],
        );
        // Reaching native load proves that the real 150ms manual-skip debounce fired.
        await entered.future.timeout(const Duration(seconds: 3));
        expect(sorted, isFalse);
        expect(
          h.container.read(playerControllerProvider).requestedTrack?.id,
          target,
        );
        release.complete();
        expect(await sorting.timeout(const Duration(seconds: 3)), isTrue);
        await _waitForState(
          h.container,
          (s) =>
              s.currentTrack?.id == target &&
              s.requestedTrackIndex == null &&
              s.isPlaying,
        );
        final state = h.container.read(playerControllerProvider);
        expect(state.queue.map((t) => t.id), ['C', 'B', 'A']);
        expect(h.handler.queue.value.map((t) => t.id), ['C', 'B', 'A']);
        expect(h.handler.mediaItem.value!.id, target);
        expect(state.currentIndex, next ? 1 : 0);
        final stored = await const PlayerQueueDataSource().readQueue();
        expect(stored!.queue.map((t) => t.id), ['C', 'B', 'A']);
        expect(stored.currentIndex, state.currentIndex);
      },
    );

    test(
      'real late ${next ? 'next' : 'previous'} waits for source reorder submission',
      () async {
        final h = await harness();
        final controller = h.container.read(playerControllerProvider.notifier);
        final gate = h.audio.holdNextQueue();
        final sorting = controller.reorderQueueForSource(
          _reversedSongs,
          source: _source,
        );
        await gate.entered.future;
        var dispatched = false;
        final skipping =
            (next ? controller.playNext() : controller.playPrevious()).then((
              _,
            ) {
              dispatched = true;
            });
        await Future<void>.delayed(Duration.zero);
        expect(dispatched, isFalse);
        expect(
          h.container.read(playerControllerProvider).requestedTrackIndex,
          isNull,
        );
        expect(h.handler.queue.value.map((t) => t.id), ['A', 'B', 'C']);
        gate.release.complete();
        expect(await sorting, isTrue);
        await skipping;
        // Current A is now last: next wraps to C, previous goes to B.
        final target = next ? 'C' : 'B';
        await _waitForState(
          h.container,
          (s) =>
              s.currentTrack?.id == target &&
              s.requestedTrackIndex == null &&
              s.isPlaying,
        );
        final state = h.container.read(playerControllerProvider);
        expect(state.queue.map((t) => t.id), ['C', 'B', 'A']);
        expect(h.handler.queue.value.map((t) => t.id), ['C', 'B', 'A']);
        expect(h.handler.mediaItem.value!.id, target);
        expect(state.currentIndex, next ? 0 : 1);
      },
    );
  }

  test(
    'real failed manual skip clears pending and releases source reorder',
    () async {
      final h = await harness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      Future<void> holdLoad(LoadRequest _) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }

      h.native.beforeLoad = holdLoad;
      h.native.current.beforeLoad = holdLoad;
      final pending = _waitForState(
        h.container,
        (s) => s.requestedTrack?.id == 'B',
      );
      await controller.playNext();
      await pending;
      final sorting = controller.reorderQueueForSource(
        _reversedSongs,
        source: _source,
      );
      await entered.future.timeout(const Duration(seconds: 3));
      h.native.beforeLoad = null;
      h.native.current.beforeLoad = null;
      release.completeError(StateError('manual source load failed'));
      expect(await sorting.timeout(const Duration(seconds: 3)), isTrue);
      final state = h.container.read(playerControllerProvider);
      expect(state.requestedTrackIndex, isNull);
      expect(state.currentTrack!.id, 'A');
      expect(state.queue.map((t) => t.id), ['C', 'B', 'A']);
      expect(h.handler.queue.value.map((t) => t.id), ['C', 'B', 'A']);
    },
  );

  test(
    'real manual skip superseded by playAt releases source reorder after commit',
    () async {
      final h = await harness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final pending = _waitForState(
        h.container,
        (s) => s.requestedTrack?.id == 'B',
      );
      await controller.playNext();
      await pending;
      final sorting = controller.reorderQueueForSource(
        _reversedSongs,
        source: _source,
      );
      await controller.playAt(0);
      expect(await sorting.timeout(const Duration(seconds: 3)), isTrue);
      final state = h.container.read(playerControllerProvider);
      expect(state.currentTrack!.id, 'A');
      expect(state.requestedTrackIndex, isNull);
      expect(state.queue.map((t) => t.id), ['C', 'B', 'A']);
      expect(h.handler.queue.value.map((t) => t.id), ['C', 'B', 'A']);
    },
  );

  test(
    'real repeated manual next keeps newest pending target until commit',
    () async {
      final h = await harness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final firstPending = _waitForState(
        h.container,
        (s) => s.requestedTrack?.id == 'B',
      );
      await controller.playNext();
      await firstPending;
      final sorting = controller.reorderQueueForSource(
        _reversedSongs,
        source: _source,
      );
      final lastPending = _waitForState(
        h.container,
        (s) => s.requestedTrack?.id == 'C',
      );
      await controller.playNext();
      await lastPending;
      expect(
        h.container.read(playerControllerProvider).queue.map((t) => t.id),
        ['A', 'B', 'C'],
      );
      expect(await sorting.timeout(const Duration(seconds: 3)), isTrue);
      final state = h.container.read(playerControllerProvider);
      expect(state.currentTrack!.id, 'C');
      expect(state.currentIndex, 0);
      expect(state.requestedTrackIndex, isNull);
      expect(state.queue.map((t) => t.id), ['C', 'B', 'A']);
      expect(h.handler.queue.value.map((t) => t.id), ['C', 'B', 'A']);
      expect(h.handler.mediaItem.value!.id, 'C');
    },
  );
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(localeCode: 'zh-CN');
}

class _MemoryHistory extends PlayerHistoryDataSource {
  @override
  Future<int> getCount() async => 0;

  @override
  Future<int> appendTrack(
    PlayerTrack track, {
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerPlayMode? previousPlayModeBeforeRadio,
  }) async => 1;
}

class _QueueGate {
  final entered = Completer<void>();
  final release = Completer<void>();
}

class _HeldHandlerAdapter extends AudioHandlerPlayerAdapter {
  _HeldHandlerAdapter(super.handler);
  _QueueGate? _nextGate;
  _QueueGate holdNextQueue() => _nextGate = _QueueGate();

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    final gate = _nextGate;
    _nextGate = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
    }
    await super.setQueue(
      tracks,
      initialIndex: initialIndex,
      forceReloadCurrent: forceReloadCurrent,
      isRadioMode: isRadioMode,
      currentRadioId: currentRadioId,
      currentRadioPlatform: currentRadioPlatform,
      currentRadioPageIndex: currentRadioPageIndex,
    );
  }
}
