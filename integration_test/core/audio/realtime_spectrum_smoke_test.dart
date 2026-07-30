import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('当前播放器在真实插件上持续产生可启停的 FFT', (_) async {
    if (Platform.isAndroid) {
      await _waitForAndroidRecordAudioPermission();
    }

    final fixture = await _SpectrumFixture.create();
    final player = AudioPlayer(
      useProxyForRequestHeaders: false,
      userAgent: 'HE-Music spectrum integration smoke',
    );
    final rawStats = _RawFftStats();
    final rawSubscription = player.visualizerFftStream.listen(rawStats.add);
    final handler = HeAudioHandler(
      player: player,
      fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
          const LyricDocument.empty(),
    );
    addTearDown(() async {
      await rawSubscription.cancel();
      await handler.disposeHandler();
      await fixture.dispose();
    });

    await handler.setVolumeValue(1);
    await handler.setSingleLoopMode(true);

    await _playTrack(handler, fixture.lowLocalTrack);
    final lowProfile = await _captureProfile(
      handler,
      player: player,
      rawStats: rawStats,
    );
    expect(lowProfile.nonZeroFrames, greaterThan(0));

    await _playTrack(handler, fixture.highHttpTrack);
    final highProfile = await _captureProfile(
      handler,
      player: player,
      rawStats: rawStats,
    );
    expect(highProfile.nonZeroFrames, greaterThan(0));
    expect(
      highProfile.peakBand,
      greaterThan(lowProfile.peakBand),
      reason: '高频片段的峰值频带必须高于低频片段。',
    );

    await _verifyPauseAndResume(handler, player, rawStats);

    await _verifyStoppedTrackChangeAndResume(
      handler,
      player,
      rawStats,
      nextTrack: fixture.lowLocalTrack,
    );
    await _verifyRepeatedStartStop(handler, player, rawStats, cycles: 20);

    final rssBefore = ProcessInfo.currentRss;
    final rawBefore = rawStats.count;
    final outputStats = _OutputFrameStats();
    final outputSubscription = handler.spectrumFrameStream.listen(
      outputStats.add,
    );
    final stabilityWatch = Stopwatch()..start();
    await handler.startSpectrumCapture();
    await Future<void>.delayed(const Duration(seconds: 30));
    final midpointRawCount = rawStats.count;
    final midpointOutputCount = outputStats.count;
    await Future<void>.delayed(const Duration(seconds: 30));
    await handler.stopSpectrumCapture();
    stabilityWatch.stop();
    await outputSubscription.cancel();
    final rssDelta = ProcessInfo.currentRss - rssBefore;
    final rawFrameCount = rawStats.count - rawBefore;
    final rawFps = rawFrameCount / stabilityWatch.elapsedMilliseconds * 1000;
    final outputFps =
        outputStats.count / stabilityWatch.elapsedMilliseconds * 1000;

    expect(rawFrameCount, greaterThan(0));
    expect(rawStats.count, greaterThan(midpointRawCount));
    expect(outputStats.count, greaterThan(midpointOutputCount));
    expect(outputStats.nonZeroCount, greaterThan(0));
    expect(rawFps, greaterThanOrEqualTo(5));
    expect(outputFps, lessThanOrEqualTo(31.5));
    expect(handler.playbackState.value.playing, isTrue);
    expect(rssDelta, lessThan(128 * 1024 * 1024));
    await _expectRawCaptureStopped(rawStats);

    debugPrint(
      'FFT_GATE '
      'platform=${Platform.operatingSystem} '
      'os=${Platform.operatingSystemVersion} '
      'captureSizes=${rawStats.captureSizes.toList()..sort()} '
      'samplingRates=${rawStats.samplingRates.toList()..sort()} '
      'rawFrames=$rawFrameCount '
      'rawFps=${rawFps.toStringAsFixed(2)} '
      'outputFrames=${outputStats.count} '
      'outputFps=${outputFps.toStringAsFixed(2)} '
      'rssDeltaBytes=$rssDelta '
      'lowPeak=${lowProfile.peakBand} '
      'highPeak=${highProfile.peakBand}',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _waitForAndroidRecordAudioPermission() async {
  if (await Permission.microphone.status == PermissionStatus.granted) return;

  debugPrint(
    'FFT_GATE_WAIT_PERMISSION '
    '请在手机设置中打开 HE-Music Debug > 权限 > 麦克风，'
    '选择“使用应用时允许”。测试会在授权后自动继续。',
  );
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (await Permission.microphone.status != PermissionStatus.granted) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('120 秒内未检测到 RECORD_AUDIO 授权。');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> _playTrack(HeAudioHandler handler, AudioTrack track) async {
  await handler.stopSpectrumCapture();
  await handler.pause();
  await handler.setQueueData(<AudioTrack>[track], forceReloadCurrent: true);
  await handler.play();
  await _waitFor(
    () => handler.playbackState.value.playing,
    timeout: const Duration(seconds: 3),
    description: '等待播放器进入 playing 状态',
  );
}

Future<_BandProfile> _captureProfile(
  HeAudioHandler handler, {
  required AudioPlayer player,
  required _RawFftStats rawStats,
}) async {
  final completer = Completer<_BandProfile>();
  final sums = List<double>.filled(AudioSpectrumFrame.bandCount, 0);
  final rawFrameCountBefore = rawStats.count;
  var frameCount = 0;
  var nonZeroFrames = 0;
  late final StreamSubscription<AudioSpectrumFrame> subscription;
  subscription = handler.spectrumFrameStream.listen((frame) {
    frameCount += 1;
    var hasEnergy = false;
    for (var index = 0; index < frame.bands.length; index += 1) {
      final value = frame.bands[index];
      sums[index] += value;
      hasEnergy = hasEnergy || value > 0;
    }
    if (hasEnergy) nonZeroFrames += 1;
    if (frameCount >= 12 && nonZeroFrames >= 8 && !completer.isCompleted) {
      completer.complete(
        _BandProfile(peakBand: _peakIndex(sums), nonZeroFrames: nonZeroFrames),
      );
    }
  });

  try {
    await handler.startSpectrumCapture();
    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw TimeoutException(
        '等待可用频谱帧超时：'
        'audioSessionId=${player.androidAudioSessionId}, '
        'rawFrames=${rawStats.count - rawFrameCountBefore}, '
        'rawNonZeroFrames=${rawStats.nonZeroCount}, '
        'rawPeakMagnitude=${rawStats.peakMagnitude.toStringAsFixed(2)}, '
        'rawMeanPeakMagnitude=${rawStats.meanPeakMagnitude.toStringAsFixed(2)}, '
        'outputFrames=$frameCount, '
        'nonZeroOutputFrames=$nonZeroFrames, '
        'playerState=${player.playerState}, '
        'positionMs=${player.position.inMilliseconds}, '
        'durationMs=${player.duration?.inMilliseconds}, '
        'captureSizes=${rawStats.captureSizes.toList()..sort()}, '
        'samplingRates=${rawStats.samplingRates.toList()..sort()}',
      );
    }
  } finally {
    await handler.stopSpectrumCapture();
    await subscription.cancel();
  }
}

Future<void> _verifyPauseAndResume(
  HeAudioHandler handler,
  AudioPlayer player,
  _RawFftStats rawStats,
) async {
  final beforePauseCapture = rawStats.count;
  await handler.startSpectrumCapture();
  await _waitFor(
    () => rawStats.count > beforePauseCapture,
    timeout: const Duration(seconds: 3),
    description: '等待暂停前的 FFT',
  );
  await handler.pause();
  await handler.stopSpectrumCapture();
  await _expectRawCaptureStopped(rawStats);

  await handler.play();
  await _waitFor(
    () => handler.playbackState.value.playing,
    timeout: const Duration(seconds: 3),
    description: '等待暂停后继续播放',
  );
  final resumedProfile = await _captureProfile(
    handler,
    player: player,
    rawStats: rawStats,
  );
  expect(resumedProfile.nonZeroFrames, greaterThan(0));
}

Future<void> _verifyRepeatedStartStop(
  HeAudioHandler handler,
  AudioPlayer player,
  _RawFftStats rawStats, {
  required int cycles,
}) async {
  for (var cycle = 0; cycle < cycles; cycle += 1) {
    final before = rawStats.count;
    await handler.startSpectrumCapture();
    await _waitFor(
      () => rawStats.count > before,
      timeout: const Duration(seconds: 3),
      description: '等待第 ${cycle + 1} 次启动产生 FFT',
    );
    final positionBeforeStop = player.position;
    final stopWatch = Stopwatch()..start();
    await handler.stopSpectrumCapture();
    await _expectRawCaptureStopped(rawStats);
    stopWatch.stop();
    final positionAdvance = player.position - positionBeforeStop;
    expect(player.playing, isTrue, reason: '停止频谱不得改变播放状态。');
    expect(
      positionAdvance.inMilliseconds,
      greaterThanOrEqualTo(stopWatch.elapsedMilliseconds - 250),
      reason: '停止频谱期间播放时间轴不得出现明显停顿。',
    );
  }
}

Future<void> _verifyStoppedTrackChangeAndResume(
  HeAudioHandler handler,
  AudioPlayer player,
  _RawFftStats rawStats, {
  required AudioTrack nextTrack,
}) async {
  final beforeStop = rawStats.count;
  await handler.startSpectrumCapture();
  await _waitFor(
    () => rawStats.count > beforeStop,
    timeout: const Duration(seconds: 3),
    description: '等待后台切歌前产生 FFT',
  );
  await handler.stopSpectrumCapture();
  await _expectRawCaptureStopped(rawStats);

  await _playTrack(handler, nextTrack);
  await Future<void>.delayed(const Duration(milliseconds: 400));

  final beforeResume = rawStats.count;
  final positionBeforeResume = player.position;
  final resumeWatch = Stopwatch()..start();
  await handler.startSpectrumCapture();
  await _waitFor(
    () => rawStats.count > beforeResume,
    timeout: const Duration(seconds: 3),
    description: '等待后台切歌后恢复 FFT',
  );
  resumeWatch.stop();

  expect(player.playing, isTrue, reason: '后台切歌后恢复频谱不得改变播放状态。');
  expect(
    (player.position - positionBeforeResume).inMilliseconds,
    greaterThanOrEqualTo(resumeWatch.elapsedMilliseconds - 250),
    reason: '后台切歌后恢复频谱期间播放时间轴不得出现明显停顿。',
  );
  await handler.stopSpectrumCapture();
  await _expectRawCaptureStopped(rawStats);
}

Future<void> _expectRawCaptureStopped(_RawFftStats rawStats) async {
  // Darwin 会把 tap 回调投递到主线程，先给已排队的尾帧一个排空窗口。
  await Future<void>.delayed(const Duration(milliseconds: 180));
  final settledCount = rawStats.count;
  await Future<void>.delayed(const Duration(milliseconds: 220));
  expect(rawStats.count, settledCount, reason: 'stop 后不得持续产生原始 FFT 帧。');
}

Future<void> _waitFor(
  bool Function() condition, {
  required Duration timeout,
  required String description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(description);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

int _peakIndex(List<double> values) {
  var peakIndex = 0;
  for (var index = 1; index < values.length; index += 1) {
    if (values[index] > values[peakIndex]) peakIndex = index;
  }
  return peakIndex;
}

class _BandProfile {
  const _BandProfile({required this.peakBand, required this.nonZeroFrames});

  final int peakBand;
  final int nonZeroFrames;
}

class _RawFftStats {
  int count = 0;
  int nonZeroCount = 0;
  double peakMagnitude = 0;
  double _peakMagnitudeSum = 0;
  final Set<int> captureSizes = <int>{};
  final Set<int> samplingRates = <int>{};

  double get meanPeakMagnitude => count == 0 ? 0 : _peakMagnitudeSum / count;

  void add(VisualizerFftCapture capture) {
    count += 1;
    captureSizes.add(capture.data.length);
    samplingRates.add(capture.samplingRate);
    var framePeakMagnitude = 0.0;
    for (var bin = 1; bin < capture.length; bin += 1) {
      final magnitude = capture.getMagnitude(bin);
      if (magnitude.isFinite && magnitude > framePeakMagnitude) {
        framePeakMagnitude = magnitude;
      }
    }
    if (framePeakMagnitude > 0) nonZeroCount += 1;
    peakMagnitude = math.max(peakMagnitude, framePeakMagnitude);
    _peakMagnitudeSum += framePeakMagnitude;
  }
}

class _OutputFrameStats {
  int count = 0;
  int nonZeroCount = 0;

  void add(AudioSpectrumFrame frame) {
    count += 1;
    if (frame.bands.any((value) => value > 0)) nonZeroCount += 1;
  }
}

class _SpectrumFixture {
  _SpectrumFixture({
    required this.directory,
    required this.server,
    required this.lowLocalTrack,
    required this.highHttpTrack,
  });

  final Directory directory;
  final HttpServer server;
  final AudioTrack lowLocalTrack;
  final AudioTrack highHttpTrack;

  static Future<_SpectrumFixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'he_music_spectrum_smoke_',
    );
    final lowFile = File('${directory.path}/low.wav');
    final highBytes = _buildToneWav(frequency: 4000);
    await lowFile.writeAsBytes(
      _buildToneWav(frequency: 220, duration: const Duration(seconds: 90)),
      flush: true,
    );

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(server.forEach((request) => _serveWav(request, highBytes)));

    return _SpectrumFixture(
      directory: directory,
      server: server,
      lowLocalTrack: AudioTrack(
        id: 'spectrum-low-local',
        title: 'Spectrum low tone',
        url: '',
        path: lowFile.path,
        platform: 'local',
      ),
      highHttpTrack: AudioTrack(
        id: 'spectrum-high-http',
        title: 'Spectrum high tone',
        url: 'http://127.0.0.1:${server.port}/high.wav',
      ),
    );
  }

  Future<void> dispose() async {
    await server.close(force: true);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

Future<void> _serveWav(HttpRequest request, Uint8List bytes) async {
  if (request.uri.path != '/high.wav') {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  var start = 0;
  var end = bytes.length - 1;
  final range = request.headers.value(HttpHeaders.rangeHeader);
  final match = range == null
      ? null
      : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
  if (match != null) {
    start = int.parse(match.group(1)!);
    final requestedEnd = match.group(2)!;
    if (requestedEnd.isNotEmpty) end = int.parse(requestedEnd);
    end = math.min(end, bytes.length - 1);
    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${bytes.length}',
    );
  }

  request.response.headers.contentType = ContentType('audio', 'wav');
  request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  request.response.contentLength = end - start + 1;
  if (request.method != 'HEAD') {
    request.response.add(bytes.sublist(start, end + 1));
  }
  await request.response.close();
}

Uint8List _buildToneWav({
  required double frequency,
  int sampleRate = 44100,
  Duration duration = const Duration(seconds: 3),
}) {
  final sampleCount = sampleRate * duration.inMilliseconds ~/ 1000;
  final pcmLength = sampleCount * 2;
  final bytes = Uint8List(44 + pcmLength);
  final data = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + pcmLength, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  data.setUint32(40, pcmLength, Endian.little);

  for (var index = 0; index < sampleCount; index += 1) {
    final phase = 2 * math.pi * frequency * index / sampleRate;
    final sample = (math.sin(phase) * 32767 * 0.08).round();
    data.setInt16(44 + index * 2, sample, Endian.little);
  }
  return bytes;
}

void _writeAscii(Uint8List target, int offset, String value) {
  for (var index = 0; index < value.length; index += 1) {
    target[offset + index] = value.codeUnitAt(index);
  }
}
