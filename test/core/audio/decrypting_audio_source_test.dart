// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/decrypting_audio_source.dart';
import 'package:just_audio/just_audio.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'native_audio_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer origin;
  late Directory temporary;
  late List<int> plaintext;
  late List<int> encrypted;
  late bool ignoreRange;
  late int fetches;
  late String? userAgent;
  late HttpOverrides? previousHttpOverrides;
  late Completer<void> finishSlowOrigin;
  final sources = <DecryptingAudioSource>[];

  setUp(() async {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _RealHttpOverrides();
    temporary = await Directory.systemTemp.createTemp('audio_stream_test_');
    plaintext = List.generate(150003, (index) => index % 251);
    encrypted = List.generate(
      plaintext.length,
      (index) => (plaintext[index] + [3, 7, 11][index % 3]) & 255,
    );
    ignoreRange = false;
    fetches = 0;
    finishSlowOrigin = Completer<void>();
    origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen((request) async {
      try {
        fetches++;
        userAgent = request.headers.value(HttpHeaders.userAgentHeader);
        final response = request.response;
        response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        final rawRange = request.headers.value(HttpHeaders.rangeHeader);
        if (request.uri.path == '/slow') {
          response.contentLength = encrypted.length;
          response.bufferOutput = false;
          response.add(encrypted.sublist(0, 4096));
          await response.flush();
          await finishSlowOrigin.future;
          response.add(encrypted.sublist(4096));
          await response.close();
          return;
        }
        if (request.uri.path == '/bad') {
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(HttpHeaders.contentRangeHeader, 'bytes invalid');
          response.contentLength = 1;
          response.add([0]);
        } else if (request.uri.path == '/truncated') {
          final socket = await response.detachSocket(writeHeaders: false);
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: 20\r\nConnection: close\r\n\r\n',
            ),
          );
          socket.add([1, 2]);
          await socket.flush();
          await socket.close();
          return;
        } else if (rawRange != null && !ignoreRange) {
          final parts = rawRange.substring(6).split('-');
          final start = int.parse(parts[0]);
          final end = parts[1].isEmpty
              ? encrypted.length
              : int.parse(parts[1]) + 1;
          if (start >= encrypted.length) {
            response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          } else {
            response.statusCode = HttpStatus.partialContent;
            response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-${end - 1}/${encrypted.length}',
            );
            response.contentLength = end - start;
            response.add(encrypted.sublist(start, end));
          }
        } else {
          response.contentLength = encrypted.length;
          for (var offset = 0; offset < encrypted.length; offset += 777) {
            response.add(
              encrypted.sublist(
                offset,
                (offset + 777).clamp(0, encrypted.length),
              ),
            );
          }
        }
        await response.close();
      } catch (_) {
        // A cancellation test deliberately closes the CDN connection early.
      }
    });
  });

  tearDown(() async {
    if (!finishSlowOrigin.isCompleted) finishSlowOrigin.complete();
    for (final source in sources) {
      await source.dispose();
    }
    sources.clear();
    await origin.close(force: true);
    if (await temporary.exists()) await temporary.delete(recursive: true);
    HttpOverrides.global = previousHttpOverrides;
  });

  DecryptingAudioSource create({
    String path = '/audio',
    String? parameters,
    String format = 'mp3',
  }) {
    final source = DecryptingAudioSource(
      url: 'http://127.0.0.1:${origin.port}$path',
      audioParams: parameters ?? _parameters(),
      format: format,
      temporaryDirectory: temporary,
    );
    sources.add(source);
    return source;
  }

  test('is a StreamAudioSource and fetches CDN only when requested', () async {
    final source = create();
    expect(source, isA<StreamAudioSource>());
    expect(fetches, 0);
    final response = await source.request();
    expect(response.sourceLength, plaintext.length);
    expect(response.contentLength, plaintext.length);
    expect(response.offset, isNull);
    expect(response.contentType, 'audio/mpeg');
    expect(await _bytes(response), plaintext);
    expect(userAgent, 'test-audio-agent');
    expect(await temporary.list().toList(), isEmpty);
  });

  test(
    'nonzero request decrypts actual upstream offsets and exclusive end',
    () async {
      final response = await create().request(65531, 131080);
      expect(response.offset, 65531);
      expect(response.contentLength, 131080 - 65531);
      expect(response.sourceLength, plaintext.length);
      expect(await _bytes(response), plaintext.sublist(65531, 131080));
    },
  );

  test(
    'first plaintext bytes arrive before the aggregation buffer fills',
    () async {
      final response = await create(path: '/slow').request();
      final first = await response.stream.first.timeout(
        const Duration(seconds: 2),
      );
      expect(first, isNotEmpty);
      expect(first, plaintext.sublist(0, first.length));
      expect(first.length, lessThanOrEqualTo(4096));
      expect(finishSlowOrigin.isCompleted, isFalse);
    },
  );
  test(
    'zero-based native range request retains offset and total length',
    () async {
      final response = await create().request(0, 42);
      expect(response.offset, 0);
      expect(await _bytes(response), plaintext.sublist(0, 42));
    },
  );

  test(
    'ignored Range returns full plaintext with no partial response offset',
    () async {
      ignoreRange = true;
      final response = await create().request(70001);
      expect(response.rangeRequestsSupported, isFalse);
      expect(response.offset, isNull);
      expect(response.contentLength, plaintext.length);
      expect(await _bytes(response), plaintext);
    },
  );

  test('invalid ranges fail before making a CDN request', () async {
    final source = create();
    for (final (start, end) in [(-1, 2), (4, 4), (4, 3), (1 << 41, null)]) {
      await expectLater(source.request(start, end), throwsFormatException);
    }
    expect(fetches, 0);
  });

  test(
    'invalid upstream metadata fails without leaking source details',
    () async {
      await expectLater(create(path: '/bad').request(), throwsFormatException);
    },
  );

  test('truncated CDN body fails the returned stream', () async {
    final response = await create(path: '/truncated').request();
    await expectLater(_bytes(response), throwsFormatException);
  });

  test(
    'released source rejects reads while another source remains usable',
    () async {
      final old = create();
      final active = create();
      await old.dispose();
      await old.dispose();
      await expectLater(old.request(), throwsStateError);
      expect(fetches, 0);
      expect(await _bytes(await active.request()), plaintext);
    },
  );

  test(
    'dispose releases responses returned without any stream subscription',
    () async {
      final source = create();
      final response = await source.request();
      await source.dispose();
      await expectLater(_bytes(response), throwsFormatException);
    },
  );

  test(
    'stream cancellation releases a request slot and leaves source usable',
    () async {
      final source = create();
      for (var i = 0; i < 6; i++) {
        final response = await source.request();
        await response.stream.listen((_) {}).cancel();
      }
      expect(
        await _bytes(await source.request(9, 21)),
        plaintext.sublist(9, 21),
      );
    },
  );

  test(
    'concurrent sample requests share one decoded file and cleanup',
    () async {
      final vector = _sampleVector();
      encrypted = _hex(vector['input'] as String);
      final expected = _hex(vector['output'] as String);
      final source = create(
        parameters: vector['parameters'] as String,
        format: 'm4a',
      );
      final responses = await Future.wait([
        source.request(0, 32),
        source.request(expected.length - 23),
      ]);
      expect(await _bytes(responses[0]), expected.sublist(0, 32));
      expect(
        await _bytes(responses[1]),
        expected.sublist(expected.length - 23),
      );
      expect(fetches, 1);
      final files = await temporary
          .list(recursive: true)
          .where((entry) => entry is File)
          .toList();
      expect(files, hasLength(1));
      expect(files.single.path, endsWith('audio.m4a'));
      await source.dispose();
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test('sample decoding failure never returns ciphertext', () async {
    final vector = _sampleVector();
    encrypted = utf8.encode('invalid encrypted MP4');
    final source = create(
      parameters: vector['parameters'] as String,
      format: 'm4a',
    );
    await expectLater(source.request(), throwsFormatException);
    await source.dispose();
    expect(await temporary.list().toList(), isEmpty);
  });

  for (final cacheEnabled in [false, true]) {
    test(
      'native source has one proxy registration with cache=$cacheEnabled',
      () async {
        final previous = JustAudioPlatform.instance;
        final platform = NativeAudioTestPlatform();
        JustAudioPlatform.instance = platform;
        const channel = MethodChannel('com.ryanheise.audio_session');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => null);
        final player = AudioPlayer(handleAudioSessionActivation: false);
        final client = HttpClient();
        final upstream = create();
        final AudioSource playback = cacheEnabled
            ? LockCachingAudioSource(
                Uri.parse('https://unused.invalid/audio'),
                cacheFile: File('${temporary.path}/native.mp3'),
                streamSource: upstream,
              )
            : upstream;
        try {
          await player.setAudioSource(playback);
          expect(player.debugProxyHandlerCount, 1);
          final message =
              (platform.current.lastLoad!.audioSourceMessage
                          as ConcatenatingAudioSourceMessage)
                      .children
                      .single
                  as ProgressiveAudioSourceMessage;
          final proxy = Uri.parse(message.uri);
          expect(proxy.host, '127.0.0.1');
          final request = await client.getUrl(proxy);
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
          final response = await request.close();
          final bytes = await response.fold<List<int>>(
            [],
            (all, chunk) => all..addAll(chunk),
          );
          expect(bytes, plaintext);
          expect(fetches, 1);
          expect(player.debugProxyHandlerCount, 1);
          if (playback is LockCachingAudioSource) {
            expect(
              await (await playback.completedFile).readAsBytes(),
              plaintext,
            );
          }
          await player.setAudioSources([], preload: false);
          await player.releaseAudioSource(playback);
          await upstream.dispose();
          expect(player.debugProxyHandlerCount, 0);
        } finally {
          client.close(force: true);
          await player.dispose();
          await upstream.dispose();
          JustAudioPlatform.instance = previous;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
      },
    );
  }
  for (final samples in [false, true]) {
    test(
      'caching source consumes plaintext directly for sample=$samples',
      () async {
        final vector = samples ? _sampleVector() : null;
        if (vector != null) encrypted = _hex(vector['input'] as String);
        final expected = vector == null
            ? plaintext
            : _hex(vector['output'] as String);
        final source = create(
          parameters: vector?['parameters'] as String?,
          format: samples ? 'm4a' : 'mp3',
        );
        final file = File(
          '${temporary.path}/cached.${samples ? 'm4a' : 'mp3'}',
        );
        final caching = LockCachingAudioSource(
          // This address is deliberately unusable: direct-source caching must
          // never make an HTTP request to its compatibility URI.
          Uri.parse('https://unused.invalid/audio'),
          streamSource: source,
          cacheFile: file,
        );
        try {
          expect(await _bytes(await caching.request()), expected);
          await caching.completedFile;
          expect(await file.readAsBytes(), expected);
          expect(fetches, 1);
        } finally {
          await caching.cancelDownload();
          await source.dispose();
        }
      },
    );
  }
}

class _RealHttpOverrides extends HttpOverrides {}

Future<List<int>> _bytes(StreamAudioResponse response) =>
    response.stream.fold<List<int>>([], (all, chunk) => all..addAll(chunk));

Map<String, dynamic> _sampleVector() =>
    (jsonDecode(
              File(
                'test/core/audio/decrypt/fixtures/go_vectors.json',
              ).readAsStringSync(),
            )
            as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (vector) => vector['ivSize'] == 16 && vector['subsamples'] == true,
        );

List<int> _hex(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];

String _parameters() => base64Url
    .encode(
      utf8.encode(
        jsonEncode({
          'v': 1,
          'kind': 1,
          'key': base64.encode([3, 7, 11]),
          'user_agent': 'test-audio-agent',
        }),
      ),
    )
    .replaceAll('=', '');
