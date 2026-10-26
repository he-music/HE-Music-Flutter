import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_handler_player_adapter.dart';
import 'package:he_music_flutter/core/audio/audio_player_port.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
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
const _otherSource = PlayerQueueSource(
  routePath: '/playlist',
  queryParameters: {'id': 'two'},
  title: 'Two',
);
const _queue = [
  PlayerTrack(id: 'A', title: 'A', platform: 'local', path: '/tmp/A.mp3'),
  PlayerTrack(id: 'B', title: 'B', platform: 'local', path: '/tmp/B.mp3'),
];
List<IdPlatformInfo> _songs(Iterable<PlayerTrack> queue) => [
  for (final track in queue) IdPlatformInfo(id: track.id, platform: 'local'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<({ProviderContainer container, _HeldQueuePlayer audio})>
  harness() async {
    final audio = _HeldQueuePlayer();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_Config.new),
        audioPlayerPortProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(playerControllerProvider.notifier)
        .replaceQueue(_queue, queueSource: _source, autoplay: false);
    return (container: container, audio: audio);
  }

  Future<
    ({
      ProviderContainer container,
      _HeldHandlerAdapter audio,
      AudioPlayer player,
      HeAudioHandler handler,
      NativeAudioTestPlatform native,
    })
  >
  nativeHarness() async {
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
      ],
    );
    addTearDown(handler.disposeHandler);
    addTearDown(container.dispose);
    await container
        .read(playerControllerProvider.notifier)
        .replaceQueue(_queue, queueSource: _source, autoplay: false);
    return (
      container: container,
      audio: audio,
      player: player,
      handler: handler,
      native: native,
    );
  }

  for (final fails in [false, true]) {
    test(
      'source reorder waits for pending switch ${fails ? 'rollback' : 'commit'}',
      () async {
        final h = await harness();
        final controller = h.container.read(playerControllerProvider.notifier);
        final gate = h.audio.holdNextQueue();
        final switching = controller.playAt(1);
        final checkedSwitch = fails
            ? expectLater(switching, throwsStateError)
            : switching;
        await gate.entered.future;
        expect(
          h.container.read(playerControllerProvider).requestedTrack!.id,
          'B',
        );
        var sorted = false;
        final sorting = controller
            .reorderQueueForSource(_songs(_queue.reversed), source: _source)
            .then((value) {
              sorted = true;
              return value;
            });
        await Future<void>.delayed(Duration.zero);
        final pending = h.container.read(playerControllerProvider);
        expect(sorted, isFalse);
        expect(pending.queue.map((t) => t.id), ['A', 'B']);
        expect(pending.requestedTrack!.id, 'B');
        expect(h.audio.queueCalls, 2);
        if (fails) {
          gate.release.completeError(StateError('held switch failed'));
        } else {
          gate.release.complete();
        }
        await checkedSwitch;
        expect(await sorting, isTrue);
        final state = h.container.read(playerControllerProvider);
        expect(state.queue.map((t) => t.id), ['B', 'A']);
        expect(state.currentTrack!.id, fails ? 'A' : 'B');
        expect(state.currentIndex, fails ? 1 : 0);
        expect(state.requestedTrackIndex, isNull);
        expect(h.audio.queue.map((t) => t.id), ['B', 'A']);
        expect(h.audio.currentIndex, state.currentIndex);
        final stored = await const PlayerQueueDataSource().readQueue();
        expect(stored!.queue.map((t) => t.id), ['B', 'A']);
        expect(stored.currentIndex, state.currentIndex);
      },
    );
  }

  for (final changesSource in [false, true]) {
    test(
      'source reorder revalidates ${changesSource ? 'source' : 'membership'} after pending replacement',
      () async {
        final h = await harness();
        final controller = h.container.read(playerControllerProvider.notifier);
        final gate = h.audio.holdNextQueue();
        final replacement = controller.replaceQueue(
          changesSource ? _queue : [_queue[1]],
          queueSource: changesSource ? _otherSource : _source,
          startIndex: changesSource ? 1 : 0,
        );
        await gate.entered.future;
        final sorting = controller.reorderQueueForSource(
          _songs(_queue.reversed),
          source: _source,
        );
        await Future<void>.delayed(Duration.zero);
        gate.release.complete();
        await replacement;
        expect(await sorting, isFalse);
        final state = h.container.read(playerControllerProvider);
        expect(state.currentTrack!.id, 'B');
        expect(state.queue.length, changesSource ? 2 : 1);
        expect(h.audio.queueCalls, 2);
        expect(h.audio.queue.map((t) => t.id), state.queue.map((t) => t.id));
      },
    );
  }

  for (final replaces in [false, true]) {
    test(
      'new ${replaces ? 'replacement' : 'playAt'} waits for source reorder audio commit',
      () async {
        final h = await harness();
        final controller = h.container.read(playerControllerProvider.notifier);
        final gate = h.audio.holdNextQueue();
        final sorting = controller.reorderQueueForSource(
          _songs(_queue.reversed),
          source: _source,
        );
        await gate.entered.future;
        expect(
          h.container.read(playerControllerProvider).queue.map((t) => t.id),
          ['B', 'A'],
        );
        final next = replaces
            ? controller.replaceQueue([_queue[1]], queueSource: _otherSource)
            : controller.playAt(0);
        await Future<void>.delayed(Duration.zero);
        expect(h.audio.queueCalls, 2);
        gate.release.complete();
        expect(await sorting, isTrue);
        await next;
        final state = h.container.read(playerControllerProvider);
        expect(state.currentTrack!.id, 'B');
        expect(state.queue.map((t) => t.id), replaces ? ['B'] : ['B', 'A']);
        expect(state.queueSource, same(replaces ? _otherSource : _source));
        expect(h.audio.queue.map((t) => t.id), state.queue.map((t) => t.id));
        expect(h.audio.currentIndex, state.currentIndex);
        expect(h.audio.queueCalls, 3);
      },
    );
  }

  test('failed source reorder releases a waiting switch', () async {
    final h = await harness();
    final controller = h.container.read(playerControllerProvider.notifier);
    final gate = h.audio.holdNextQueue();
    final sorting = controller.reorderQueueForSource(
      _songs(_queue.reversed),
      source: _source,
    );
    final checkedSort = expectLater(sorting, throwsStateError);
    await gate.entered.future;
    final next = controller.playAt(0);
    await Future<void>.delayed(Duration.zero);
    expect(h.audio.queueCalls, 2);
    gate.release.completeError(StateError('held reorder failed'));
    await checkedSort;
    await next;
    final state = h.container.read(playerControllerProvider);
    expect(state.currentTrack!.id, 'B');
    expect(h.audio.queue.map((t) => t.id), ['B', 'A']);
    expect(h.audio.currentIndex, state.currentIndex);
  });

  test(
    'queued source reorder waits for newest switch and ignores late stale commit',
    () async {
      final h = await harness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final oldGate = h.audio.holdNextQueue();
      final oldSwitch = controller.playAt(1);
      await oldGate.entered.future;
      var sorted = false;
      final sorting = controller
          .reorderQueueForSource(_songs(_queue.reversed), source: _source)
          .then((value) {
            sorted = true;
            return value;
          });
      final newGate = h.audio.holdNextQueue();
      final newSwitch = controller.playAt(0);
      await newGate.entered.future;
      expect(sorted, isFalse);
      expect(
        h.container.read(playerControllerProvider).requestedTrack!.id,
        'A',
      );
      newGate.release.complete();
      await newSwitch;
      expect(await sorting, isTrue);
      oldGate.release.complete();
      await oldSwitch;
      final state = h.container.read(playerControllerProvider);
      expect(state.queue.map((t) => t.id), ['B', 'A']);
      expect(state.currentTrack!.id, 'A');
      expect(state.currentIndex, 1);
      expect(h.audio.queue.map((t) => t.id), ['B', 'A']);
      expect(h.audio.currentIndex, 1);
    },
  );

  test(
    'newest switch wins when two requests wait for source reorder',
    () async {
      final h = await harness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final gate = h.audio.holdNextQueue();
      final sorting = controller.reorderQueueForSource(
        _songs(_queue.reversed),
        source: _source,
      );
      await gate.entered.future;
      final oldSwitch = controller.playAt(0);
      await Future<void>.delayed(Duration.zero);
      final newSwitch = controller.playAt(1);
      await Future<void>.delayed(Duration.zero);
      expect(h.audio.queueCalls, 2);
      gate.release.complete();
      expect(await sorting, isTrue);
      await Future.wait([oldSwitch, newSwitch]);
      final state = h.container.read(playerControllerProvider);
      expect(state.currentTrack!.id, 'A');
      expect(state.currentIndex, 1);
      expect(h.audio.queue.map((t) => t.id), ['B', 'A']);
      expect(h.audio.currentIndex, 1);
      expect(h.audio.queueCalls, 3);
    },
  );

  test(
    'real adapter pending source load settles before source reorder',
    () async {
      final h = await nativeHarness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final entered = Completer<void>();
      final release = Completer<void>();
      Future<void> holdLoad(LoadRequest _) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }

      // stop may recreate the native player, so cover both the live instance and init.
      h.native.beforeLoad = holdLoad;
      h.native.current.beforeLoad = holdLoad;
      final switching = controller.playAt(1);
      await entered.future.timeout(const Duration(seconds: 3));
      expect(
        h.container.read(playerControllerProvider).requestedTrack!.id,
        'B',
      );
      final sorting = controller.reorderQueueForSource(
        _songs(_queue.reversed),
        source: _source,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        h.container.read(playerControllerProvider).requestedTrack!.id,
        'B',
      );
      expect(
        h.container.read(playerControllerProvider).queue.map((t) => t.id),
        ['A', 'B'],
      );
      release.complete();
      await switching;
      expect(await sorting, isTrue);
      await Future<void>.delayed(Duration.zero);
      final state = h.container.read(playerControllerProvider);
      expect(state.currentTrack!.id, 'B');
      expect(state.currentIndex, 0);
      expect(state.queue.map((t) => t.id), ['B', 'A']);
      expect(h.handler.queue.value.map((t) => t.id), ['B', 'A']);
      expect(h.player.playing, isTrue);
      expect(state.requestedTrackIndex, isNull);
    },
  );

  test(
    'real adapter late switch follows held source reorder submission',
    () async {
      final h = await nativeHarness();
      final controller = h.container.read(playerControllerProvider.notifier);
      final gate = h.audio.holdNextQueue();
      final sorting = controller.reorderQueueForSource(
        _songs(_queue.reversed),
        source: _source,
      );
      await gate.entered.future;
      final next = controller.playAt(0);
      await Future<void>.delayed(Duration.zero);
      // The late switch cannot stop/load the old audio queue while reorder is held.
      expect(h.handler.queue.value.map((t) => t.id), ['A', 'B']);
      expect(
        h.container.read(playerControllerProvider).queue.map((t) => t.id),
        ['B', 'A'],
      );
      gate.release.complete();
      expect(await sorting, isTrue);
      await next;
      await Future<void>.delayed(Duration.zero);
      final state = h.container.read(playerControllerProvider);
      expect(state.currentTrack!.id, 'B');
      expect(state.currentIndex, 0);
      expect(state.queue.map((t) => t.id), ['B', 'A']);
      expect(h.handler.queue.value.map((t) => t.id), ['B', 'A']);
      expect(h.handler.mediaItem.value!.id, 'B');
      expect(h.player.playing, isTrue);
    },
  );
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(localeCode: 'zh-CN');
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

class _HeldQueuePlayer extends AudioPlayerPort {
  _QueueGate? _nextGate;
  int queueCalls = 0;
  int currentIndex = 0;
  List<AudioTrack> queue = [];

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
    final version = ++queueCalls;
    final gate = _nextGate;
    _nextGate = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.release.future;
    }
    // The production audio handler discards superseded source submissions too.
    if (version != queueCalls) return;
    queue = tracks;
    currentIndex = initialIndex;
  }

  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<bool> get loadingStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<dynamic> get customEventStream => const Stream.empty();
  @override
  Future<CurrentLyricStateSnapshot> getCurrentLyricState() async =>
      const CurrentLyricStateSnapshot();
  @override
  Future<void> setSource(AudioTrack track, {String? forcedQualityName}) async {}
  @override
  Future<void> playAt(int index) async {}
  @override
  Future<void> seekToNext() async {}
  @override
  Future<void> seekToPrevious() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setSingleLoop(bool enabled) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}
