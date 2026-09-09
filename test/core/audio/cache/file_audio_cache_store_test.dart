import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:path/path.dart' as p;

import 'cache_test_support.dart';

void main() {
  late Directory directory;
  late FakeCapacity capacity;
  late FileAudioCacheStore store;
  late DateTime now;
  final stores = <FileAudioCacheStore>[];

  FileAudioCacheStore create({
    int schema = 1,
    Future<void> Function(Directory)? deleteOldSchema,
    Duration timeout = const Duration(seconds: 1),
  }) {
    final result = FileAudioCacheStore(
      capacity: capacity,
      applicationCacheDirectory: () async => directory,
      clock: () => now,
      schema: schema,
      deleteOldSchema: deleteOldSchema,
      capacityTimeout: timeout,
    );
    stores.add(result);
    return result;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'audio-cache-store-test-',
    );
    capacity = FakeCapacity();
    now = DateTime.fromMillisecondsSinceEpoch(1000000);
    store = create();
    await store.initialize();
  });
  tearDown(() async {
    for (final value in stores) {
      await value.dispose();
    }
    stores.clear();
    await directory.delete(recursive: true);
  });

  test(
    'only atomic metadata publication survives restart and no TTL is applied',
    () async {
      final lease = (await admit(store))!;
      await File(lease.path).writeAsBytes(List.filled(10, 1));
      expect(await store.lookupAndPin(cacheKey()), isNull);
      expect(store.snapshot.publishedBytes, 0);
      expect(
        await store.completeWrite(lease, mimeType: 'audio/mpeg'),
        AudioCachePublication.published,
      );
      expect(lease.state, AudioCacheLeaseState.retainedData);
      expect(store.snapshot.publishedBytes, 10);
      expect(store.snapshot.managedFootprintBytes, 10);
      final metadata = File(
        p.join(
          directory.path,
          'he_music/audio/v1/entries/${cacheKey().digest}.json',
        ),
      );
      final json = jsonDecode(await metadata.readAsString()) as Map;
      expect(
        json.keys,
        unorderedEquals([
          'schema',
          'key',
          'file_name',
          'resolved_format',
          'actual_bytes',
          'completed_at_ms',
        ]),
      );
      expect(json['file_name'], p.basename(lease.path));
      await lease.dispose();
      await store.dispose();
      now = DateTime(2050);
      final restarted = create();
      final hit = (await restarted.lookupAndPin(cacheKey()))!;
      expect(hit.path, lease.path);
      expect(hit.state, AudioCacheLeaseState.pinnedData);
      expect(capacity.calls, 1);
      await hit.dispose();
    },
  );

  test(
    'repeated completion after published lease release never deletes indexed data',
    () async {
      final lease = await publish(store);
      await lease.dispose();
      expect(await store.completeWrite(lease), AudioCachePublication.published);
      expect(await File(lease.path).exists(), isTrue);
      final hit = (await store.lookupAndPin(cacheKey()))!;
      await store.completeWrite(lease);
      expect(await File(hit.path).exists(), isTrue);
      await hit.dispose();
    },
  );

  for (final order in [
    ['complete', 'abort', 'new'],
    ['complete', 'new', 'abort'],
    ['abort', 'complete', 'new'],
    ['abort', 'new', 'complete'],
    ['new', 'complete', 'abort'],
    ['new', 'abort', 'complete'],
  ]) {
    test(
      'same-key terminal and new admission permutation ${order.join('-')}',
      () async {
        final old = (await admit(store))!;
        await File(old.path).writeAsBytes(List.filled(10, 1));
        Future<AudioCacheSourceLease?>? next;
        final operations = <Future<Object?>>[];
        for (final operation in order) {
          switch (operation) {
            case 'complete':
              operations.add(store.completeWrite(old));
            case 'abort':
              operations.add(store.abort(old));
            case 'new':
              next = admit(store);
              operations.add(next);
          }
        }
        await Future.wait(operations);
        final newLease = await next;
        final cancellationWins =
            order.indexOf('abort') < order.indexOf('complete');
        final newAdmitted =
            cancellationWins && order.indexOf('abort') < order.indexOf('new');
        expect(newLease != null, newAdmitted);
        expect(
          old.state,
          cancellationWins
              ? AudioCacheLeaseState.cancelled
              : AudioCacheLeaseState.retainedData,
        );
        if (cancellationWins) {
          await File(old.path).writeAsBytes([9]);
          await store.completeWrite(old);
          expect(await File(old.path).exists(), isFalse);
        }
        if (newLease != null) {
          await File(newLease.path).writeAsBytes(List.filled(10, 2));
          expect(
            await store.completeWrite(newLease),
            AudioCachePublication.published,
          );
          await newLease.dispose();
        }
        await old.dispose();
      },
    );
  }

  test(
    'LRU evicts oldest unpinned entry and external deletion heals on lookup',
    () async {
      final first = await publish(
        store,
        key: cacheKey(track: 'first'),
        limit: 20,
      );
      await first.dispose();
      now = now.add(const Duration(seconds: 1));
      final second = await publish(
        store,
        key: cacheKey(track: 'second'),
        limit: 20,
      );
      await second.dispose();
      final third = (await admit(
        store,
        key: cacheKey(track: 'third'),
        limit: 20,
      ))!;
      expect(await File(first.path).exists(), isFalse);
      expect(await File(second.path).exists(), isTrue);
      await third.dispose();
      await File(second.path).delete();
      expect(await store.lookupAndPin(second.key), isNull);
      expect(store.snapshot.publishedBytes, 0);
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  test(
    'clear preserves downloaded, lyric, and local library files outside its root',
    () async {
      final downloads = Directory(p.join(directory.path, 'Downloads'));
      await downloads.create();
      for (final name in ['song.mp3', 'song.lrc', 'local.db']) {
        await File(p.join(downloads.path, name)).writeAsString('user-owned');
      }
      final cached = await publish(store);
      await cached.dispose();
      await store.clear();
      for (final item in await downloads.list().toList()) {
        expect(await File(item.path).readAsString(), 'user-owned');
      }
    },
  );

  for (final mismatch in ['format', 'mime', 'oversized']) {
    test(
      '$mismatch completion retains current data but never publishes',
      () async {
        final lease = (await admit(
          store,
          format: mismatch == 'format' ? 'flac' : 'mp3',
          limit: 20,
        ))!;
        await File(
          lease.path,
        ).writeAsBytes(List.filled(mismatch == 'oversized' ? 30 : 10, 1));
        final publication = await store.completeWrite(
          lease,
          mimeType: mismatch == 'mime'
              ? 'audio/flac'
              : 'application/octet-stream',
        );
        expect(publication, AudioCachePublication.rejected);
        expect(lease.state, AudioCacheLeaseState.retainedData);
        expect(lease.canRetainOnStop, isFalse);
        expect(await File(lease.path).exists(), isTrue);
        expect(store.snapshot.entryCount, 0);
        expect(
          store.snapshot.managedFootprintBytes,
          mismatch == 'oversized' ? 30 : 10,
        );
        expect(await store.lookupAndPin(cacheKey()), isNull);
        await lease.dispose();
        expect(await File(lease.path).exists(), isFalse);
        expect(store.snapshot.managedFootprintBytes, 0);
        await store.dispose();
        expect(await create().lookupAndPin(cacheKey()), isNull);
      },
    );
  }

  test(
    'a stale source admission cannot restore an older larger configured target',
    () async {
      await store.setLimitBytes(20);
      expect(await admit(store, expected: 30, limit: 100), isNull);
      final lease = (await admit(store, expected: 10, limit: 100))!;
      await File(lease.path).writeAsBytes(List.filled(30, 1));
      expect(await store.completeWrite(lease), AudioCachePublication.rejected);
      await lease.dispose();
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  test(
    'abort waits behind held fresh capacity query and releases its reservation once',
    () async {
      final a = (await admit(store, expected: 60, limit: 100))!;
      final entered = Completer<void>();
      final capacityResult = Completer<int?>();
      capacity.query = () {
        entered.complete();
        return capacityResult.future;
      };
      final pending = admit(
        store,
        key: cacheKey(track: 'b'),
        expected: 40,
        limit: 100,
      );
      await entered.future;
      final abort = store.abort(a);
      await Future<void>.delayed(Duration.zero);
      expect(a.state, AudioCacheLeaseState.activeWrite);
      capacityResult.complete(AudioCachePolicy.physicalFloorBytes + 100);
      final b = (await pending)!;
      await abort;
      expect(a.state, AudioCacheLeaseState.cancelled);
      expect(store.snapshot.managedFootprintBytes, 40);
      await a.dispose();
      await b.dispose();
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  test(
    'missing and empty completed data reject publication without leaking reservation',
    () async {
      for (final createEmpty in [false, true]) {
        final lease = (await admit(store))!;
        if (createEmpty) await File(lease.path).writeAsBytes([]);
        expect(
          await store.completeWrite(lease),
          AudioCachePublication.rejected,
        );
        expect(lease.state, AudioCacheLeaseState.failed);
        expect(store.snapshot.managedFootprintBytes, 0);
        await lease.dispose();
      }
    },
  );

  test(
    'normalized format and matching MIME publish; unknown MIME is allowed',
    () async {
      final lease = (await admit(store, format: ' MP3 '))!;
      await File(lease.path).writeAsBytes(List.filled(10, 1));
      await File(
        '${lease.path}.mime',
      ).writeAsString('audio/mpeg; charset=binary');
      expect(await store.completeWrite(lease), AudioCachePublication.published);
      expect(audioCacheMimeMatches('mp3', 'text/html'), isFalse);
      expect(audioCacheMimeMatches('mp3', 'audio/custom'), isTrue);
      expect(audioCacheMimeMatches('mp3', null), isTrue);
      await lease.dispose();
    },
  );

  test(
    'offline fallback returns latest actual key while online miss never falls back',
    () async {
      final low = cacheKey(quality: 128);
      final high = cacheKey(quality: 999, format: 'flac');
      final first = await publish(store, key: low);
      await first.dispose();
      now = now.add(const Duration(seconds: 10));
      final second = await publish(store, key: high, format: 'flac');
      await second.dispose();
      expect(await store.lookupAndPin(cacheKey()), isNull);
      final fallback = (await store.lookupAndPin(cacheKey(), offline: true))!;
      expect(fallback.key, high);
      await fallback.dispose();
      expect(
        await store.lookupAndPin(cacheKey(platform: 'wy'), offline: true),
        isNull,
      );
      await File(second.path).writeAsBytes([]);
      final valid = (await store.lookupAndPin(cacheKey(), offline: true))!;
      expect(valid.key, low);
      expect(store.snapshot.entryCount, 1);
      await valid.dispose();
    },
  );

  test(
    'exact hit wins over a more recently used alternate quality offline',
    () async {
      final exact = await publish(store);
      await exact.dispose();
      now = now.add(const Duration(days: 1));
      final newer = await publish(store, key: cacheKey(quality: 128));
      await newer.dispose();
      final hit = (await store.lookupAndPin(cacheKey(), offline: true))!;
      expect(hit.key, cacheKey());
      await hit.dispose();
    },
  );

  test(
    'data-before-metadata crash, partial, MIME and metadata temp reconcile away',
    () async {
      final lease = (await admit(store))!;
      await File(lease.path).writeAsBytes([1, 2, 3]);
      await File('${lease.path}.part').writeAsBytes([1]);
      await File('${lease.path}.mime').writeAsString('audio/mpeg');
      await File(
        p.join(directory.path, 'he_music/audio/v1/temp/orphan.metadata.tmp'),
      ).writeAsString('{}');
      await store.dispose();
      final restarted = create();
      expect(await restarted.lookupAndPin(cacheKey()), isNull);
      expect(await File(lease.path).exists(), isFalse);
      expect(
        await Directory(
          p.join(directory.path, 'he_music/audio/v1/data'),
        ).list().toList(),
        isEmpty,
      );
      expect(
        await Directory(
          p.join(directory.path, 'he_music/audio/v1/temp'),
        ).list().toList(),
        isEmpty,
      );
    },
  );

  for (final corruption in [
    'missing',
    'zero',
    'size',
    'json',
    'key',
    'file_name',
    'schema',
    'symlink',
  ]) {
    test(
      'reconcile removes $corruption corruption and does not follow foreign paths',
      () async {
        final lease = await publish(store);
        await lease.dispose();
        final metadata = File(
          p.join(
            directory.path,
            'he_music/audio/v1/entries/${cacheKey().digest}.json',
          ),
        );
        final outside = File(p.join(directory.path, 'download.mp3'));
        await outside.writeAsBytes(List.filled(10, 9));
        switch (corruption) {
          case 'missing':
            await File(lease.path).delete();
          case 'zero':
            await File(lease.path).writeAsBytes([]);
          case 'size':
            await File(lease.path).writeAsBytes([1]);
          case 'json':
            await metadata.writeAsString('{bad');
          case 'symlink':
            await File(lease.path).delete();
            await Link(lease.path).create(outside.path);
          default:
            final map =
                jsonDecode(await metadata.readAsString())
                    as Map<String, dynamic>;
            if (corruption == 'key') {
              map['key'] = cacheKey(track: 'wrong').toJson();
            }
            if (corruption == 'file_name') map['file_name'] = outside.path;
            if (corruption == 'schema') map['schema'] = 2;
            await metadata.writeAsString(jsonEncode(map));
        }
        await store.dispose();
        final restarted = create();
        expect(await restarted.lookupAndPin(cacheKey()), isNull);
        expect(await metadata.exists(), isFalse);
        expect(await outside.readAsBytes(), List.filled(10, 9));
        expect(restarted.readHealth, AudioCacheReadHealth.ready);
      },
    );
  }

  test(
    'old schemas delete asynchronously without scanning; future and unknown survive',
    () async {
      await store.dispose();
      final audio = Directory(p.join(directory.path, 'he_music/audio'));
      for (final name in ['v0', 'v2', 'v3', 'unknown', 'v01']) {
        final target = Directory(p.join(audio.path, name));
        await target.create();
        await File(
          p.join(target.path, 'sentinel'),
        ).writeAsString('not metadata');
      }
      final entered = Completer<void>();
      final release = Completer<void>();
      final current = create(
        schema: 2,
        deleteOldSchema: (old) async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
          await old.delete(recursive: true);
        },
      );
      await current.initialize();
      await entered.future;
      expect(await current.lookupAndPin(cacheKey(schema: 2)), isNull);
      expect(current.snapshot.entryCount, 0);
      release.complete();
      await current.oldSchemaCleanup;
      expect(await Directory(p.join(audio.path, 'v0')).exists(), isFalse);
      expect(await Directory(p.join(audio.path, 'v1')).exists(), isFalse);
      for (final name in ['v2', 'v3', 'unknown', 'v01']) {
        expect(await Directory(p.join(audio.path, name)).exists(), isTrue);
      }
    },
  );

  test(
    'old schema delete failure does not fence reads and a fresh runtime retries',
    () async {
      await store.dispose();
      final old = Directory(p.join(directory.path, 'he_music/audio/v0'));
      await old.create();
      final failed = create(
        deleteOldSchema: (_) async {
          throw const FileSystemException('injected');
        },
      );
      await failed.initialize();
      await failed.oldSchemaCleanup;
      expect(failed.readHealth, AudioCacheReadHealth.ready);
      expect(await old.exists(), isTrue);
      await failed.dispose();
      final restarted = create();
      await restarted.initialize();
      await restarted.oldSchemaCleanup;
      expect(await old.exists(), isFalse);
    },
  );

  for (final completeFirst in [true, false]) {
    test(
      'same-key complete/cancel order completeFirst=$completeFirst is terminal once',
      () async {
        final old = (await admit(store))!;
        expect(await admit(store), isNull);
        await File(old.path).writeAsBytes(List.filled(10, 1));
        final operations = completeFirst
            ? [store.completeWrite(old), store.abort(old)]
            : [store.abort(old), store.completeWrite(old)];
        await Future.wait(operations);
        expect(
          old.state,
          completeFirst
              ? AudioCacheLeaseState.retainedData
              : AudioCacheLeaseState.cancelled,
        );
        expect(store.snapshot.entryCount, completeFirst ? 1 : 0);
        await old.dispose();
        await old.dispose();
        await store.invalidate(cacheKey());
        final next = (await admit(store))!;
        expect(next.path, isNot(old.path));
        await File(old.path).writeAsBytes([9]);
        await store.completeWrite(old);
        expect(await File(old.path).exists(), isFalse);
        expect(await admit(store), isNull);
        await File(next.path).writeAsBytes(List.filled(10, 2));
        expect(
          await store.completeWrite(next),
          AudioCachePublication.published,
        );
        await next.dispose();
      },
    );
  }

  test(
    'held capacity captures remaining and serializes terminal, clear and next admission',
    () async {
      final a = (await admit(
        store,
        key: cacheKey(track: 'a'),
        expected: 60,
        limit: 200,
      ))!;
      await File('${a.path}.part').writeAsBytes(List.filled(20, 1));
      final entered = Completer<void>();
      final result = Completer<int?>();
      capacity.query = () {
        entered.complete();
        return result.future;
      };
      final bFuture = admit(
        store,
        key: cacheKey(track: 'b'),
        expected: 50,
        limit: 200,
      );
      await entered.future;
      await File('${a.path}.part').writeAsBytes(List.filled(60, 1));
      await File('${a.path}.part').rename(a.path);
      var aCompleted = false;
      var cleared = false;
      final completion = store.completeWrite(a).then((value) {
        aCompleted = true;
        return value;
      });
      final clear = store.clear().then((value) {
        cleared = true;
        return value;
      });
      final cFuture = admit(
        store,
        key: cacheKey(track: 'c'),
        expected: 10,
        limit: 200,
      );
      await Future<void>.delayed(Duration.zero);
      expect(aCompleted, isFalse);
      expect(cleared, isFalse);
      expect(capacity.calls, 2);
      capacity.query = null;
      // Fits only if incorrectly shrinking A's captured 40-byte remaining to 0.
      result.complete(AudioCachePolicy.physicalFloorBytes + 50 + 39);
      expect(await bFuture, isNull);
      expect(await completion, AudioCachePublication.published);
      await clear;
      final c = (await cFuture)!;
      expect(c.acquisitionEpoch, 1);
      expect(store.snapshot.managedFootprintBytes, 70);
      await a.dispose();
      await c.dispose();
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  test(
    'held query success reserves captured basis once despite A progress',
    () async {
      final a = (await admit(store, expected: 60, limit: 110))!;
      final entered = Completer<void>();
      final result = Completer<int?>();
      capacity.query = () {
        entered.complete();
        return result.future;
      };
      final pending = admit(
        store,
        key: cacheKey(track: 'b'),
        expected: 50,
        limit: 110,
      );
      await entered.future;
      await File(a.path).writeAsBytes(List.filled(60, 1));
      final completion = store.completeWrite(a);
      result.complete(AudioCachePolicy.physicalFloorBytes + 110);
      final b = (await pending)!;
      await completion;
      expect(store.snapshot.managedFootprintBytes, 110);
      expect(
        await admit(store, key: cacheKey(track: 'c'), expected: 1, limit: 110),
        isNull,
      );
      expect(capacity.calls, 2);
      await a.dispose();
      await b.dispose();
    },
  );

  test(
    'fresh physical boundary, unknown, error and timeout never leave reservations',
    () async {
      final bounded = create(timeout: const Duration(milliseconds: 20));
      capacity.value = AudioCachePolicy.physicalFloorBytes + 9;
      expect(await admit(bounded), isNull);
      capacity.value = null;
      expect(await admit(bounded), isNull);
      capacity.query = () => throw StateError('injected');
      expect(await admit(bounded), isNull);
      final late = Completer<int?>();
      capacity.query = () => late.future;
      expect(await admit(bounded), isNull);
      late.complete(AudioCachePolicy.physicalFloorBytes + 10);
      expect(bounded.snapshot.managedFootprintBytes, 0);
      expect(bounded.readHealth, AudioCacheReadHealth.ready);
      expect(bounded.writeHealth, AudioCacheWriteHealth.ready);
      capacity.query = null;
      capacity.value = AudioCachePolicy.physicalFloorBytes + 10;
      final admitted = (await admit(bounded))!;
      expect(capacity.calls, 5);
      expect(
        capacity.paths.every(
          (path) => path == p.join(directory.path, 'he_music/audio/v1'),
        ),
        isTrue,
      );
      await bounded.abort(admitted);
      expect(bounded.snapshot.managedFootprintBytes, 0);
      await admitted.dispose();
    },
  );

  test(
    'unknown, zero, negative, oversized and unsafe format bypass before capacity',
    () async {
      for (final bytes in <int?>[null, 0, -1, 101]) {
        expect(await admit(store, expected: bytes), isNull);
      }
      expect(await admit(store, format: '../mp3'), isNull);
      expect(capacity.calls, 0);
      final lease = await publish(store);
      await lease.dispose();
      final hit = (await store.lookupAndPin(cacheKey()))!;
      expect(hit.key, cacheKey());
      await hit.dispose();
    },
  );

  for (final isWrite in [false, true]) {
    for (final commitFirst in [false, true]) {
      test(
        'clear fence write=$isWrite commitFirst=$commitFirst preserves native-owned data',
        () async {
          AudioCacheSourceLease lease;
          if (isWrite) {
            lease = (await admit(store))!;
            await File('${lease.path}.part').writeAsBytes([1]);
          } else {
            final published = await publish(store);
            await published.dispose();
            lease = (await store.lookupAndPin(cacheKey()))!;
          }
          if (commitFirst) expect(await lease.commitForPlayback(42), isTrue);
          final result = await store.clear();
          expect(result.hasDeferredData, isTrue);
          expect(store.snapshot.publishedBytes, 0);
          expect(await store.lookupAndPin(cacheKey()), isNull);
          expect(lease.clearedDeferred, commitFirst);
          expect(lease.commitRevoked, !commitFirst);
          expect(lease.canRetainOnStop, isFalse);
          expect(
            await File(isWrite ? '${lease.path}.part' : lease.path).exists(),
            isTrue,
          );
          if (!commitFirst) expect(await lease.commitForPlayback(42), isFalse);
          if (isWrite) {
            await File('${lease.path}.part').rename(lease.path);
            expect(
              await store.completeWrite(lease),
              AudioCachePublication.suppressed,
            );
            expect(lease.state, AudioCacheLeaseState.retainedData);
          }
          await lease.dispose();
          expect(await File(lease.path).exists(), isFalse);
          expect(store.snapshot.managedFootprintBytes, 0);
          final fresh = (await admit(store))!;
          expect(fresh.acquisitionEpoch, 1);
          expect(await fresh.commitForPlayback(43), isTrue);
          await fresh.dispose();
        },
      );
    }
  }

  test(
    'LRU skips pending pins, touch requires commit, release converges lowered limit',
    () async {
      final a = await publish(store, key: cacheKey(track: 'a'));
      await a.dispose();
      now = now.add(const Duration(seconds: 10));
      final b = await publish(store, key: cacheKey(track: 'b'));
      await b.dispose();
      final pin = (await store.lookupAndPin(a.key))!;
      final original = await File(pin.path).lastModified();
      now = now.add(const Duration(seconds: 10));
      await pin.touchAfterSourceCommit();
      expect(await File(pin.path).lastModified(), original);
      expect(await pin.commitForPlayback(1), isTrue);
      await pin.touchAfterSourceCommit();
      expect(await File(pin.path).lastModified(), now);
      await store.setLimitBytes(5);
      expect(await File(a.path).exists(), isTrue);
      expect(await File(b.path).exists(), isFalse);
      expect(store.snapshot.publishedBytes, 10);
      expect(pin.clearedDeferred, isFalse);
      expect(pin.publication, AudioCachePublication.published);
      await pin.dispose();
      expect(store.snapshot.publishedBytes, 0);
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  test(
    'all pinned and duplicate hit leases count each data file once',
    () async {
      final lease = await publish(store);
      final one = (await store.lookupAndPin(cacheKey()))!;
      final two = (await store.lookupAndPin(cacheKey()))!;
      expect(store.snapshot.managedFootprintBytes, 10);
      expect(store.snapshot.activeLeaseCount, 3);
      expect(
        await admit(store, key: cacheKey(track: 'new'), limit: 15),
        isNull,
      );
      await store.clear();
      await lease.dispose();
      await one.dispose();
      expect(await File(two.path).exists(), isTrue);
      expect(store.snapshot.managedFootprintBytes, 10);
      await two.dispose();
      expect(await File(two.path).exists(), isFalse);
    },
  );

  test(
    'materialized plus remaining never double counts and no chunk snapshots fire',
    () async {
      final events = <AudioCacheSnapshot>[];
      final subscription = store.snapshots.listen(events.add);
      final lease = (await admit(store, expected: 50))!;
      await Future<void>.delayed(Duration.zero);
      final count = events.length;
      await File('${lease.path}.part').writeAsBytes(List.filled(20, 1));
      await Future<void>.delayed(Duration.zero);
      expect(events.length, count);
      await store.setLimitBytes(100);
      expect(store.snapshot.managedFootprintBytes, 50);
      await File('${lease.path}.part').writeAsBytes(List.filled(70, 1));
      await store.setLimitBytes(100);
      expect(store.snapshot.managedFootprintBytes, 70);
      await File('${lease.path}.part').rename(lease.path);
      await store.completeWrite(lease);
      expect(store.snapshot.managedFootprintBytes, 70);
      expect(store.snapshot.publishedBytes, 70);
      await lease.dispose();
      final hit = (await store.lookupAndPin(cacheKey()))!;
      await hit.commitForPlayback(1);
      await Future<void>.delayed(Duration.zero);
      final beforeTouch = events.length;
      now = now.add(const Duration(seconds: 1));
      await hit.touchAfterSourceCommit();
      await Future<void>.delayed(Duration.zero);
      expect(events.length, beforeTouch);
      await hit.dispose();
      await subscription.cancel();
    },
  );
}
