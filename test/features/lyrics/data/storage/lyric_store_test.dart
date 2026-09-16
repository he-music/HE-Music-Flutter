import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';

void main() {
  late Directory root;
  late LyricStore store;
  const target = LyricRequest(trackId: 'original', platform: 'qq');
  const other = LyricRequest(trackId: 'other', platform: 'qq');
  const bundle = RawLyricBundle(
    lyric: '[00:00.00]original',
    translation: '[00:00.00]translation',
    romanization: '[00:00.00]roma',
  );
  LyricStore open({int limit = 50 * 1024 * 1024}) => LyricStore(
    manualDirectory: () async => Directory('${root.path}/manual'),
    automaticDirectory: () async => Directory('${root.path}/auto'),
    limitBytes: limit,
  );
  Future<void> save(
    LyricRequest request, {
    RawLyricBundle value = bundle,
    (int, int)? token,
  }) => store.saveManual(
    request,
    value,
    sourcePlatform: 'kugou',
    sourceId: 'composite|candidate',
    title: 'title',
    artist: 'artist',
    token: token ?? store.beginSelection(request),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('lyric-store-test');
    store = open();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'refresh removes only the target cache and rejects stale writes',
    () async {
      await save(target);
      final epoch = store.automaticEpoch;
      await store.saveAutomatic(target, bundle, epoch);
      await store.saveAutomatic(other, bundle, epoch);
      final changes = <String?>[];
      final subscription = store.changes.listen(changes.add);
      await store.refreshAutomatic(target);
      await store.saveAutomatic(target, bundle, epoch);
      expect(await store.read(target, manual: false), isNull);
      expect(await store.read(other, manual: false), isNotNull);
      expect(await store.read(target, manual: true), isNotNull);
      expect(changes, [lyricStorageKey(target)]);
      await subscription.cancel();
    },
  );

  test(
    'complete manual bundle survives restart and automatic clearing',
    () async {
      await save(target);
      await store.saveAutomatic(target, bundle, store.automaticEpoch);
      await store.clearAutomatic();
      store = open();
      final read = await store.read(target, manual: true);
      expect(read!.translation, bundle.translation);
      expect(read.romanization, bundle.romanization);
      expect(await store.read(target, manual: false), isNull);
      final stats = await store.statistics();
      expect(stats.manualCount, 1);
      expect(stats.manualBytes, greaterThan(0));
      await store.restoreDefault(target);
      expect(await store.hasManual(target), isFalse);
    },
  );

  test(
    'replacement is a full bundle and unusable selection preserves old choice',
    () async {
      await save(target);
      await expectLater(
        save(
          target,
          value: const RawLyricBundle(lyric: 'plain unsupported text'),
        ),
        throwsFormatException,
      );
      expect(
        (await store.read(target, manual: true))!.romanization,
        bundle.romanization,
      );
      await save(
        target,
        value: const RawLyricBundle(lyric: '[00:00.00]replacement'),
      );
      final read = (await store.read(target, manual: true))!;
      expect(read.translation, isEmpty);
      expect(read.romanization, isEmpty);
    },
  );

  test(
    'restore, bulk delete and newer selection invalidate pending network choices',
    () async {
      var token = store.beginSelection(target);
      await store.restoreDefault(target);
      await expectLater(save(target, token: token), throwsStateError);
      token = store.beginSelection(target);
      await store.clearManual();
      await expectLater(save(target, token: token), throwsStateError);
      token = store.beginSelection(target);
      await save(target);
      await expectLater(save(target, token: token), throwsStateError);
      expect((await store.statistics()).manualCount, 1);
    },
  );

  test('failed disk write leaves previous manual selection intact', () async {
    await save(target);
    final temporary = Directory(
      '${root.path}/manual/${lyricStorageKey(target)}.json.tmp',
    );
    await temporary.create();
    await expectLater(
      save(target, value: const RawLyricBundle(lyric: '[00:00.00]replacement')),
      throwsA(isA<FileSystemException>()),
    );
    expect((await store.read(target, manual: true))!.lyric, bundle.lyric);
    await temporary.delete();
  });

  test(
    'clear rejects old automatic writers and never deletes manual lyrics',
    () async {
      await save(target);
      final epoch = store.automaticEpoch;
      await store.clearAutomatic();
      await store.saveAutomatic(target, bundle, epoch);
      expect(await store.read(target, manual: false), isNull);
      expect(await store.hasManual(target), isTrue);
      await store.saveAutomatic(target, bundle, store.automaticEpoch);
      await store.clearManual();
      expect(await store.read(target, manual: false), isNotNull);
    },
  );

  test(
    'automatic corruption is deleted; manual corruption is retained',
    () async {
      await save(target);
      await store.saveAutomatic(target, bundle, 0);
      final key = lyricStorageKey(target);
      await File('${root.path}/manual/$key.json').writeAsString('{broken');
      await File('${root.path}/auto/$key.json').writeAsString('{broken');
      await expectLater(
        store.read(target, manual: true),
        throwsFormatException,
      );
      expect(await store.hasManual(target), isTrue);
      expect(await store.read(target, manual: false), isNull);
      expect(await File('${root.path}/auto/$key.json').exists(), isFalse);
    },
  );

  test(
    'LRU touches on hit, evicts oldest and skips oversize bundles',
    () async {
      await store.saveAutomatic(target, bundle, 0);
      final size = (await store.statistics()).automaticBytes;
      store = open(limit: size * 2 + 50);
      await store.saveAutomatic(other, bundle, 0);
      await File(
        '${root.path}/auto/${lyricStorageKey(other)}.json',
      ).setLastModified(DateTime(2000));
      await store.read(target, manual: false);
      const third = LyricRequest(trackId: 'third', platform: 'qq');
      await store.saveAutomatic(third, bundle, 0);
      expect(await store.read(other, manual: false), isNull);
      expect(await store.read(target, manual: false), isNotNull);
      expect(
        (await store.statistics()).automaticBytes,
        lessThanOrEqualTo(size * 2 + 50),
      );
      const huge = LyricRequest(trackId: 'huge', platform: 'qq');
      await store.saveAutomatic(
        huge,
        RawLyricBundle(lyric: '[00:00.00]${'x' * 5000}'),
        0,
      );
      expect(await store.read(huge, manual: false), isNull);
    },
  );

  test(
    'local identity uses normalized path and ignores scan metadata',
    () async {
      final first = LyricRequest(
        trackId: 'scan-1',
        platform: 'local',
        localPath: '${root.path}/a/../song.mp3',
      );
      final rescanned = LyricRequest(
        trackId: 'scan-2',
        platform: 'local',
        localPath: Uri.file('${root.path}/song.mp3').toString(),
      );
      expect(lyricStorageKey(first), lyricStorageKey(rescanned));
      await save(first);
      expect(await store.read(rescanned, manual: true), isNotNull);
      await store.saveAutomatic(first, bundle, 0);
      expect(await store.read(first, manual: false), isNull);
      expect(
        lyricStorageKey(const LyricRequest(trackId: 'c', platform: 'a::b')),
        isNot(
          lyricStorageKey(const LyricRequest(trackId: 'b::c', platform: 'a')),
        ),
      );
    },
  );
}
