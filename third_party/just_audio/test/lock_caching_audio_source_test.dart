import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  late Directory tempDirectory;
  late _LoopbackOrigin origin;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('just_audio_cache_test');
    origin = await _LoopbackOrigin.start();
  });

  tearDown(() async {
    await origin.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
      'completes one full transfer and serves ranges during and after download',
      () async {
    final cacheFile = File('${tempDirectory.path}/success.wav');
    final source = LockCachingAudioSource(
      origin.uri('/slow'),
      cacheFile: cacheFile,
    );

    final initialResponse = await source.request(0, 8192).timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError(
            'initial request did not resolve; '
            'firstChunk=${origin.firstSlowChunk.isCompleted}, '
            'resources=${source.debugActiveResourceCount}, '
            'bytes=${source.debugDownloadedBytes}, '
            'state=${source.downloadState}',
          ),
        );
    final initialBytes =
        initialResponse.stream.expand((chunk) => chunk).toList();
    await origin.firstSlowChunk.future;

    final futureRange = source.request(32000, 33000);
    while (source.debugPendingRequestCount == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    origin.releaseSlowResponse();
    final rangeResponse = await futureRange.timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('future range did not resolve'),
    );
    final rangeBytes =
        await rangeResponse.stream.expand((chunk) => chunk).toList().timeout(
              const Duration(seconds: 3),
              onTimeout: () => throw StateError('range stream did not close'),
            );
    final completed = await source.completedFile.timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('completedFile did not resolve'),
    );

    expect(await initialBytes, origin.bytes.sublist(0, 8192));
    expect(rangeBytes, origin.bytes.sublist(32000, 33000));
    expect(await completed.readAsBytes(), origin.bytes);
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
    expect(origin.fullRequests, 1);
    expect(origin.rangeRequests, 1);

    final completedRange = await source.request(1000, 2000);
    expect(
      await completedRange.stream.expand((chunk) => chunk).toList(),
      origin.bytes.sublist(1000, 2000),
    );
    expect(origin.fullRequests, 1);
  });
  test('rejects a 206 response for the wrong byte range', () async {
    final cacheFile = File('${tempDirectory.path}/bad-range.wav');
    final source = LockCachingAudioSource(
      origin.uri('/bad-range'),
      cacheFile: cacheFile,
    );
    final initial = await source.request(0, 4096);
    await initial.stream.drain<void>();
    await origin.firstSlowChunk.future;

    final response = source.request(32000, 33000);
    origin.releaseSlowResponse();
    await expectLater(
      response,
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.invalidHttpResponse,
        ),
      ),
    );
    await source.completedFile;
    expect(source.debugActiveResourceCount, 0);
  });

  test('reports a truncated 206 range stream', () async {
    final cacheFile = File('${tempDirectory.path}/short-range.wav');
    final source = LockCachingAudioSource(
      origin.uri('/short-range'),
      cacheFile: cacheFile,
    );
    final initial = await source.request(0, 4096);
    await initial.stream.drain<void>();
    await origin.firstSlowChunk.future;

    final responseFuture = source.request(32000, 33000);
    origin.releaseSlowResponse();
    final response = await responseFuture;
    await expectLater(
      response.stream.drain<void>(),
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.contentLength,
        ),
      ),
    );
    await source.completedFile;
    expect(source.debugActiveResourceCount, 0);
  });

  test('cache completion closes a paused auxiliary range transfer', () async {
    final cacheFile = File('${tempDirectory.path}/paused-range.wav');
    final source = LockCachingAudioSource(
      origin.uri('/slow'),
      cacheFile: cacheFile,
    );
    final initial = await source.request(0, 4096);
    await initial.stream.drain<void>();
    await origin.firstSlowChunk.future;

    final responseFuture = source.request(32000, 33000);
    origin.releaseSlowResponse();
    final response = await responseFuture;
    final subscription = response.stream.listen((_) {});
    subscription.pause();

    await source.completedFile.timeout(const Duration(seconds: 3));
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
    await subscription.cancel();
  });

  test('cache completion rejects an unfinished auxiliary range', () async {
    final cacheFile = File('${tempDirectory.path}/slow-range.wav');
    final source = LockCachingAudioSource(
      origin.uri('/slow-range'),
      cacheFile: cacheFile,
    );
    final initial = await source.request(0, 4096);
    await initial.stream.drain<void>();
    await origin.firstSlowChunk.future;

    final responseFuture = source.request(32000, 33000);
    origin.releaseSlowResponse();
    final response = await responseFuture.timeout(const Duration(seconds: 3));
    final rangeCompletion = response.stream.drain<void>();
    await origin.firstSlowRangeChunk.future;
    origin.releaseSlowMainCompletion();

    await source.completedFile.timeout(const Duration(seconds: 3));
    await expectLater(
      rangeCompletion,
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.contentLength,
        ),
      ),
    );
    origin.releaseSlowRangeResponse();
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
  });

  test('paused proxy consumer does not block cache publication', () async {
    final cacheFile = File('${tempDirectory.path}/paused.wav');
    final source = LockCachingAudioSource(
      origin.uri('/slow'),
      cacheFile: cacheFile,
    );

    final response = await source.request();
    final subscription = response.stream.listen((_) {});
    subscription.pause();
    await origin.firstSlowChunk.future;
    origin.releaseSlowResponse();

    final completed = await source.completedFile.timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('paused consumer blocked completion'),
    );
    expect(await completed.readAsBytes(), origin.bytes);
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
    await subscription.cancel();
  });

  test('accepts a complete 206 origin response', () async {
    final cacheFile = File('${tempDirectory.path}/full-206.wav');
    final source = LockCachingAudioSource(
      origin.uri('/full-206'),
      cacheFile: cacheFile,
    );
    final response = await source.request();
    expect(
        await response.stream.expand((chunk) => chunk).toList(), origin.bytes);

    final completed = await source.completedFile;
    expect(await completed.readAsBytes(), origin.bytes);
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
  });

  for (final path in ['/status', '/disconnect', '/truncate', '/chunked']) {
    test('$path fails without publishing files or leaking resources', () async {
      final cacheFile =
          File('${tempDirectory.path}${path.replaceAll('/', '_')}');
      final source = LockCachingAudioSource(
        origin.uri(path),
        cacheFile: cacheFile,
      );
      final completion = source.completedFile;

      try {
        final response = await source.request();
        await response.stream.drain<void>();
      } catch (_) {}

      await expectLater(
          completion, throwsA(isA<LockCachingAudioSourceException>()));
      expect(source.downloadState, LockCachingAudioSourceState.failed);
      expect(await cacheFile.exists(), isFalse);
      expect(await File('${cacheFile.path}.part').exists(), isFalse);
      expect(await File('${cacheFile.path}.mime').exists(), isFalse);
      expect(source.debugActiveResourceCount, 0);
    });
  }

  test('filesystem sink setup failure reaches failed terminal state', () async {
    final cacheFile = File('${tempDirectory.path}/sink-failure.wav');
    await Directory('${cacheFile.path}.part').create(recursive: true);
    final source = LockCachingAudioSource(
      origin.uri('/audio'),
      cacheFile: cacheFile,
    );
    final completion = source.completedFile;

    await expectLater(
        source.request(), throwsA(isA<LockCachingAudioSourceException>()));
    await expectLater(
      completion,
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.fileSystem,
        ),
      ),
    );
    expect(source.downloadState, LockCachingAudioSourceState.failed);
    expect(await cacheFile.exists(), isFalse);
    expect(source.debugActiveResourceCount, 0);
  });
  test('injected sink flush failure removes all cache artifacts', () async {
    final cacheFile = File('${tempDirectory.path}/sink-flush-failure.wav');
    final source = LockCachingAudioSource(
      origin.uri('/audio'),
      cacheFile: cacheFile,
      sinkFactory: (_) => IOSink(_FailingStreamConsumer()),
    );
    final completion = source.completedFile;

    await expectLater(
      source.request(),
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.fileSystem,
        ),
      ),
    );
    await expectLater(
      completion,
      throwsA(isA<LockCachingAudioSourceException>()),
    );
    expect(source.downloadState, LockCachingAudioSourceState.failed);
    expect(await cacheFile.exists(), isFalse);
    expect(await File('${cacheFile.path}.part').exists(), isFalse);
    expect(await File('${cacheFile.path}.mime').exists(), isFalse);
    expect(source.debugActiveResourceCount, 0);
  });

  test('clear racing the first request is serialized before startup', () async {
    final cacheFile = File('${tempDirectory.path}/clear-start.wav');
    await File('${cacheFile.path}.part').writeAsBytes([1, 2, 3]);
    await File('${cacheFile.path}.mime').writeAsString('stale/type');
    final source = LockCachingAudioSource(
      origin.uri('/audio'),
      cacheFile: cacheFile,
    );

    final clear = source.clearCache();
    final responseFuture = source.request();
    await clear;
    final response = await responseFuture;
    await response.stream.drain<void>();
    final completed = await source.completedFile;

    expect(await completed.readAsBytes(), origin.bytes);
    expect(source.downloadState, LockCachingAudioSourceState.completed);
    expect(source.debugActiveResourceCount, 0);
  });

  test('cancel during startup cannot create resources after cleanup', () async {
    final cacheFile = File('${tempDirectory.path}/cancel-start.wav');
    late LockCachingAudioSource source;
    source = LockCachingAudioSource(
      origin.uri('/audio'),
      cacheFile: cacheFile,
      sinkFactory: (partialFile) {
        scheduleMicrotask(() => unawaited(source.cancelDownload()));
        return partialFile.openWrite();
      },
    );
    final completion = source.completedFile;

    await expectLater(
      source.request(),
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.cancelled,
        ),
      ),
    );
    await expectLater(
      completion,
      throwsA(isA<LockCachingAudioSourceException>()),
    );
    expect(source.downloadState, LockCachingAudioSourceState.cancelled);
    expect(await cacheFile.exists(), isFalse);
    expect(await File('${cacheFile.path}.part').exists(), isFalse);
    expect(await File('${cacheFile.path}.mime').exists(), isFalse);
    expect(source.debugActiveResourceCount, 0);
  });

  test('cancel is idempotent and removes staging resources', () async {
    final cacheFile = File('${tempDirectory.path}/cancel.wav');
    final source = LockCachingAudioSource(
      origin.uri('/slow'),
      cacheFile: cacheFile,
    );
    final completion = source.completedFile;
    final response = await source.request();
    final responseDone = response.stream.drain<void>().catchError((_) {});
    await origin.firstSlowChunk.future;

    await Future.wait([
      source.cancelDownload(),
      source.cancelDownload(),
      source.clearCache(),
    ]);
    origin.releaseSlowResponse();
    await responseDone;

    await expectLater(
      completion,
      throwsA(
        isA<LockCachingAudioSourceException>().having(
          (error) => error.failure,
          'failure',
          LockCachingAudioSourceFailure.cancelled,
        ),
      ),
    );
    expect(source.downloadState, LockCachingAudioSourceState.cancelled);
    expect(await cacheFile.exists(), isFalse);
    expect(await File('${cacheFile.path}.part').exists(), isFalse);
    expect(await File('${cacheFile.path}.mime').exists(), isFalse);
    expect(source.debugActiveResourceCount, 0);
  });

  test('completion and cancellation produce exactly one terminal result',
      () async {
    for (var i = 0; i < 20; i++) {
      final cacheFile = File('${tempDirectory.path}/race-$i.wav');
      final source = LockCachingAudioSource(
        origin.uri('/audio'),
        cacheFile: cacheFile,
      );
      final completion = source.completedFile.then<Object>(
        (file) => file,
        onError: (Object error, StackTrace _) => error,
      );
      final response = await source.request();
      final drain = response.stream.drain<void>().catchError((_) {});

      await source.cancelDownload();
      await drain;
      final result = await completion;

      expect(
        source.downloadState,
        anyOf(
          LockCachingAudioSourceState.completed,
          LockCachingAudioSourceState.cancelled,
        ),
      );
      if (source.downloadState == LockCachingAudioSourceState.completed) {
        expect(result, isA<File>());
        expect(await cacheFile.exists(), isTrue);
      } else {
        expect(result, isA<LockCachingAudioSourceException>());
        expect(await cacheFile.exists(), isFalse);
      }
      expect(source.debugActiveResourceCount, 0);
    }
  });

  test('failures never expose URL query, token, or cache path', () async {
    final cacheFile = File('${tempDirectory.path}/private-cache-path.wav');
    final source = LockCachingAudioSource(
      origin.uri('/status?token=secret-token'),
      headers: const {'Authorization': 'Bearer secret-token'},
      cacheFile: cacheFile,
    );

    final completion = source.completedFile;
    try {
      await source.request();
    } catch (_) {}
    Object? error;
    try {
      await completion;
    } catch (caught) {
      error = caught;
    }

    final text = '$error';
    expect(text, isNot(contains('secret-token')));
    expect(text, isNot(contains('token=')));
    expect(text, isNot(contains(cacheFile.path)));
    expect(text, isNot(contains(origin.server.address.address)));
  });
}

