import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/database/app_database.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';

void main() {
  late Directory root;
  late LocalMusicDatabase database;
  late LyricStore store;
  const song = LyricRequest(trackId: 'song', platform: 'qq');
  const bundle = RawLyricBundle(lyric: '[00:01.00]original');
  LyricStore open({LocalMusicDatabase? connection}) => LyricStore(
    database: connection ?? database,
    manualDirectory: () async => Directory('${root.path}/manual'),
    automaticDirectory: () async => Directory('${root.path}/automatic'),
  );
  Future<void> replace({RawLyricBundle lyrics = bundle}) => store.saveManual(
    song,
    lyrics,
    sourcePlatform: 'qq',
    sourceId: 'candidate',
    title: 'song',
    artist: '',
    token: store.beginSelection(song),
  );
  Future<List<LyricOffsetEntry>> rows() =>
      database.select(database.lyricOffsets).get();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lyric-offset-test');
    database = appDatabase;
    store = open();
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'reading an unadjusted song creates no records; returning to zero deletes its row',
    () async {
      expect(await store.readOffset(song, manual: false), 0);
      expect(await store.readOffset(song, manual: true), 0);
      expect(await rows(), isEmpty);
      await store.adjustOffset(song, 100, manual: false);
      expect((await rows()).single.milliseconds, 100);
      await store.adjustOffset(song, -100, manual: false);
      expect(await rows(), isEmpty);
      expect(await Directory('${root.path}/offsets').exists(), isFalse);
    },
  );

  test(
    'increments serialize into one row and survive automatic cache removal',
    () async {
      await store.saveAutomatic(song, bundle, store.automaticEpoch);
      await Future.wait([
        store.adjustOffset(song, 100, manual: false),
        store.adjustOffset(song, 100, manual: false),
        store.adjustOffset(song, 100, manual: false),
      ]);
      final row = (await rows()).single;
      expect(row.milliseconds, 300);
      expect(row.targetKey, lyricStorageKey(song));
      expect(row.sourceKind, 'default');
      expect(row.manualRevision, isNull);
      expect(row.updatedAt, greaterThan(0));
      expect((await store.read(song, manual: false))!.lyric, bundle.lyric);
      await store.refreshAutomatic(song);
      await store.clearAutomatic();
      store = open();
      expect(await store.readOffset(song, manual: false), 300);
      expect(await store.read(song, manual: false), isNull);
      expect(
        await store.readOffset(
          const LyricRequest(trackId: 'song', platform: 'netease'),
          manual: false,
        ),
        0,
      );
    },
  );

  test('corrections persist after closing and reopening SQLite', () async {
    final file = File('${root.path}/offsets_test.db');
    final first = LocalMusicDatabase.forTesting(file: file);
    try {
      await open(connection: first).adjustOffset(song, -200, manual: false);
    } finally {
      await first.close();
    }
    final second = LocalMusicDatabase.forTesting(file: file);
    try {
      expect(
        await open(connection: second).readOffset(song, manual: false),
        -200,
      );
      expect(
        (await second.select(second.lyricOffsets).get()).single.milliseconds,
        -200,
      );
    } finally {
      await second.close();
    }
  });

  test('manual replacements and restores delete only the manual row', () async {
    await store.adjustOffset(song, 200, manual: false);
    await replace();
    await store.adjustOffset(song, -100, manual: true);
    store = open();
    expect(await store.readOffset(song, manual: true), -100);
    expect(
      (await rows())
          .where((row) => row.sourceKind == 'manual')
          .single
          .manualRevision,
      isNotEmpty,
    );
    expect((await store.read(song, manual: true))!.lyric, bundle.lyric);
    await replace(lyrics: const RawLyricBundle(lyric: '[00:02.00]replacement'));
    expect((await rows()).single.sourceKind, 'default');
    expect(await store.readOffset(song, manual: true), 0);
    await store.adjustOffset(song, 100, manual: true);
    await store.restoreDefault(song);
    expect((await rows()).single.sourceKind, 'default');
    expect(await store.readOffset(song, manual: false), 200);
    await replace();
    await store.adjustOffset(song, 100, manual: true);
    await store.clearManual();
    expect((await rows()).single.sourceKind, 'default');
    expect(await store.readOffset(song, manual: true), 0);
  });

  test(
    'bulk manual removal deletes orphan rows and keeps default corrections',
    () async {
      await replace();
      await store.adjustOffset(song, -100, manual: true);
      await store.adjustOffset(song, 200, manual: false);
      await File('${root.path}/manual/${lyricStorageKey(song)}.json').delete();
      expect(await rows(), hasLength(2));
      await store.clearManual();
      expect((await rows()).single.sourceKind, 'default');
      expect(await store.readOffset(song, manual: false), 200);
    },
  );

  test(
    'a missing or changed manual selection removes its stale timing row',
    () async {
      await replace();
      await store.adjustOffset(song, 100, manual: true);
      await (database.update(database.lyricOffsets)
            ..where((row) => row.sourceKind.equals('manual')))
          .write(const LyricOffsetsCompanion(manualRevision: Value('stale')));
      expect(await store.readOffset(song, manual: true), 0);
      expect(await rows(), isEmpty);
      await store.adjustOffset(song, 100, manual: true);
      await File('${root.path}/manual/${lyricStorageKey(song)}.json').delete();
      expect(await store.readOffset(song, manual: true), 0);
      expect(await rows(), isEmpty);
    },
  );

  test(
    'restore cleans an orphan timing row even if its lyrics are gone',
    () async {
      await replace();
      await store.adjustOffset(song, 100, manual: true);
      await File('${root.path}/manual/${lyricStorageKey(song)}.json').delete();
      await store.restoreDefault(song);
      expect(await rows(), isEmpty);
    },
  );

  test(
    'failed lyric replacement preserves the manual lyrics and correction',
    () async {
      await replace();
      await store.adjustOffset(song, -100, manual: true);
      await Directory(
        '${root.path}/manual/${lyricStorageKey(song)}.json.tmp',
      ).create();
      await expectLater(
        replace(lyrics: const RawLyricBundle(lyric: '[00:02.00]new')),
        throwsA(isA<FileSystemException>()),
      );
      expect((await store.read(song, manual: true))!.lyric, bundle.lyric);
      expect(await store.readOffset(song, manual: true), -100);
      expect((await rows()).single.sourceKind, 'manual');
    },
  );

  test(
    'reset all deletes all rows, keeps both lyric sources, and never reloads lyrics',
    () async {
      const other = LyricRequest(trackId: 'other', platform: 'qq');
      await replace();
      await store.saveAutomatic(song, bundle, store.automaticEpoch);
      await store.adjustOffset(song, 100, manual: false);
      await store.adjustOffset(song, -200, manual: true);
      await store.adjustOffset(other, 300, manual: false);
      final reloads = <String?>[];
      final events = <LyricOffsetChange>[];
      final subscription = store.changes.listen(reloads.add);
      final offsetSubscription = store.offsetChanges.listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(offsetSubscription.cancel);
      await store.resetAllOffsets();
      expect(await rows(), isEmpty);
      expect(reloads, isEmpty);
      expect(events, hasLength(1));
      expect(events.single.key, isNull);
      expect((await store.read(song, manual: true))!.lyric, bundle.lyric);
      expect((await store.read(song, manual: false))!.lyric, bundle.lyric);
    },
  );

  test(
    'reset all serializes with adjustments and works with an empty table',
    () async {
      await store.resetAllOffsets();
      await Future.wait([
        store.adjustOffset(song, 100, manual: false),
        store.resetAllOffsets(),
        store.adjustOffset(song, -100, manual: false),
      ]);
      expect(await store.readOffset(song, manual: false), -100);
      expect((await rows()).single.milliseconds, -100);
    },
  );

  test('zero and unknown source kinds are rejected by the database', () async {
    LyricOffsetEntry row(int milliseconds, String kind) => LyricOffsetEntry(
      targetKey: lyricStorageKey(song),
      sourceKind: kind,
      milliseconds: milliseconds,
      updatedAt: 1,
    );
    await expectLater(
      database.into(database.lyricOffsets).insert(row(0, 'default')),
      throwsException,
    );
    await expectLater(
      database.into(database.lyricOffsets).insert(row(100, 'unknown')),
      throwsException,
    );
    expect(await rows(), isEmpty);
  });

  test('failed updates roll back the correction and emit no change', () async {
    await store.adjustOffset(song, 100, manual: false);
    await database.customStatement(
      "CREATE TRIGGER reject_timing_update BEFORE UPDATE ON lyric_offsets BEGIN SELECT RAISE(ABORT, 'test write failure'); END",
    );
    final events = <LyricOffsetChange>[];
    final subscription = store.offsetChanges.listen(events.add);
    addTearDown(subscription.cancel);
    await expectLater(
      store.adjustOffset(song, 100, manual: false),
      throwsException,
    );
    expect(await store.readOffset(song, manual: false), 100);
    expect(events, isEmpty);
  });

  test('failed bulk resets keep all corrections and emit no reset', () async {
    await replace();
    await store.adjustOffset(song, 100, manual: false);
    await store.adjustOffset(song, -100, manual: true);
    await database.customStatement(
      "CREATE TRIGGER reject_timing_delete BEFORE DELETE ON lyric_offsets WHEN OLD.source_kind = 'manual' BEGIN SELECT RAISE(ABORT, 'test delete failure'); END",
    );
    final events = <LyricOffsetChange>[];
    final subscription = store.offsetChanges.listen(events.add);
    addTearDown(subscription.cancel);
    await expectLater(store.resetAllOffsets(), throwsException);
    expect(await rows(), hasLength(2));
    expect(await store.readOffset(song, manual: false), 100);
    expect(await store.readOffset(song, manual: true), -100);
    expect(events, isEmpty);
  });

  test('local timing follows normalized file paths and not scan IDs', () async {
    const before = LyricRequest(
      trackId: 'before',
      platform: 'local',
      localPath: '/music/album/../song.mp3',
    );
    const after = LyricRequest(
      trackId: 'after',
      platform: 'local',
      localPath: 'file:///music/song.mp3',
    );
    await store.adjustOffset(before, 100, manual: false);
    expect(await store.readOffset(after, manual: false), 100);
  });
}
