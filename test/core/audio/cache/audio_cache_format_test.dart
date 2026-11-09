import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_format.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:path/path.dart' as p;

import 'cache_test_support.dart';

void main() {
  late Directory directory;
  final stores = <FileAudioCacheStore>[];

  FileAudioCacheStore create() {
    final store = FileAudioCacheStore(
      capacity: FakeCapacity(),
      applicationCacheDirectory: () async => directory,
    );
    stores.add(store);
    return store;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cache-format-test-');
  });
  tearDown(() async {
    for (final store in stores) {
      await store.dispose();
    }
    stores.clear();
    await directory.delete(recursive: true);
  });

  test('resolver maps only known service request formats', () {
    for (final (platform, requested, expected) in [
      ('kuwo', 'mflac', 'flac'),
      ('soda', 'aac', 'm4a'),
      ('soda', 'flac', 'm4a'),
      (' SODA ', ' AAC ', 'm4a'),
      ('qq', 'flac', 'flac'),
      ('kuwo', 'mp3', 'mp3'),
      ('qq', 'mflac', null),
      ('soda', '../aac', null),
      ('kuwo', 'unknown', null),
    ]) {
      expect(
        resolveAudioCacheFormat(platform: platform, requestedFormat: requested),
        expected,
      );
    }
  });

  for (final (platform, requested, resolved, mime) in [
    ('kuwo', 'mflac', 'flac', 'audio/flac'),
    ('soda', 'aac', 'm4a', 'audio/mp4'),
    ('soda', 'flac', 'm4a', 'audio/x-m4a'),
    ('qq', 'mp3', 'mp3', 'audio/mpeg'),
    ('kuwo', 'flac', 'flac', 'audio/flac'),
    ('soda', 'aac', 'aac', 'audio/aac'),
    ('soda', 'flac', 'flac', 'audio/flac'),
  ]) {
    test(
      '$platform $requested to $resolved publishes and restores schema 1',
      () async {
        final key = cacheKey(platform: platform, format: requested);
        final store = create();
        final lease = (await admit(store, key: key, format: resolved))!;
        await File(lease.path).writeAsBytes(List.filled(10, 1));
        await File('${lease.path}.mime').writeAsString(mime);
        expect(
          await store.completeWrite(lease),
          AudioCachePublication.published,
        );
        expect(p.extension(lease.path), '.$resolved');
        final metadataFile = File(
          p.join(
            directory.path,
            'he_music/audio/v1/entries/${key.digest}.json',
          ),
        );
        final json = jsonDecode(await metadataFile.readAsString());
        final metadata = AudioCacheMetadata.tryParse(json)!;
        expect(json['schema'], 1);
        expect(AudioCacheKey.currentSchema, 1);
        expect(metadata.key, key);
        expect(metadata.key.requestedFormat, requested);
        expect(metadata.resolvedFormat, resolved);
        expect(jsonDecode(key.canonicalIdentity), [
          'audio-cache:v1',
          platform,
          'song',
          320,
          requested,
        ]);
        await lease.dispose();
        await store.dispose();

        final restarted = create();
        final hit = (await restarted.lookupAndPin(key))!;
        expect(hit.path, lease.path);
        expect(hit.key, key);
        expect(hit.resolvedFormat, resolved);
        await hit.dispose();
        final missing = cacheKey(
          platform: platform,
          quality: 999,
          format: 'opus',
        );
        expect(await restarted.lookupAndPin(missing), isNull);
        final offline = (await restarted.lookupAndPin(missing, offline: true))!;
        expect(offline.key, key);
        expect(offline.resolvedFormat, resolved);
        await offline.dispose();
        expect(
          await restarted.lookupAndPin(
            cacheKey(platform: 'other', quality: 999),
            offline: true,
          ),
          isNull,
        );
        if (requested != resolved) {
          expect(
            await restarted.lookupAndPin(
              cacheKey(platform: platform, format: resolved),
            ),
            isNull,
          );
        }
      },
    );
  }

  for (final (platform, requested, resolved) in [
    ('qq', 'mflac', 'flac'),
    ('qq', 'aac', 'm4a'),
    ('kuwo', 'aac', 'm4a'),
    ('soda', 'mp3', 'm4a'),
    ('soda', 'flac', 'aac'),
    ('kuwo', 'mflac', 'mp3'),
    ('unknown', 'flac', 'm4a'),
  ]) {
    test(
      '$platform $requested to $resolved rejects publish and forged recovery',
      () async {
        final key = cacheKey(platform: platform, format: requested);
        final store = create();
        final lease = (await admit(store, key: key, format: resolved))!;
        await File(lease.path).writeAsBytes(List.filled(10, 1));
        expect(
          await store.completeWrite(lease),
          AudioCachePublication.rejected,
        );
        expect(await store.lookupAndPin(key, offline: true), isNull);
        final forged = AudioCacheMetadata(
          key: key,
          fileName: p.basename(lease.path),
          resolvedFormat: resolved,
          actualBytes: 10,
          completedAtMs: 0,
        ).toJson();
        expect(AudioCacheMetadata.tryParse(forged), isNull);
        await lease.dispose();
        await store.dispose();
        await File(lease.path).writeAsBytes(List.filled(10, 1));
        await File(
          p.join(
            directory.path,
            'he_music/audio/v1/entries/${key.digest}.json',
          ),
        ).writeAsString(jsonEncode(forged));
        final restarted = create();
        expect(await restarted.lookupAndPin(key, offline: true), isNull);
        expect(restarted.snapshot.entryCount, 0);
        expect(await File(lease.path).exists(), isFalse);
      },
    );
  }

  test(
    'mapped containers still reject conflicting MIME at publication',
    () async {
      for (final (platform, requested, resolved, mime) in [
        ('kuwo', 'mflac', 'flac', 'audio/mpeg'),
        ('soda', 'aac', 'm4a', 'audio/aac'),
        ('soda', 'flac', 'm4a', 'audio/flac'),
        ('soda', 'flac', 'm4a', 'text/html'),
      ]) {
        final store = create();
        final key = cacheKey(platform: platform, format: requested);
        final lease = (await admit(store, key: key, format: resolved))!;
        await File(lease.path).writeAsBytes(List.filled(10, 1));
        expect(
          await store.completeWrite(lease, mimeType: mime),
          AudioCachePublication.rejected,
        );
        expect(await store.lookupAndPin(key), isNull);
        await lease.dispose();
        await store.dispose();
      }
    },
  );

  test('mapped metadata keeps filename, output format and size validation', () {
    final key = cacheKey(platform: 'soda', format: 'flac');
    final value = AudioCacheMetadata(
      key: key,
      fileName: '${key.digest}.session.m4a',
      resolvedFormat: 'm4a',
      actualBytes: 10,
      completedAtMs: 0,
    ).toJson();
    expect(AudioCacheMetadata.tryParse(value), isNotNull);
    for (final mutation in <Map<String, Object>>[
      {'file_name': '../${key.digest}.session.m4a'},
      {'file_name': '${key.digest}.session.flac'},
      {'file_name': '${cacheKey().digest}.session.m4a'},
      {'resolved_format': '../m4a'},
      {'resolved_format': 'M4A'},
      {'actual_bytes': 0},
      {'schema': 2},
    ]) {
      expect(AudioCacheMetadata.tryParse({...value, ...mutation}), isNull);
    }
    expect(
      audioCacheFormatsCompatible(
        platform: 'soda',
        requestedFormat: 'flac',
        resolvedFormat: '../m4a',
      ),
      isFalse,
    );
  });
}
