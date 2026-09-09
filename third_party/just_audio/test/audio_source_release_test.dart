import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioSessionChannel = MethodChannel('com.ryanheise.audio_session');
  late JustAudioPlatform originalPlatform;
  late _ReleaseTestJustAudioPlatform platform;
  late Directory tempDirectory;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, (_) async => null);
    originalPlatform = JustAudioPlatform.instance;
    platform = _ReleaseTestJustAudioPlatform();
    JustAudioPlatform.instance = platform;
    tempDirectory =
        await Directory.systemTemp.createTemp('source_release_test');
  });

  tearDown(() async {
    JustAudioPlatform.instance = originalPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, null);
    await tempDirectory.delete(recursive: true);
  });

  test('100 source replacements return registries to the stable baseline',
      () async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    AudioSource? previous;

    for (var i = 0; i < 100; i++) {
      final source = switch (i % 3) {
        0 => LockCachingAudioSource(
            Uri.parse('https://example.invalid/audio-$i.mp3'),
            cacheFile: File('${tempDirectory.path}/cache-$i.mp3'),
          ),
        1 => AudioSource.uri(
            Uri.parse('https://example.invalid/audio.mp3'),
            headers: {'X-Test': '$i'},
          ),
        _ => AudioSource.file('${tempDirectory.path}/local-$i.mp3'),
      };
      await player.setAudioSource(source);
      if (previous != null) await player.releaseAudioSource(previous);
      previous = source;

      expect(player.debugAudioSourceRegistryCount, 2);
      expect(player.debugProxyHandlerCount, lessThanOrEqualTo(1));
    }

    await player.setAudioSources([], preload: false);
    await player.releaseAudioSource(previous!);
    expect(player.debugAudioSourceRegistryCount, 1);
    expect(player.debugProxyHandlerCount, 0);
  });

  test('release rejects a source that native playback may still use', () async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final source = AudioSource.file('${tempDirectory.path}/active.mp3');
    await player.setAudioSource(source);

    await expectLater(
      player.releaseAudioSource(source),
      throwsA(isA<StateError>()),
    );
  });

  test('releasing an old URI registration preserves a newer colliding source',
      () async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final uri = Uri.parse('https://example.invalid/same.mp3?signature=secret');
    final first = AudioSource.uri(uri, headers: const {'X-Source': 'first'});
    final second = AudioSource.uri(uri, headers: const {'X-Source': 'second'});

    await player.setAudioSource(first);
    await player.setAudioSource(second);
    expect(player.debugProxyHandlerCount, 2);

    await player.releaseAudioSource(first);
    expect(player.debugProxyHandlerCount, 1);

    await player.setAudioSources([], preload: false);
    await player.releaseAudioSource(second);
    expect(player.debugProxyHandlerCount, 0);
  });
  test('releasing an old graph preserves a child shared by the playlist',
      () async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final shared = AudioSource.uri(
      Uri.parse('https://example.invalid/shared.mp3'),
      headers: const {'X-Test': 'shared'},
    );
    final oldGraph = ConcatenatingAudioSource(
      children: [
        shared,
        AudioSource.file('${tempDirectory.path}/old.mp3'),
      ],
    );
    final currentGraph = ConcatenatingAudioSource(
      children: [
        shared,
        AudioSource.file('${tempDirectory.path}/current.mp3'),
      ],
    );

    await player.setAudioSource(oldGraph);
    await player.setAudioSource(currentGraph);
    await player.releaseAudioSource(oldGraph);

    expect(player.debugAudioSourceRegistryCount, 4);
    expect(player.debugProxyHandlerCount, 1);
    await expectLater(
      player.releaseAudioSource(shared),
      throwsA(isA<StateError>()),
    );

    await player.setAudioSources([], preload: false);
    await player.releaseAudioSource(currentGraph);
    expect(player.debugAudioSourceRegistryCount, 1);
    expect(player.debugProxyHandlerCount, 0);
  });

  test('dispose racing the first proxy load leaves no handlers', () async {
    for (var i = 0; i < 25; i++) {
      final player = AudioPlayer(handleAudioSessionActivation: false);
      final source = _ThrowingStreamAudioSource('race-$i');
      final load = player.setAudioSource(source).catchError((_) => null);
      await Future.wait<Object?>([load, player.dispose()]);
      expect(player.debugProxyHandlerCount, 0);
    }
  });

  test('HLS nested resources share an owner path and release together',
      () async {
    final requestedHeaders = <String, String?>{};
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    origin.listen((request) async {
      requestedHeaders[request.uri.path] = request.headers.value('x-test');
      if (request.uri.path == '/playlist/master.m3u8') {
        final manifest = '#EXTM3U\n'
            '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
            'segment.ts\n'
            'http://${origin.address.address}:${origin.port}/absolute.ts\n';
        request.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl');
        request.response.write(manifest);
      } else {
        request.response.add([1, 2, 3, 4]);
      }
      await request.response.close();
    });

    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final source = AudioSource.uri(
      Uri.parse(
        'http://${origin.address.address}:${origin.port}/playlist/master.m3u8',
      ),
      headers: const {'X-Test': 'manifest-token'},
    );
    late Uri proxyUri;

    await HttpOverrides.runZoned(
      () async {
        await player.setAudioSource(source);
        proxyUri = Uri.parse(
          (platform.player.lastLoad!.audioSourceMessage
                  as ConcatenatingAudioSourceMessage)
              .children
              .single
              .let((message) => (message as UriAudioSourceMessage).uri),
        );
        final client = HttpClient();
        try {
          final manifestResponse =
              await (await client.getUrl(proxyUri)).close();
          expect(manifestResponse.statusCode, HttpStatus.ok);
          final manifest =
              await manifestResponse.transform(systemEncoding.decoder).join();
          final nestedUris = RegExp(r'http://[^"\s]+')
              .allMatches(manifest)
              .map((match) => Uri.parse(match.group(0)!))
              .toList();
          expect(nestedUris, hasLength(3));
          final ownerPrefix = '/id/${proxyUri.pathSegments[1]}/';
          for (final nestedUri in nestedUris) {
            expect(nestedUri.path, startsWith(ownerPrefix));
            final response = await (await client.getUrl(nestedUri)).close();
            expect(response.statusCode, HttpStatus.ok);
            await response.drain<void>();
          }
        } finally {
          client.close(force: true);
        }
      },
      createHttpClient: _RealHttpOverrides().createHttpClient,
    );

    expect(requestedHeaders['/playlist/master.m3u8'], 'manifest-token');
    expect(requestedHeaders['/playlist/key.bin'], 'manifest-token');
    expect(requestedHeaders['/playlist/segment.ts'], 'manifest-token');
    expect(player.debugProxyHandlerCount, 4);
    await player.setAudioSources([], preload: false);
    await player.releaseAudioSource(source);
    expect(player.debugProxyHandlerCount, 0);
  });

  test('released HLS owner cannot register late manifest resources', () async {
    final originRequested = Completer<void>();
    final releaseOrigin = Completer<void>();
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    origin.listen((request) async {
      request.response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl');
      if (!originRequested.isCompleted) originRequested.complete();
      await releaseOrigin.future;
      request.response.write('#EXTM3U\nsegment.ts\n');
      await request.response.close();
    });

    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final source = AudioSource.uri(
      Uri.parse(
        'http://${origin.address.address}:${origin.port}/playlist/master.m3u8',
      ),
      headers: const {'Authorization': 'secret'},
    );

    await HttpOverrides.runZoned(
      () async {
        await player.setAudioSource(source);
        final proxyUri = Uri.parse(
          (platform.player.lastLoad!.audioSourceMessage
                  as ConcatenatingAudioSourceMessage)
              .children
              .single
              .let((message) => (message as UriAudioSourceMessage).uri),
        );
        final client = HttpClient();
        try {
          final responseFuture = client
              .getUrl(proxyUri)
              .then((request) => request.close())
              .then((response) => response.drain<void>());
          await originRequested.future;
          await player.setAudioSources([], preload: false);
          await player.releaseAudioSource(source);
          expect(player.debugProxyHandlerCount, 0);
          releaseOrigin.complete();
          await responseFuture.catchError((_) {});
          await Future<void>.delayed(Duration.zero);
          expect(player.debugProxyHandlerCount, 0);
        } finally {
          client.close(force: true);
        }
      },
      createHttpClient: _RealHttpOverrides().createHttpClient,
    );
  });

  test('proxy source errors do not print exception, URL, query, or file path',
      () async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final source = _ThrowingStreamAudioSource(
      'https://signed.invalid/audio?token=secret-token '
      '${tempDirectory.path}/private.part',
    );
    await player.setAudioSource(source);
    final proxyUri = Uri.parse(
      (platform.player.lastLoad!.audioSourceMessage
              as ConcatenatingAudioSourceMessage)
          .children
          .single
          .let((message) => (message as ProgressiveAudioSourceMessage).uri),
    );
    final printed = <String>[];

    final realHttpOverrides = _RealHttpOverrides();
    await HttpOverrides.runZoned(
      () => runZoned(
        () async {
          final client = HttpClient();
          try {
            final response = await (await client.getUrl(proxyUri)).close();
            expect(response.statusCode, HttpStatus.internalServerError);
            await response.drain<void>();
          } finally {
            client.close(force: true);
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ),
      ),
      createHttpClient: realHttpOverrides.createHttpClient,
    );

    expect(printed, isEmpty);
    await player.setAudioSources([], preload: false);
    await player.releaseAudioSource(source);
    expect(player.debugProxyHandlerCount, 0);
  });
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}

