import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_handler_player_adapter.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_port.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_projector.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('重复启停只调用一次 visualizer，并由 adapter 暴露同一端口', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    var startCount = 0;
    var stopCount = 0;
    final handler = _buildHandler(
      fft: fft,
      start: () async => startCount += 1,
      stop: () async => stopCount += 1,
    );
    addTearDown(fft.close);
    addTearDown(handler.disposeHandler);

    final adapter = AudioHandlerPlayerAdapter(handler);
    expect(adapter, isA<AudioSpectrumPort>());

    await adapter.startSpectrumCapture();
    await adapter.startSpectrumCapture();
    await adapter.stopSpectrumCapture();
    await adapter.stopSpectrumCapture();

    expect(startCount, 1);
    expect(stopCount, 1);
  });

  test('快速 start 后 stop 会等待启动完成再串行停止', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    final startGate = Completer<void>();
    var startInFlight = false;
    var stopCount = 0;
    final handler = _buildHandler(
      fft: fft,
      start: () async {
        startInFlight = true;
        await startGate.future;
        startInFlight = false;
      },
      stop: () async {
        expect(startInFlight, isFalse);
        stopCount += 1;
      },
    );
    addTearDown(fft.close);
    addTearDown(handler.disposeHandler);

    final starting = handler.startSpectrumCapture();
    await Future<void>.delayed(Duration.zero);
    final stopping = handler.stopSpectrumCapture();

    expect(stopCount, 0);
    startGate.complete();
    await Future.wait(<Future<void>>[starting, stopping]);

    expect(stopCount, 1);
  });

  test('启动 Future 完成边界改变目标仍会收敛到停止', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    final startGate = Completer<void>();
    final stopScheduled = Completer<void>();
    Future<void>? stopping;
    var stopCount = 0;
    late final HeAudioHandler handler;
    handler = _buildHandler(
      fft: fft,
      start: () async {
        await startGate.future;
        scheduleMicrotask(() {
          stopping = handler.stopSpectrumCapture();
          stopScheduled.complete();
        });
      },
      stop: () async => stopCount += 1,
    );
    addTearDown(fft.close);
    addTearDown(handler.disposeHandler);

    final starting = handler.startSpectrumCapture();
    startGate.complete();
    await stopScheduled.future;
    await starting;
    await stopping!;

    expect(stopCount, 1);
  });

  test('每个 33ms 周期只广播最新 FFT，并支持多个消费者', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    final handler = _buildHandler(fft: fft);
    addTearDown(fft.close);
    addTearDown(handler.disposeHandler);
    await handler.startSpectrumCapture();

    final firstConsumer = handler.spectrumFrameStream.first.timeout(
      const Duration(milliseconds: 300),
    );
    final secondConsumer = handler.spectrumFrameStream.first.timeout(
      const Duration(milliseconds: 300),
    );
    fft.add(_captureWithPeakAtBand(4));
    fft.add(_captureWithPeakAtBand(52));

    final frames = await Future.wait(<Future<AudioSpectrumFrame>>[
      firstConsumer,
      secondConsumer,
    ]);

    expect(_peakIndex(frames[0].bands), 52);
    expect(frames[1].bands, frames[0].bands);
  });

  test('source generation 改变后不再提交旧捕获订阅的帧', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    final handler = _buildHandler(
      fft: fft,
      setAudioSource: (source, player) async => null,
    );
    addTearDown(fft.close);
    addTearDown(handler.disposeHandler);
    final frames = <AudioSpectrumFrame>[];
    final subscription = handler.spectrumFrameStream.listen(frames.add);
    addTearDown(subscription.cancel);
    await handler.startSpectrumCapture();

    fft.add(_captureWithPeakAtBand(8));
    await _waitFor(() => frames.length == 1);

    await handler.setQueueData(<AudioTrack>[
      const AudioTrack(
        id: 'local-song',
        title: '本地歌曲',
        url: '',
        path: '/tmp/local-song.mp3',
        platform: 'local',
      ),
    ]);
    fft.add(_captureWithPeakAtBand(40));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(frames, hasLength(1));
  });

  test('dispose 会停止捕获、关闭广播流并拒绝再次启动', () async {
    final fft = StreamController<VisualizerFftCapture>.broadcast(sync: true);
    var stopCount = 0;
    final handler = _buildHandler(fft: fft, stop: () async => stopCount += 1);
    final streamDone = Completer<void>();
    handler.spectrumFrameStream.listen(null, onDone: streamDone.complete);
    await handler.startSpectrumCapture();

    await handler.disposeHandler();

    expect(stopCount, 1);
    await streamDone.future.timeout(const Duration(milliseconds: 300));
    await expectLater(handler.startSpectrumCapture(), throwsStateError);
    await fft.close();
  });
}

HeAudioHandler _buildHandler({
  required StreamController<VisualizerFftCapture> fft,
  Future<void> Function()? start,
  Future<void> Function()? stop,
  HeAudioHandlerSetAudioSource? setAudioSource,
}) {
  return HeAudioHandler(
    setAudioSourceOverride: setAudioSource,
    startVisualizerOverride: (_) => start?.call() ?? Future<void>.value(),
    stopVisualizerOverride: (_) => stop?.call() ?? Future<void>.value(),
    visualizerFftStreamOverride: (_) => fft.stream,
  );
}

VisualizerFftCapture _captureWithPeakAtBand(int bandIndex) {
  const dataLength = 1024;
  final bin = buildAudioSpectrumBinRanges(dataLength ~/ 2 + 1)[bandIndex].start;
  final data = Int8List(dataLength);
  data[bin * 2] = 120;
  return VisualizerFftCapture(samplingRate: 44100, data: data);
}

int _peakIndex(List<double> values) {
  var peakIndex = 0;
  for (var index = 1; index < values.length; index += 1) {
    if (values[index] > values[peakIndex]) peakIndex = index;
  }
  return peakIndex;
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(milliseconds: 300));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('等待频谱帧超时。');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
