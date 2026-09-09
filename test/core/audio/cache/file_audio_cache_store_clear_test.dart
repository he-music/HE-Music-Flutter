import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:path/path.dart' as p;

import 'cache_test_support.dart';

void main() {
  late Directory directory;
  late FileAudioCacheStore store;
  late CacheFileDeletionFault deletion;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cache-clear-');
    deletion = CacheFileDeletionFault();
    store = FileAudioCacheStore(
      capacity: FakeCapacity(),
      applicationCacheDirectory: () async => directory,
      deleteFile: deletion.delete,
    );
    await store.initialize();
  });
  tearDown(() async {
    await store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'explicit clear fails after failed root while lookup silently bypasses',
    () async {
      final unavailable = FileAudioCacheStore(
        capacity: FakeCapacity(),
        applicationCacheDirectory: () async =>
            throw const FileSystemException('private root'),
      );
      addTearDown(unavailable.dispose);
      await expectLater(
        unavailable.clear(),
        throwsA(isA<AudioCacheClearException>()),
      );
      expect(unavailable.readHealth, AudioCacheReadHealth.unavailable);
      expect(unavailable.writeHealth, AudioCacheWriteHealth.unavailable);
      expect(await unavailable.lookupAndPin(cacheKey()), isNull);
    },
  );

  test(
    'metadata delete failure fences all entries and reports safe failure',
    () async {
      final first = await publish(store);
      await first.dispose();
      final second = await publish(store, key: cacheKey(track: 'second'));
      await second.dispose();
      final metadata = File(
        p.join(
          directory.path,
          'he_music',
          'audio',
          'v1',
          'entries',
          '${cacheKey().digest}.json',
        ),
      );
      deletion.blockedPath = metadata.path;
      await expectLater(
        store.clear(),
        throwsA(
          isA<AudioCacheClearException>().having(
            (error) => error.toString(),
            'safe message',
            isNot(contains(directory.path)),
          ),
        ),
      );
      expect(await metadata.exists(), isTrue);
      expect(store.snapshot.entryCount, 0);
      expect(store.snapshot.publishedBytes, 0);
      expect(store.readHealth, AudioCacheReadHealth.unavailable);
      expect(await store.lookupAndPin(cacheKey()), isNull);
      expect(await File(first.path).exists(), isFalse);
      expect(await File(second.path).exists(), isFalse);
      await expectLater(
        store.clear(),
        throwsA(isA<AudioCacheClearException>()),
      );
    },
  );

  for (final artifact in ['data', 'zero-data', 'part', 'mime', 'temp']) {
    test(
      'clear retries failed $artifact deletion even when it occupies zero bytes',
      () async {
        final lease = await publish(store);
        await lease.dispose();
        final path = switch (artifact) {
          'part' => '${lease.path}.part',
          'mime' => '${lease.path}.mime',
          'temp' => p.join(
            directory.path,
            'he_music',
            'audio',
            'v1',
            'temp',
            '${p.basename(lease.path)}.metadata.tmp',
          ),
          _ => lease.path,
        };
        if (artifact != 'data') await File(path).writeAsBytes([]);
        deletion.blockedPath = path;
        await expectLater(
          store.clear(),
          throwsA(isA<AudioCacheClearException>()),
        );
        expect(store.snapshot.publishedBytes, 0);
        expect(store.snapshot.activeLeaseCount, 0);
        expect(
          store.snapshot.managedFootprintBytes,
          artifact == 'data' ? 10 : 0,
        );
        expect(await File(path).exists(), isTrue);
        expect(await store.lookupAndPin(cacheKey()), isNull);
        await expectLater(
          store.clear(),
          throwsA(isA<AudioCacheClearException>()),
        );
        deletion.blockedPath = null;
        expect((await store.clear()).hasDeferredData, isFalse);
        expect(await File(path).exists(), isFalse);
        expect(store.snapshot.managedFootprintBytes, 0);
      },
    );
  }

  test(
    'automatic cleanup remains silent but its garbage makes explicit clear fail',
    () async {
      final lease = await publish(store);
      await lease.dispose();
      deletion.blockedPath = lease.path;
      await store.invalidate(cacheKey());
      expect(store.snapshot.publishedBytes, 0);
      expect(store.readHealth, AudioCacheReadHealth.ready);
      await expectLater(
        store.clear(),
        throwsA(isA<AudioCacheClearException>()),
      );
      deletion.blockedPath = null;
      expect((await store.clear()).hasDeferredData, isFalse);
      expect(await File(lease.path).exists(), isFalse);
    },
  );

  test(
    'failed clear preserves committed native data and revokes pending commit',
    () async {
      final active = await publish(store);
      expect(await active.commitForPlayback(1), isTrue);
      final pending = await publish(store, key: cacheKey(track: 'pending'));
      final unleased = await publish(store, key: cacheKey(track: 'unleased'));
      await unleased.dispose();
      deletion.blockedPath = unleased.path;
      await expectLater(
        store.clear(),
        throwsA(isA<AudioCacheClearException>()),
      );
      expect(active.clearedDeferred, isTrue);
      expect(pending.commitRevoked, isTrue);
      expect(await pending.commitForPlayback(2), isFalse);
      expect(await File(active.path).exists(), isTrue);
      expect(await File(pending.path).exists(), isTrue);
      expect(store.snapshot.publishedBytes, 0);
      deletion.blockedPath = null;
      expect((await store.clear()).hasDeferredData, isTrue);
      await pending.dispose();
      await active.dispose();
      expect((await store.clear()).hasDeferredData, isFalse);
      expect(await File(active.path).exists(), isFalse);
    },
  );

  test(
    'cancelled lease without data is not reported as active deferred data',
    () async {
      final lease = (await admit(store))!;
      await store.abort(lease);
      expect((await store.clear()).hasDeferredData, isFalse);
      await lease.dispose();
    },
  );
}