class _RealHttpOverrides extends HttpOverrides {}

class _ThrowingStreamAudioSource extends StreamAudioSource {
  final String sensitiveDetails;

  _ThrowingStreamAudioSource(this.sensitiveDetails);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    throw Exception(sensitiveDetails);
  }
}

class _ReleaseTestJustAudioPlatform extends JustAudioPlatform {
  late final _ReleaseTestAudioPlayer player;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    player = _ReleaseTestAudioPlayer(request.id);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await player.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

class _ReleaseTestAudioPlayer extends AudioPlayerPlatform {
  _ReleaseTestAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _playGate = Completer<void>();
  LoadRequest? lastLoad;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<VisualizerWaveformCaptureMessage> get visualizerWaveformStream =>
      const Stream<VisualizerWaveformCaptureMessage>.empty();

  @override
  Stream<VisualizerFftCaptureMessage> get visualizerFftStream =>
      const Stream<VisualizerFftCaptureMessage>.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    lastLoad = request;
    _events.add(_event(ProcessingStateMessage.loading));
    _events.add(_event(ProcessingStateMessage.ready));
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  PlaybackEventMessage _event(ProcessingStateMessage state) =>
      PlaybackEventMessage(
        processingState: state,
        updatePosition: Duration.zero,
        updateTime: DateTime.now(),
        bufferedPosition: Duration.zero,
        duration: const Duration(minutes: 3),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      );

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    await _playGate.future;
    return PlayResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async =>
      SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async =>
          SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async =>
      ConcatenatingRemoveRangeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    if (!_playGate.isCompleted) _playGate.complete();
    await _events.close();
    return DisposeResponse();
  }
}
