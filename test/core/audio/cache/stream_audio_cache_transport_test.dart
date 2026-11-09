// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  late Directory directory;
  final caches = <LockCachingAudioSource>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('direct_stream_cache_');
  });
  tearDown(() async {
    for (final cache in caches) {
      await cache.cancelDownload();
    }
    caches.clear();
    await directory.delete(recursive: true);
  });

  LockCachingAudioSource create(StreamAudioSource upstream) {
    final cache = LockCachingAudioSource(
      Uri.parse('https://must-not-be-requested.invalid/audio.mp3'),
      cacheFile: File('${directory.path}/audio-${caches.length}.mp3'),
      streamSource: upstream,
    );
    caches.add(cache);
    return cache;
  }

  test(
    'future seek reads the upstream source directly while full cache is pending',
    () async {
      final bytes = List.generate(100, (index) => index);
      final initial = StreamController<List<int>>();
      addTearDown(() => initial.close());
      final requests = <(int?, int?)>[];
      final cache = create(
        _Source((start, end) async {
          requests.add((start, end));
          return StreamAudioResponse(
            sourceLength: bytes.length,
            contentLength: end == null ? bytes.length : end - start!,
            offset: start,
            contentType: 'audio/mpeg',
            stream: start == null
                ? initial.stream
                : Stream.value(bytes.sublist(start, end)),
          );
        }),
      );
      final first = cache.request(0, 4);
      initial.add(bytes.sublist(0, 4));
      expect(await _bytes(await first), bytes.sublist(0, 4));
      final seeking = cache.request(80, 85);
      await _until(() => cache.debugPendingRequestCount > 0);
      initial.add(bytes.sublist(4, 8));
      final seek = await seeking;
      expect(await _bytes(seek), bytes.sublist(80, 85));
      expect(requests, [(null, null), (80, 85)]);
      initial.add(bytes.sublist(8));
      await initial.close();
      final file = await cache.completedFile;
      expect(await file.readAsBytes(), bytes);
      expect(await _bytes(await cache.request(30, 35)), bytes.sublist(30, 35));
      expect(requests, hasLength(2));
      expect(cache.debugActiveResourceCount, 0);
    },
  );

  test('cancel closes an auxiliary response that was never consumed', () async {
    var rangeCancelled = false;
    final initial = StreamController<List<int>>();
    final auxiliary = StreamController<List<int>>(
      onCancel: () => rangeCancelled = true,
    );
    addTearDown(() => initial.close());
    addTearDown(() => auxiliary.close());
    final cache = create(
      _Source(
        (start, end) async => StreamAudioResponse(
          sourceLength: 100,
          contentLength: start == null ? 100 : end! - start,
          offset: start,
          contentType: 'audio/mpeg',
          stream: start == null ? initial.stream : auxiliary.stream,
        ),
      ),
    );
    final first = cache.request(0, 4);
    initial.add([1, 2, 3, 4]);
    await (await first).stream.drain<void>();
    final seeking = cache.request(80, 85);
    await _until(() => cache.debugPendingRequestCount > 0);
    initial.add([5, 6]);
    final seek = await seeking;
    final terminal = expectLater(
      cache.completedFile,
      throwsA(isA<LockCachingAudioSourceException>()),
    );
    await cache.cancelDownload();
    expect(rangeCancelled, isTrue);
    await expectLater(
      seek.stream.drain<void>(),
      throwsA(isA<LockCachingAudioSourceException>()),
    );
    await terminal;
    expect(cache.debugActiveResourceCount, 0);
  });

  test(
    'cancellation during request cancels the late source response',
    () async {
      final started = Completer<void>();
      final ready = Completer<StreamAudioResponse>();
      var cancelled = false;
      final bytes = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      addTearDown(() => bytes.close());
      final cache = create(
        _Source((start, end) {
          started.complete();
          return ready.future;
        }),
      );
      final terminal = expectLater(
        cache.completedFile,
        throwsA(isA<LockCachingAudioSourceException>()),
      );
      final pending = expectLater(
        cache.request(),
        throwsA(isA<LockCachingAudioSourceException>()),
      );
      await started.future;
      await cache.cancelDownload();
      ready.complete(
        StreamAudioResponse(
          sourceLength: 4,
          contentLength: 4,
          offset: null,
          contentType: 'audio/mpeg',
          stream: bytes.stream,
        ),
      );
      await pending;
      await terminal;
      await _until(() => cancelled);
      expect(cache.debugActiveResourceCount, 0);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  for (final mode in ['length', 'offset', 'total', 'truncated']) {
    test('invalid direct stream $mode is never published', () async {
      var cancelled = false;
      final bytes = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      addTearDown(() => bytes.close());
      final cache = create(
        _Source(
          (start, end) async => StreamAudioResponse(
            sourceLength: mode == 'total' ? 10 : 4,
            contentLength: mode == 'length' ? null : 4,
            offset: mode == 'offset' ? 1 : null,
            contentType: 'audio/mpeg',
            stream: bytes.stream,
          ),
        ),
      );
      final terminal = expectLater(
        cache.completedFile,
        throwsA(isA<LockCachingAudioSourceException>()),
      );
      final pending = () async {
        try {
          await (await cache.request()).stream.drain<void>();
        } catch (_) {
          // Both source and terminal futures intentionally observe failure.
        }
      }();
      if (mode == 'truncated') {
        bytes.add([1, 2]);
        await bytes.close();
      }
      await terminal;
      await pending;
      expect(cancelled, isTrue);
      expect(await (await cache.cacheFile).exists(), isFalse);
      expect(cache.debugActiveResourceCount, 0);
    });
  }
}

Future<List<int>> _bytes(StreamAudioResponse response) =>
    response.stream.fold<List<int>>([], (all, chunk) => all..addAll(chunk));

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Cancellation did not settle');
    }
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Source extends StreamAudioSource {
  _Source(this.read);
  final Future<StreamAudioResponse> Function(int?, int?) read;
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) =>
      read(start, end);
}
