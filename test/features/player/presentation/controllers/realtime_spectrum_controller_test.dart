import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_port.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/realtime_spectrum_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('仅在消费者可见且播放就绪时启动，并去重重复目标', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);

    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();
    controller.setConsumerVisible(true);
    await tester.pump();

    expect(port.startCount, 1);
    expect(
      harness.container.read(realtimeSpectrumControllerProvider).status,
      RealtimeSpectrumStatus.running,
    );

    controller.setConsumerVisible(false);
    await tester.pump();
    controller.setConsumerVisible(false);
    await tester.pump();

    expect(port.stopCount, 1);
    expect(
      harness.container.read(realtimeSpectrumControllerProvider).status,
      RealtimeSpectrumStatus.idle,
    );
  });

  testWidgets('启动尚未完成时隐藏会等待启动后再串行停止', (tester) async {
    final startGate = Completer<void>();
    final port = _FakeSpectrumPort(startGate: startGate);
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );

    controller.setConsumerVisible(true);
    await tester.pump();
    controller.setConsumerVisible(false);
    await tester.pump();
    expect(port.stopCount, 0);

    startGate.complete();
    await tester.pump();
    await tester.pump();

    expect(port.startCount, 1);
    expect(port.stopCount, 1);
    expect(port.calls, <String>['start', 'stop']);
  });

  testWidgets('播放中切歌会停止旧 generation 后重新启动', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();

    harness.player.setTrack('song-b');
    await tester.pump();
    await tester.pump();

    expect(port.calls, <String>['start', 'stop', 'start']);
  });

  testWidgets('启动失败不会生成假频谱或在相同目标下重试', (tester) async {
    final port = _FakeSpectrumPort(startError: StateError('denied'));
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );

    controller.setConsumerVisible(true);
    await tester.pump();
    harness.player.setLoading(true);
    await tester.pump();
    harness.player.setLoading(false);
    await tester.pump();

    final state = harness.container.read(realtimeSpectrumControllerProvider);
    expect(port.startCount, 1);
    expect(state.status, RealtimeSpectrumStatus.failed);
    expect(state.bands, everyElement(0));
  });

  testWidgets('真实帧快起并在停止后约 300ms 平滑归零', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();

    port.addFrame(_frameAt(8, 1));
    await tester.pump(RealtimeSpectrumController.tickPeriod);
    await tester.pump(RealtimeSpectrumController.tickPeriod);
    final raised = harness.container.read(realtimeSpectrumControllerProvider);
    expect(raised.bands[8], greaterThan(0.5));
    expect(raised.bands.where((value) => value > 0).length, 1);

    harness.player.setPlaying(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final falling = harness.container.read(realtimeSpectrumControllerProvider);
    expect(falling.bands[8], greaterThan(0));
    expect(falling.bands[8], lessThan(raised.bands[8]));

    await tester.pump(const Duration(milliseconds: 1200));
    final stopped = harness.container.read(realtimeSpectrumControllerProvider);
    expect(stopped.bands, everyElement(0));
    expect(port.stopCount, 1);
  });

  testWidgets('正常波动按 release 回落，无数据超时后归零但保持捕获', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();

    port.addFrame(_frameAt(12, 1));
    await tester.pump(RealtimeSpectrumController.tickPeriod * 2);
    final raised = harness.container.read(realtimeSpectrumControllerProvider);

    port.addFrame(_frameAt(12, 0));
    await tester.pump(RealtimeSpectrumController.tickPeriod);
    final released = harness.container.read(realtimeSpectrumControllerProvider);
    expect(released.bands[12], greaterThan(0));
    expect(released.bands[12], lessThan(raised.bands[12]));

    port.addFrame(_frameAt(12, 1));
    await tester.pump(RealtimeSpectrumController.tickPeriod * 2);
    await tester.runAsync(
      () => Future<void>.delayed(
        RealtimeSpectrumController.frameTimeout +
            RealtimeSpectrumController.tickPeriod,
      ),
    );
    await tester.pump(RealtimeSpectrumController.tickPeriod);
    await tester.pump(const Duration(milliseconds: 1200));

    final stale = harness.container.read(realtimeSpectrumControllerProvider);
    expect(stale.bands, everyElement(0));
    expect(port.stopCount, 0);
  });

  testWidgets('进入缓冲时停止捕获，恢复就绪后重新启动', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();

    harness.player.setLoading(true);
    await tester.pump();
    expect(port.calls, <String>['start', 'stop']);

    harness.player.setLoading(false);
    await tester.pump();
    expect(port.calls, <String>['start', 'stop', 'start']);
  });

  testWidgets('协调器销毁时停止仍在运行的捕获', (tester) async {
    final port = _FakeSpectrumPort();
    final harness = _buildHarness(port: port);
    final controller = harness.container.read(
      realtimeSpectrumControllerProvider.notifier,
    );
    controller.setConsumerVisible(true);
    await tester.pump();
    expect(port.startCount, 1);

    harness.dispose();
    await tester.pump();
    await tester.pump();

    expect(port.stopCount, 1);
  });
}

_SpectrumHarness _buildHarness({required _FakeSpectrumPort port}) {
  final player = _SpectrumPlayerController();
  final container = ProviderContainer(
    overrides: [
      playerControllerProvider.overrideWith(() => player),
      audioSpectrumPortProvider.overrideWithValue(port),
    ],
  );
  final subscription = container.listen<RealtimeSpectrumState>(
    realtimeSpectrumControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  return _SpectrumHarness(
    container: container,
    player: player,
    subscription: subscription,
  );
}

class _SpectrumHarness {
  _SpectrumHarness({
    required this.container,
    required this.player,
    required this.subscription,
  });

  final ProviderContainer container;
  final _SpectrumPlayerController player;
  final ProviderSubscription<RealtimeSpectrumState> subscription;

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

class _SpectrumPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(<PlayerTrack>[
      const PlayerTrack(
        id: 'song-a',
        title: 'Song A',
        artist: 'Artist',
        platform: 'local',
      ),
    ]).copyWith(isPlaying: true);
  }

  void setTrack(String id) {
    state = state.copyWith(
      queue: <PlayerTrack>[
        PlayerTrack(id: id, title: id, artist: 'Artist', platform: 'local'),
      ],
      currentIndex: 0,
    );
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setPlaying(bool value) {
    state = state.copyWith(isPlaying: value);
  }
}

class _FakeSpectrumPort implements AudioSpectrumPort {
  _FakeSpectrumPort({this.startGate, this.startError});

  final Completer<void>? startGate;
  final Object? startError;
  final StreamController<AudioSpectrumFrame> _frames =
      StreamController<AudioSpectrumFrame>.broadcast(sync: true);
  final List<String> calls = <String>[];
  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<AudioSpectrumFrame> get spectrumFrameStream => _frames.stream;

  @override
  Future<void> startSpectrumCapture() async {
    startCount += 1;
    calls.add('start');
    final error = startError;
    if (error != null) {
      throw error;
    }
    await startGate?.future;
  }

  @override
  Future<void> stopSpectrumCapture() async {
    stopCount += 1;
    calls.add('stop');
  }

  void addFrame(AudioSpectrumFrame frame) {
    _frames.add(frame);
  }
}

AudioSpectrumFrame _frameAt(int index, double value) {
  final bands = List<double>.filled(AudioSpectrumFrame.bandCount, 0);
  bands[index] = value;
  return AudioSpectrumFrame(bands);
}
