// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

const _httpsOrigin = String.fromEnvironment(
  'AUDIO_CACHE_SPIKE_HTTPS_URL',
  defaultValue: 'https://samplelib.com/mp3/sample-3s.mp3',
);
const _httpsExpectedBytes = int.fromEnvironment(
  'AUDIO_CACHE_SPIKE_HTTPS_EXPECTED_BYTES',
  defaultValue: 52079,
);
const _backgroundWaitSeconds = int.fromEnvironment(
  'AUDIO_CACHE_SPIKE_BACKGROUND_WAIT_SECONDS',
  defaultValue: 0,
);
const _exitAfterRun = bool.fromEnvironment(
  'AUDIO_CACHE_SPIKE_EXIT_AFTER_RUN',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'vendored cache source release spike',
    (_) async {
      final directory = await getTemporaryDirectory();
      final spikeDirectory = Directory('${directory.path}/audio-cache-spike');
      if (await spikeDirectory.exists()) {
        await spikeDirectory.delete(recursive: true);
      }
      await spikeDirectory.create(recursive: true);
      final origin = await _SpikeOrigin.start();
      final player = AudioPlayer();
      final playbackErrors = <Object>[];
      final playbackEvents = player.playbackEventStream.listen(
        (_) {},
        onError: (Object error, StackTrace _) => playbackErrors.add(error),
      );
      String? result;

      _phase('origin_started');
      try {
        final httpCache = File('${spikeDirectory.path}/http.wav');
        final httpSource = LockCachingAudioSource(
          origin.uri('/audio.wav'),
          cacheFile: httpCache,
        );
        _phase('http_prepare_start');
        await player.setAudioSource(httpSource);
        _phase('http_prepare_done bytes=${httpSource.debugDownloadedBytes}');
        _issuePlay(player, playbackErrors);
        var activeSeek = false;
        if (httpSource.downloadState == LockCachingAudioSourceState.active) {
          await player
              .seek(const Duration(seconds: 8))
              .timeout(const Duration(seconds: 15));
          activeSeek = true;
          _phase('active_seek_done');
        }
        await httpSource.completedFile.timeout(const Duration(seconds: 30));
        _phase('http_download_done');
        expect(httpSource.downloadState, LockCachingAudioSourceState.completed);
        expect(httpSource.debugActiveResourceCount, 0);
        expect(origin.fullRequests, 1);
        if (Platform.isAndroid || Platform.isMacOS) {
          expect(activeSeek, isTrue);
        }
        await player
            .seek(const Duration(seconds: 2))
            .timeout(const Duration(seconds: 15));

        _phase('http_seek_done');
        if (Platform.isMacOS) {
          _phase('fft_start');
          final fft = player.visualizerFftStream.first.timeout(
            const Duration(seconds: 10),
          );
          await player.startVisualizer(
            enableWaveform: false,
            enableFft: true,
            captureRate: 30000,
            captureSize: 1024,
          );
          await fft;
          await player.stopVisualizer();
          _phase('fft_done');
        }

        if (_backgroundWaitSeconds > 0) {
          await player.setLoopMode(LoopMode.one);
          final backgroundStartPosition = player.position;
          debugPrint('AUDIO_CACHE_SPIKE phase=background_window');
          await Future<void>.delayed(
            const Duration(seconds: _backgroundWaitSeconds),
          );
          final backgroundEndPosition = player.position;
          expect(player.playing, isTrue);
          expect(player.processingState, isNot(ProcessingState.completed));
          if (Platform.isAndroid) {
            final minimumAdvance = Duration(
              seconds: max(1, _backgroundWaitSeconds - 2),
            );
            expect(
              backgroundEndPosition - backgroundStartPosition,
              greaterThanOrEqualTo(minimumAdvance),
            );
          }
          await player.setLoopMode(LoopMode.off);
        }

        _phase('cancel_start');
        final cancelCache = File('${spikeDirectory.path}/cancel.wav');
        final cancelSource = LockCachingAudioSource(
          origin.uri('/cancel.wav'),
          cacheFile: cancelCache,
        );
        final cancelCompletion = cancelSource.completedFile.then<Object>(
          (file) => file,
          onError: (Object error, StackTrace _) => error,
        );
        await player.setAudioSource(cancelSource);
        _issuePlay(player, playbackErrors);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final fallbackSource = AudioSource.file(httpCache.path);
        await player.setAudioSource(fallbackSource);
        await cancelSource.cancelDownload();
        await player.releaseAudioSource(cancelSource);
        expect(await cancelCompletion, isA<LockCachingAudioSourceException>());
        expect(
          cancelSource.downloadState,
          LockCachingAudioSourceState.cancelled,
        );
        expect(await File('${cancelCache.path}.part').exists(), isFalse);

        _phase('cancel_done');
        AudioSource? previous = fallbackSource;
        for (var i = 0; i < 30; i++) {
          final current = AudioSource.file(httpCache.path);
          await player.setAudioSource(current);
          if (previous != null) await player.releaseAudioSource(previous);
          previous = current;
        }
        _phase('replacement_done');
        await player.setAudioSources([], preload: false);
        await player.releaseAudioSource(previous!);
        await player.releaseAudioSource(httpSource);
        expect(player.debugAudioSourceRegistryCount, 1);
        expect(player.debugProxyHandlerCount, 0);

        _phase('https_start');
        final httpsCache = File('${spikeDirectory.path}/https.mp3');
        final httpsSource = LockCachingAudioSource(
          Uri.parse(_httpsOrigin),
          cacheFile: httpsCache,
        );
        await player.setAudioSource(httpsSource);
        _issuePlay(player, playbackErrors);
        final httpsFile = await httpsSource.completedFile.timeout(
          const Duration(seconds: 90),
        );
        _phase('https_download_done');
        final httpsBytes = await httpsFile.length();
        expect(httpsBytes, greaterThan(0));
        if (_httpsExpectedBytes > 0) {
          expect(httpsBytes, _httpsExpectedBytes);
        }
        expect(
          httpsSource.downloadState,
          LockCachingAudioSourceState.completed,
        );
        await player.setAudioSources([], preload: false);
        await player.releaseAudioSource(httpsSource);

        expect(player.debugAudioSourceRegistryCount, 1);
        expect(player.debugProxyHandlerCount, 0);
        expect(playbackErrors, isEmpty);
        result =
            'AUDIO_CACHE_SPIKE result=go '
            'platform=${Platform.operatingSystem} '
            'fullRequests=${origin.fullRequests} '
            'rangeRequests=${origin.rangeRequests} '
            'activeSeek=$activeSeek';
      } finally {
        _phase('cleanup_playback_subscription_start');
        await playbackEvents.cancel();
        _phase('cleanup_player_start');
        await player.dispose();
        _phase('cleanup_origin_start');
        await origin.close();
        _phase('cleanup_origin_done');
        if (await spikeDirectory.exists()) {
          await spikeDirectory.delete(recursive: true);
        }
      }
      debugPrint(result);
      if (_exitAfterRun) exit(0);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

void _phase(String phase) {
  debugPrint('AUDIO_CACHE_SPIKE phase=$phase');
}

void _issuePlay(AudioPlayer player, List<Object> playbackErrors) {
  unawaited(
    player.play().catchError((Object error, StackTrace _) {
      playbackErrors.add(error);
    }),
  );
}

class _SpikeOrigin {
  final HttpServer server;
  final List<int> bytes;
  final _handlerFutures = <Future<void>>{};
  Object? _unexpectedHandlerError;
  StackTrace? _unexpectedHandlerStackTrace;
  int fullRequests = 0;
  int rangeRequests = 0;

  _SpikeOrigin._(this.server, this.bytes);

  static Future<_SpikeOrigin> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = _SpikeOrigin._(server, _createWav(seconds: 16));
    server.listen(origin._track);
    return origin;
  }

  Uri uri(String path) =>
      Uri.parse('http://${server.address.address}:${server.port}$path');

  Future<void> close() async {
    await server.close(force: true);
    while (_handlerFutures.isNotEmpty) {
      await Future.wait(_handlerFutures.toList());
    }
    final error = _unexpectedHandlerError;
    if (error != null) {
      Error.throwWithStackTrace(
        error,
        _unexpectedHandlerStackTrace ?? StackTrace.current,
      );
    }
  }

  void _track(HttpRequest request) {
    late final Future<void> handlerFuture;
    handlerFuture = _runHandler(request).whenComplete(() {
      _handlerFutures.remove(handlerFuture);
    });
    _handlerFutures.add(handlerFuture);
  }

  Future<void> _runHandler(HttpRequest request) async {
    try {
      await _handle(request);
    } on SocketException {
      // Source cancellation is expected to close an in-flight loopback request.
    } on HttpException {
      // Source cancellation is expected to close an in-flight loopback request.
    } catch (error, stackTrace) {
      _unexpectedHandlerError ??= error;
      _unexpectedHandlerStackTrace ??= stackTrace;
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      rangeRequests++;
      _phase('origin_range');
      final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
      if (match == null) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await request.response.close();
        return;
      }
      final start = int.parse(match.group(1)!);
      final endExclusive = match.group(2)!.isEmpty
          ? bytes.length
          : min(bytes.length, int.parse(match.group(2)!) + 1);
      final body = bytes.sublist(start, endExclusive);
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${endExclusive - 1}/${bytes.length}',
      );
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.contentLength = body.length;
      request.response.add(body);
      await request.response.close();
      return;
    }

    fullRequests++;
    _phase('origin_full');
    request.response.bufferOutput = false;
    request.response.headers.contentType = ContentType('audio', 'wav');
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.contentLength = bytes.length;
    var disconnected = false;
    final responseDone = request.response.done.then<void>(
      (_) => disconnected = true,
      onError: (Object _, StackTrace _) => disconnected = true,
    );

    Future<bool> flushOrDisconnect() async {
      var flushed = false;
      await Future.any<void>([
        request.response.flush().then<void>((_) => flushed = true),
        responseDone,
        Future<void>.delayed(const Duration(seconds: 5)),
      ]);
      return flushed && !disconnected;
    }

    final delay = request.uri.path == '/cancel.wav'
        ? const Duration(milliseconds: 50)
        : const Duration(milliseconds: 8);
    for (var offset = 0; offset < bytes.length; offset += 4096) {
      final end = min(offset + 4096, bytes.length);
      request.response.add(bytes.sublist(offset, end));
      if (!await flushOrDisconnect()) return;
      await Future.any<void>([Future<void>.delayed(delay), responseDone]);
      if (disconnected) return;
    }
    await Future.any<void>([
      request.response.close(),
      responseDone,
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
  }

  static List<int> _createWav({required int seconds}) {
    const sampleRate = 8000;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = sampleRate * seconds;
    final dataLength = sampleCount * channels * (bitsPerSample ~/ 8);
    final data = ByteData(44 + dataLength);

    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < sampleCount; i++) {
      final sample = (sin(2 * pi * 440 * i / sampleRate) * 9000).round();
      data.setInt16(44 + i * 2, sample, Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
