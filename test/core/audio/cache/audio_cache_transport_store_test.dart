// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:just_audio/just_audio.dart';

import 'cache_test_support.dart';

void main() {
  for (final mode in [
    'success',
    'format',
    'mime',
    'http-error',
    'truncated',
    'disconnect',
    'sink',
    'cancel',
  ]) {
    test('vendor terminal feeds store safely for $mode', () async {
      final directory = await Directory.systemTemp.createTemp(
        'audio-cache-terminal-',
      );
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final store = FileAudioCacheStore(
        capacity: FakeCapacity(),
        applicationCacheDirectory: () async => directory,
      );
      final runtime = AudioCacheRuntime(store: store, capabilityEnabled: true);
      final requests = <Future<void>>[];
      final firstChunk = Completer<void>();
      final finishOrigin = Completer<void>();
      origin.listen((request) {
        requests.add(() async {
          try {
            if (mode == 'http-error') {
              request.response.statusCode = 404;
              await request.response.close();
              return;
            }
            if (mode == 'truncated' || mode == 'disconnect') {
              final socket = await request.response.detachSocket(
                writeHeaders: false,
              );
              socket.add(
                ascii.encode(
                  'HTTP/1.1 200 OK\r\n'
                  'Content-Type: audio/mpeg\r\nContent-Length: 10\r\n'
                  'Connection: close\r\n\r\n',
                ),
              );
              socket.add([1, 2]);
              await socket.flush();
              if (mode == 'disconnect') {
                socket.destroy();
              } else {
                await socket.close();
              }
              return;
            }
            request.response.bufferOutput = false;
            request.response.headers.contentType = ContentType(
              'audio',
              mode == 'mime' || mode == 'format' ? 'flac' : 'mpeg',
            );
            request.response.contentLength = 10;
            request.response.add([1, 2]);
            await request.response.flush();
            firstChunk.complete();
            if (mode == 'cancel') {
              await finishOrigin.future;
              // The client has already closed this connection. The server's
              // forced shutdown owns it, not a new response-close Future.
              return;
            }
            request.response.add(List.filled(8, 1));
            await request.response.close();
          } catch (_) {
            /* Intentional client cancellation or truncation. */
          }
        }());
      });
      final lease = (await admit(
        store,
        format: mode == 'format' ? 'flac' : 'mp3',
      ))!;
      final source = LockCachingAudioSource(
        Uri.parse('http://127.0.0.1:${origin.port}/audio?token=secret-fixture'),
        cacheFile: File(lease.path),
        sinkFactory: mode == 'sink'
            ? (_) => throw const FileSystemException('injected')
            : null,
      );
      try {
        final terminal = runtime.observeWriteCompletion(
          lease,
          source.completedFile,
        );
        final read = () async {
          try {
            await (await source.request()).stream.drain<void>();
          } catch (_) {
            /* Both consumers explicitly observe the failing terminal. */
          }
        }();
        if (mode == 'cancel') {
          await firstChunk.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                throw StateError('Origin first chunk did not flush'),
          );
          await source.cancelDownload().timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                throw StateError('Transport cancellation did not settle'),
          );
          finishOrigin.complete();
        }
        final publication = await terminal.timeout(const Duration(seconds: 3));
        await read.timeout(const Duration(seconds: 3));
        expect(
          publication,
          mode == 'success'
              ? AudioCachePublication.published
              : AudioCachePublication.rejected,
        );
        expect(store.snapshot.entryCount, mode == 'success' ? 1 : 0);
        expect(source.debugActiveResourceCount, 0);
        if (mode != 'success' && mode != 'format' && mode != 'mime') {
          expect(await File(lease.path).exists(), isFalse);
          expect(await File('${lease.path}.part').exists(), isFalse);
          expect(await File('${lease.path}.mime').exists(), isFalse);
        }
        expect(store.readHealth, AudioCacheReadHealth.ready);
        expect(store.writeHealth, AudioCacheWriteHealth.ready);
      } finally {
        if (!finishOrigin.isCompleted) finishOrigin.complete();
        await source.cancelDownload().timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('Final transport cancel timed out'),
        );
        await lease.dispose().timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('Data lease release timed out'),
        );
        await store.dispose().timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('Store release timed out'),
        );
        await origin.close(force: true);
        await Future.wait(requests).timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('Origin handlers did not close'),
        );
        await directory.delete(recursive: true);
      }
    });
  }
}
