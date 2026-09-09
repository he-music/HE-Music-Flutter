import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_source_plan.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:just_audio/just_audio.dart';

import 'cache_test_support.dart';

void main() {
  late Directory directory;
  late FileAudioCacheStore store;
  late AudioCacheRuntime runtime;
  late FakeCapacity capacity;
  late DateTime now;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('audio-cache-plan-');
    capacity = FakeCapacity();
    now = DateTime.fromMillisecondsSinceEpoch(1000000);
    store = FileAudioCacheStore(
      capacity: capacity,
      applicationCacheDirectory: () async => directory,
      clock: () => now,
    );
    runtime = AudioCacheRuntime(store: store, capabilityEnabled: true);
    await runtime.initialize();
  });
  tearDown(() async {
    await store.dispose();
    await directory.delete(recursive: true);
  });

  PlaybackSourceLease owner({
    AudioCacheSourceLease? cache,
    List<String>? events,
    Future<void> Function()? native,
    Future<void> Function()? cancel,
  }) => PlaybackSourceLease(
    source: AudioSource.uri(Uri.parse('https://example.invalid/audio')),
    cacheLease: cache,
    releaseNative:
        native ??
        () async {
          events?.add('native');
        },
    cancelTransport:
        cancel ??
        () async {
          events?.add('cancel');
        },
    releaseSourceRegistration: () async {
      events?.add('registry');
    },
  );

  ResolvedAudioSourcePlan plan(
    PlaybackSourceLease source, {
    AudioSourceKind? kind,
  }) => ResolvedAudioSourcePlan(
    cacheKey: source.cacheLease?.key,
    requestedQuality: 320,
    requestedFormat: 'mp3',
    resolvedFormat: 'mp3',
    expectedBytes: 10,
    kind:
        kind ??
        (source.cacheLease == null
            ? AudioSourceKind.plainRemote
            : AudioSourceKind.cachingRemote),
    requiresNetwork: true,
    sourceLease: source,
  );

  test(
    'plain and local sources release native, transport and registry once without cache lease',
    () async {
      for (final kind in [
        AudioSourceKind.plainRemote,
        AudioSourceKind.localTrack,
      ]) {
        final events = <String>[];
        final pending = plan(owner(events: events), kind: kind);
        await Future.wait([pending.dispose(), pending.dispose()]);
        expect(events, ['native', 'cancel', 'registry']);
        expect(() => pending.commit(1), throwsStateError);
      }
    },
  );

  test(
    'commit transfers exactly once; pending finally cannot dispose committed source',
    () async {
      final cache = (await admit(store))!;
      final events = <String>[];
      final owned = owner(cache: cache, events: events);
      final pending = plan(owned);
      expect(await pending.commit(7), same(owned));
      expect(cache.committedForPlayback, isTrue);
      expect(cache.playbackGeneration, 7);
      expect(() => pending.commit(8), throwsStateError);
      await pending.dispose();
      expect(events, isEmpty);
      await owned.dispose();
      await owned.dispose();
      expect(events, ['native', 'cancel', 'registry']);
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );

  for (final isWrite in [false, true]) {
    for (final moment in ['before-open', 'during-set', 'after-set']) {
      test(
        'clear revokes ${isWrite ? 'write' : 'hit'} plan $moment but holds data until native release',
        () async {
          AudioCacheSourceLease cache;
          if (isWrite) {
            cache = (await admit(store))!;
            await File('${cache.path}.part').writeAsBytes([1]);
          } else {
            final published = await publish(store);
            await published.dispose();
            cache = (await store.lookupAndPin(cacheKey()))!;
          }
          final nativeEntered = Completer<void>();
          final nativeDone = Completer<void>();
          final openStarted = Completer<void>();
          final finishSet = Completer<void>();
          Future<void>? setFuture;
          final path = isWrite ? '${cache.path}.part' : cache.path;
          Future<void> loadNative() async {
            final handle = await File(path).open();
            openStarted.complete();
            await finishSet.future;
            expect(await handle.read(1), isNotEmpty);
            await handle.close();
          }

          final events = <String>[];
          final owned = owner(
            cache: cache,
            events: events,
            native: () async {
              nativeEntered.complete();
              await setFuture;
              await nativeDone.future;
              events.add('native');
            },
          );
          final pending = plan(
            owned,
            kind: isWrite
                ? AudioSourceKind.cachingRemote
                : AudioSourceKind.localCacheHit,
          );
          if (moment != 'before-open') {
            setFuture = loadNative();
            await openStarted.future;
          }
          if (moment == 'after-set') {
            finishSet.complete();
            await setFuture;
          }
          await store.clear();
          if (moment == 'before-open') {
            setFuture = loadNative();
            await openStarted.future;
          }
          final commit = pending.commit(1);
          await nativeEntered.future;
          expect(
            await File(isWrite ? '${cache.path}.part' : cache.path).exists(),
            isTrue,
          );
          expect(events, isEmpty);
          expect(store.snapshot.publishedBytes, 0);
          expect(cache.commitRevoked, isTrue);
          if (!finishSet.isCompleted) finishSet.complete();
          await setFuture;
          nativeDone.complete();
          expect(await commit, isNull);
          await pending.dispose();
          expect(events, ['native', 'cancel', 'registry']);
          expect(store.snapshot.managedFootprintBytes, 0);
          expect(await File(cache.path).exists(), isFalse);
          expect(await File('${cache.path}.part').exists(), isFalse);
        },
      );
    }
  }

  test(
    'pending dispose racing a held commit cannot transfer ownership',
    () async {
      final cache = (await admit(store))!;
      final entered = Completer<void>();
      final capacityDone = Completer<int?>();
      capacity.query = () {
        entered.complete();
        return capacityDone.future;
      };
      final blocker = admit(store, key: cacheKey(track: 'other'));
      await entered.future;
      final events = <String>[];
      final pending = plan(owner(cache: cache, events: events));
      final commit = pending.commit(2);
      final disposal = pending.dispose();
      capacityDone.complete(null);
      await blocker;
      expect(await commit, isNull);
      await disposal;
      expect(pending.isTransferred, isFalse);
      expect(events, ['native', 'cancel', 'registry']);
      expect(store.snapshot.activeLeaseCount, 0);
    },
  );

  for (final reason in ['stale', 'set-failure', 'retry']) {
    test(
      '$reason pending hit disposal leaves lastModified unchanged',
      () async {
        final published = await publish(store);
        await published.dispose();
        final cache = (await store.lookupAndPin(cacheKey()))!;
        final original = await File(cache.path).lastModified();
        now = now.add(const Duration(hours: 1));
        final pending = plan(
          owner(cache: cache),
          kind: AudioSourceKind.localCacheHit,
        );
        await pending.dispose();
        expect(await File(cache.path).lastModified(), original);
        expect(store.snapshot.activeLeaseCount, 0);
      },
    );
  }

  test(
    'failed native fence never deletes data or unregisters and can retry safely',
    () async {
      final cache = (await admit(store))!;
      await File('${cache.path}.part').writeAsBytes([1]);
      var fail = true;
      final events = <String>[];
      final owned = owner(
        cache: cache,
        events: events,
        native: () async {
          if (fail) throw StateError('native still using data');
          events.add('native');
        },
      );
      await expectLater(owned.dispose(), throwsStateError);
      expect(events, isEmpty);
      expect(await File('${cache.path}.part').exists(), isTrue);
      fail = false;
      await owned.dispose();
      expect(events, ['native', 'cancel', 'registry']);
      expect(store.snapshot.activeLeaseCount, 0);
    },
  );

  test(
    'source factory failure rolls back reservation and same-key ownership',
    () async {
      final frozen = const AudioCachePolicy(limitBytes: 100);
      final failed = await runtime.createCachingSource(
        key: cacheKey(),
        resolvedFormat: 'mp3',
        expectedBytes: 10,
        frozenPolicy: frozen,
        frozenNetwork: NetworkConnectionType.wifi,
        factory: (lease) async {
          await File('${lease.path}.part').writeAsBytes([1]);
          throw StateError('factory failure');
        },
      );
      expect(failed, isNull);
      expect(store.snapshot.managedFootprintBytes, 0);
      expect(store.snapshot.activeLeaseCount, 0);
      expect(runtime.writeHealth, AudioCacheWriteHealth.ready);
      final next = (await admit(store))!;
      await next.dispose();
    },
  );

  test(
    'frozen policy is not replaced by later runtime changes; disable does not hide hits',
    () async {
      const frozen = AudioCachePolicy(limitBytes: 100);
      await runtime.updatePolicy(const AudioCachePolicy(enabled: false));
      final owned = (await runtime.createCachingSource(
        key: cacheKey(),
        resolvedFormat: 'mp3',
        expectedBytes: 10,
        frozenPolicy: frozen,
        frozenNetwork: NetworkConnectionType.wifi,
        factory: (lease) => owner(cache: lease),
      ))!;
      expect(runtime.policy.enabled, isFalse);
      await File(owned.cacheLease!.path).writeAsBytes(List.filled(10, 1));
      await store.completeWrite(owned.cacheLease!);
      await owned.dispose();
      final hit = (await runtime.lookupAndPin(cacheKey()))!;
      await hit.dispose();
      expect(
        await runtime.createCachingSource(
          key: cacheKey(track: 'new'),
          resolvedFormat: 'mp3',
          expectedBytes: 10,
          frozenPolicy: runtime.policy,
          frozenNetwork: NetworkConnectionType.wifi,
          factory: (lease) => owner(cache: lease),
        ),
        isNull,
      );
    },
  );

  test(
    'unsupported runtime bypasses lookup/write without root or capacity initialization',
    () async {
      var roots = 0;
      final unused = FileAudioCacheStore(
        capacity: capacity,
        applicationCacheDirectory: () async {
          roots++;
          return directory;
        },
      );
      final disabled = AudioCacheRuntime(
        store: unused,
        capabilityEnabled: false,
      );
      await disabled.initialize();
      expect(await disabled.lookupAndPin(cacheKey()), isNull);
      expect(
        await disabled.createCachingSource(
          key: cacheKey(),
          resolvedFormat: 'mp3',
          expectedBytes: 10,
          frozenPolicy: const AudioCachePolicy(),
          frozenNetwork: NetworkConnectionType.wifi,
          factory: (lease) => owner(cache: lease),
        ),
        isNull,
      );
      expect(roots, 0);
      expect(capacity.calls, 0);
      await unused.dispose();
    },
  );

  test(
    'completion observer consumes failure and late completion cannot publish after disposal',
    () async {
      final cache = (await admit(store))!;
      final result = Completer<File>();
      final observed = runtime.observeWriteCompletion(cache, result.future);
      result.completeError(const FileSystemException('injected sink failure'));
      expect(await observed, AudioCachePublication.rejected);
      expect(cache.state, AudioCacheLeaseState.failed);
      expect(runtime.writeHealth, AudioCacheWriteHealth.ready);
      await cache.dispose();
      final next = (await admit(store))!;
      final late = Completer<File>();
      final completed = runtime.observeWriteCompletion(next, late.future);
      await next.dispose();
      await File(next.path).writeAsBytes([1]);
      late.complete(File(next.path));
      expect(await completed, isNot(AudioCachePublication.published));
      expect(await File(next.path).exists(), isFalse);
      expect(store.snapshot.managedFootprintBytes, 0);
    },
  );
}