class _LoopbackOrigin {
  final HttpServer server;
  final List<int> bytes;
  final firstSlowChunk = Completer<void>();
  final firstSlowRangeChunk = Completer<void>();
  final _slowGate = Completer<void>();
  final _slowMainCompletionGate = Completer<void>();
  final _slowRangeGate = Completer<void>();
  int fullRequests = 0;
  int rangeRequests = 0;

  _LoopbackOrigin._(this.server, this.bytes);

  static Future<_LoopbackOrigin> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bytes = List<int>.generate(65536, (index) => index % 251);
    final origin = _LoopbackOrigin._(server, bytes);
    server.listen(origin._handle);
    return origin;
  }

  Uri uri(String path) => Uri.parse(
        'http://${server.address.address}:${server.port}$path',
      );

  void releaseSlowResponse() {
    if (!_slowGate.isCompleted) _slowGate.complete();
  }

  void releaseSlowMainCompletion() {
    if (!_slowMainCompletionGate.isCompleted) {
      _slowMainCompletionGate.complete();
    }
  }

  void releaseSlowRangeResponse() {
    if (!_slowRangeGate.isCompleted) _slowRangeGate.complete();
  }

  Future<void> close() async {
    releaseSlowResponse();
    releaseSlowMainCompletion();
    releaseSlowRangeResponse();
    await server.close(force: true);
  }

  Future<void> _writeTruncatedResponse(
    HttpRequest request,
    int byteCount, {
    bool abrupt = false,
  }) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.add(ascii.encode(
      'HTTP/1.1 200 OK\r\n'
      'Content-Type: audio/wav\r\n'
      'Content-Length: ${bytes.length}\r\n'
      'Connection: close\r\n\r\n',
    ));
    socket.add(bytes.sublist(0, byteCount));
    await socket.flush();
    if (abrupt) {
      socket.destroy();
    } else {
      await socket.close();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/status') {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    if (request.uri.path == '/disconnect') {
      fullRequests++;
      await _writeTruncatedResponse(request, 4096, abrupt: true);
      return;
    }
    if (request.uri.path == '/truncate') {
      fullRequests++;
      await _writeTruncatedResponse(request, bytes.length ~/ 2);
      return;
    }
    if (request.uri.path == '/chunked') {
      fullRequests++;
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.add(bytes.sublist(0, bytes.length ~/ 2));
      await request.response.close();
      return;
    }
    if (request.uri.path == '/full-206') {
      fullRequests++;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes 0-${bytes.length - 1}/${bytes.length}',
      );
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
      return;
    }

    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      rangeRequests++;
      final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range)!;
      final start = int.parse(match.group(1)!);
      final endExclusive = match.group(2)!.isEmpty
          ? bytes.length
          : int.parse(match.group(2)!) + 1;
      final body = bytes.sublist(start, endExclusive);
      if (request.uri.path == '/short-range') {
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.add(ascii.encode(
          'HTTP/1.1 206 Partial Content\r\n'
          'Content-Type: audio/wav\r\n'
          'Content-Range: bytes $start-${endExclusive - 1}/${bytes.length}\r\n'
          'Content-Length: ${body.length}\r\n'
          'Connection: close\r\n\r\n',
        ));
        socket.add(body.sublist(0, body.length ~/ 2));
        await socket.flush();
        await socket.close();
        return;
      }
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        request.uri.path == '/bad-range'
            ? 'bytes ${start + 1}-${endExclusive - 1}/${bytes.length}'
            : 'bytes $start-${endExclusive - 1}/${bytes.length}',
      );
      request.response.contentLength = body.length;
      if (request.uri.path == '/slow-range') {
        request.response.bufferOutput = false;
        const firstChunkLength = 64;
        request.response.add(body.sublist(0, firstChunkLength));
        await request.response.flush();
        if (!firstSlowRangeChunk.isCompleted) {
          firstSlowRangeChunk.complete();
        }
        await _slowRangeGate.future;
        try {
          request.response.add(body.sublist(firstChunkLength));
          await request.response.close();
        } on HttpException {
          // The cache completion test intentionally closes this range early.
        } on SocketException {
          // The cache completion test intentionally closes this range early.
        }
        return;
      }
      request.response.add(body);
      await request.response.close();
      return;
    }

    fullRequests++;
    request.response.headers.contentType = ContentType('audio', 'wav');
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.contentLength = bytes.length;
    if ({'/slow', '/slow-range', '/bad-range', '/short-range'}
        .contains(request.uri.path)) {
      request.response.bufferOutput = false;
      request.response.add(bytes.sublist(0, 4096));
      await request.response.flush();
      if (!firstSlowChunk.isCompleted) firstSlowChunk.complete();
      await _slowGate.future;
      for (var offset = 4096; offset < bytes.length; offset += 4096) {
        final end = (offset + 4096).clamp(0, bytes.length);
        request.response.add(bytes.sublist(offset, end));
        await request.response.flush();
        if (request.uri.path == '/slow-range' && offset == 4096) {
          await _slowMainCompletionGate.future;
        }
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    } else {
      request.response.add(bytes);
    }
    await request.response.close();
  }
}

class _FailingStreamConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {
      throw const FileSystemException('injected sink failure');
    }
  }

  @override
  Future<void> close() async {}
}
