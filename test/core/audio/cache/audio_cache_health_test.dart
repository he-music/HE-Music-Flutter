import 'dart:async';
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
  final stores = <FileAudioCacheStore>[];
  FileAudioCacheStore create({Future<Directory> Function()? root}) {
    final store = FileAudioCacheStore(
      capacity: capacity,
      applicationCacheDirectory: root ?? () async => directory,
    );
    stores.add(store);
    return store;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('audio-cache-health-');
    capacity = FakeCapacity();
  });
  tearDown(() async {
    for (final store in stores) {
      await store.dispose();
    }
    stores.clear();
    await directory.delete(recursive: true);
  });

  for (final failure in ['root', 'reconcile', 'index']) {
    test(
      '$failure initialization failure terminates lookup/write and fresh store retries',
      () async {
        final audio = Directory(p.join(directory.path, 'he_music/audio/v1'));
        if (failure == 'reconcile') {
          await audio.create(recursive: true);
          await File(
            p.join(audio.path, 'data'),
          ).writeAsString('directory obstruction');
        } else if (failure == 'index') {
          await audio.create(recursive: true);
          await File(
            p.join(audio.path, 'entries'),
          ).writeAsString('index obstruction');
        }
        final failed = create(
          root: failure == 'root'
              ? () async => throw const FileSystemException('root unavailable')
              : null,
        );
        expect(
          await failed
              .lookupAndPin(cacheKey())
              .timeout(const Duration(seconds: 1)),
          isNull,
        );
        expect(await admit(failed).timeout(const Duration(seconds: 1)), isNull);
        expect(failed.readHealth, AudioCacheReadHealth.unavailable);
        expect(failed.writeHealth, AudioCacheWriteHealth.unavailable);
        expect(capacity.calls, 0);
        await failed.dispose();
        if (await audio.exists()) await audio.delete(recursive: true);
        final fresh = create();
        final lease = (await admit(fresh))!;
        expect(fresh.readHealth, AudioCacheReadHealth.ready);
        expect(fresh.writeHealth, AudioCacheWriteHealth.ready);
        await lease.dispose();
      },
    );
  }

  test(
    'health-unavailable bypass does not wait for a held root future',
    () async {
      final held = Completer<Directory>();
      final store = create(root: () => held.future);
      final initializing = store.initialize();
      await Future<void>.delayed(Duration.zero);
      store.markReadUnavailable();
      expect(
        await store
            .lookupAndPin(cacheKey())
            .timeout(const Duration(milliseconds: 50)),
        isNull,
      );
      expect(
        await admit(store).timeout(const Duration(milliseconds: 50)),
        isNull,
      );
      held.complete(directory);
      await initializing;
    },
  );

  test(
    'cache ancestor symlink never permits reconcile or cleanup outside app cache',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'audio-cache-foreign-',
      );
      try {
        final sentinel = File(p.join(outside.path, 'user.mp3'));
        await sentinel.writeAsString('user-owned');
        await Link(p.join(directory.path, 'he_music')).create(outside.path);
        final store = create();
        expect(await store.lookupAndPin(cacheKey()), isNull);
        expect(store.readHealth, AudioCacheReadHealth.unavailable);
        expect(await sentinel.readAsString(), 'user-owned');
      } finally {
        await outside.delete(recursive: true);
      }
    },
  );

  test(
    'lookup waits terminal initialization but write fuse during init cannot be reset',
    () async {
      final held = Completer<Directory>();
      final store = create(root: () => held.future);
      var done = false;
      final lookup = store.lookupAndPin(cacheKey()).then((value) {
        done = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.readHealth, AudioCacheReadHealth.initializing);
      expect(done, isFalse);
      store.markWriteUnavailable();
      held.complete(directory);
      expect(await lookup, isNull);
      expect(store.readHealth, AudioCacheReadHealth.ready);
      expect(store.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(await admit(store), isNull);
    },
  );

  test(
    'read fuse during initialization cannot be overwritten by successful reconcile',
    () async {
      final held = Completer<Directory>();
      final store = create(root: () => held.future);
      final lookup = store.lookupAndPin(cacheKey());
      await Future<void>.delayed(Duration.zero);
      store.markReadUnavailable();
      held.complete(directory);
      expect(await lookup, isNull);
      expect(store.readHealth, AudioCacheReadHealth.unavailable);
      expect(store.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(await admit(store), isNull);
    },
  );

  for (final readFailure in [false, true]) {
    test(
      'held admission health fence readFailure=$readFailure prevents late reservation',
      () async {
        final store = create();
        final existing = await publish(store);
        await existing.dispose();
        final entered = Completer<void>();
        final result = Completer<int?>();
        capacity.query = () {
          entered.complete();
          return result.future;
        };
        final pending = admit(store, key: cacheKey(track: 'new'));
        await entered.future;
        if (readFailure) {
          store.markReadUnavailable();
        } else {
          store.markWriteUnavailable();
        }
        result.complete(AudioCachePolicy.physicalFloorBytes + 1000);
        expect(await pending, isNull);
        expect(store.snapshot.managedFootprintBytes, 10);
        expect(store.snapshot.activeLeaseCount, 0);
        final hit = await store.lookupAndPin(cacheKey());
        expect(hit == null, readFailure);
        await hit?.dispose();
        capacity.query = null;
        await store.dispose();
        final fresh = create();
        final recovered = (await fresh.lookupAndPin(cacheKey()))!;
        expect(fresh.readHealth, AudioCacheReadHealth.ready);
        expect(fresh.writeHealth, AudioCacheWriteHealth.ready);
        await recovered.dispose();
      },
    );
  }

  test(
    'writer directory failure fences writes only and preserves existing lookup',
    () async {
      final store = create();
      final published = await publish(store);
      await published.dispose();
      final temp = Directory(p.join(directory.path, 'he_music/audio/v1/temp'));
      await temp.delete();
      await File(temp.path).writeAsString('writer obstruction');
      expect(await admit(store, key: cacheKey(track: 'new')), isNull);
      expect(store.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(store.readHealth, AudioCacheReadHealth.ready);
      final hit = (await store.lookupAndPin(cacheKey()))!;
      await hit.dispose();
    },
  );

  test(
    'write failure and capacity failure do not fuse health; read fuse suppresses publication',
    () async {
      final store = create();
      final failed = (await admit(store))!;
      await store.abort(failed, failed: true);
      await failed.dispose();
      capacity.query = () => throw StateError('transient');
      expect(await admit(store), isNull);
      expect(store.readHealth, AudioCacheReadHealth.ready);
      expect(store.writeHealth, AudioCacheWriteHealth.ready);
      capacity.query = null;
      final pending = (await admit(store))!;
      await File(pending.path).writeAsBytes([1]);
      store.markReadUnavailable();
      expect(
        await store.completeWrite(pending),
        AudioCachePublication.suppressed,
      );
      expect(await pending.commitForPlayback(1), isFalse);
      expect(store.snapshot.publishedBytes, 0);
      await pending.dispose();
    },
  );
}
