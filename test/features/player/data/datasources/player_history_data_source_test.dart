import 'dart:convert';

import 'package:he_music_flutter/core/database/app_database.dart';
import 'package:drift/drift.dart'
    show QueryInterceptor, QueryExecutor, TransactionExecutor;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_history_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'backfill executes one conditional UPDATE without SELECT or transaction',
    () async {
      final queries = _HistoryQueryLog();
      const dataSource = PlayerHistoryDataSource();
      const track = PlayerTrack(
        id: 'duration',
        title: 'Duration',
        duration: Duration(seconds: 272),
      );
      await dataSource.appendTrack(track);
      await appDatabase.runWithInterceptor(() async {
        queries.statements.clear();
        expect(
          await dataSource.updateTrackDuration(
            track.copyWith(duration: const Duration(seconds: 273)),
          ),
          isTrue,
        );
        expect(queries.statements, [startsWith('UPDATE playback_history')]);
        queries.statements.clear();
        expect(
          await dataSource.updateTrackDuration(
            track.copyWith(duration: const Duration(seconds: 273)),
          ),
          isFalse,
        );
        expect(queries.statements, [startsWith('UPDATE playback_history')]);
      }, interceptor: queries);
    },
  );

  test('failed legacy migration can retry before duration backfill', () async {
    SharedPreferences.setMockInitialValues({
      'player_play_history_v1': 'invalid-json',
    });
    const dataSource = PlayerHistoryDataSource();
    await expectLater(dataSource.listHistory(), throwsFormatException);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'player_play_history_v1',
      jsonEncode([
        {'id': 'legacy', 'title': 'Legacy', 'playedAt': 123},
      ]),
    );
    expect(
      await dataSource.updateTrackDuration(
        const PlayerTrack(
          id: 'legacy',
          title: 'Legacy',
          duration: Duration(seconds: 272),
        ),
      ),
      isTrue,
    );
    final item = (await dataSource.listHistory()).single;
    expect(item.duration, 272);
    expect(item.playedAt, 123);
  });

  test('history persists duration as integer seconds', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'duration',
        title: 'Duration',
        duration: Duration(milliseconds: 272999),
      ),
    );
    expect((await dataSource.listHistory()).single.duration, 272);
    final row = await appDatabase
        .select(appDatabase.playbackHistory)
        .getSingle();
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    expect(payload['duration'], 272);
    expect(payload.containsKey('duration_ms'), isFalse);
    expect(payload.containsKey('durationMs'), isFalse);
  });

  for (final duration in [null, 0, -1, 'unknown']) {
    test(
      'legacy duration $duration stays unknown and can be backfilled',
      () async {
        SharedPreferences.setMockInitialValues({
          'player_play_history_v1': jsonEncode([
            {
              'id': 'legacy',
              'title': 'Legacy',
              'playedAt': 123,
              'duration': ?duration,
            },
          ]),
        });
        const dataSource = PlayerHistoryDataSource();
        expect((await dataSource.listHistory()).single.duration, isNull);
        expect(
          await dataSource.updateTrackDuration(
            const PlayerTrack(
              id: 'legacy',
              title: 'Legacy',
              duration: Duration(seconds: 272),
            ),
          ),
          isTrue,
        );
        final item = (await dataSource.listHistory()).single;
        expect(item.duration, 272);
        expect(item.playedAt, 123);
      },
    );
  }

  test(
    'conditional SQL updates duration once without moving history',
    () async {
      const dataSource = PlayerHistoryDataSource();
      const track = PlayerTrack(id: 'same-id', title: 'QQ', platform: 'qq');
      await dataSource.appendTrack(track);
      await dataSource.appendTrack(
        const PlayerTrack(
          id: 'newer',
          title: 'Newer',
          duration: Duration(seconds: 100),
        ),
      );
      await dataSource.appendTrack(
        const PlayerTrack(
          id: 'same-id',
          title: 'Other platform',
          platform: 'netease',
        ),
      );
      final before = await dataSource.listHistory();
      final rowsBefore = await appDatabase
          .select(appDatabase.playbackHistory)
          .get();
      await appDatabase.customStatement(
        'CREATE TEMP TABLE history_writes (track_key TEXT)',
      );
      await appDatabase.customStatement('''
      CREATE TEMP TRIGGER count_history_updates
      AFTER UPDATE ON playback_history BEGIN
        INSERT INTO history_writes VALUES (NEW.track_key);
      END
    ''');

      final resolved = track.copyWith(
        duration: const Duration(milliseconds: 272999),
      );
      expect(await dataSource.updateTrackDuration(resolved), isTrue);
      expect(
        await dataSource.updateTrackDuration(
          track.copyWith(duration: const Duration(seconds: 272)),
        ),
        isFalse,
      );
      expect(await dataSource.updateTrackDuration(track), isFalse);
      expect(
        await dataSource.updateTrackDuration(
          track.copyWith(duration: Duration.zero),
        ),
        isFalse,
      );
      expect(
        await dataSource.updateTrackDuration(
          const PlayerTrack(
            id: 'missing',
            title: 'Missing',
            duration: Duration(seconds: 272),
          ),
        ),
        isFalse,
      );

      final after = await dataSource.listHistory();
      expect(
        after.map((item) => (item.id, item.platform)),
        before.map((item) => (item.id, item.platform)),
      );
      expect(
        after.map((item) => item.playedAt),
        before.map((item) => item.playedAt),
      );
      expect(after.last.duration, 272);
      expect(after.first.duration, isNull);
      final rowsAfter = await appDatabase
          .select(appDatabase.playbackHistory)
          .get();
      expect(
        {for (final row in rowsAfter) row.trackKey: row.playedAt},
        {for (final row in rowsBefore) row.trackKey: row.playedAt},
      );
      final oldPayload =
          jsonDecode(
                rowsBefore
                    .firstWhere((row) => row.trackKey == 'same-id|qq')
                    .payload,
              )
              as Map<String, dynamic>;
      final newPayload =
          jsonDecode(
                rowsAfter
                    .firstWhere((row) => row.trackKey == 'same-id|qq')
                    .payload,
              )
              as Map<String, dynamic>;
      expect(newPayload..remove('duration'), oldPayload);
      final writes = await appDatabase
          .customSelect('SELECT COUNT(*) AS count FROM history_writes')
          .getSingle();
      expect(writes.read<int>('count'), 1);

      await dataSource.clearHistory();
      expect(await dataSource.updateTrackDuration(resolved), isFalse);
      expect(await dataSource.listHistory(), isEmpty);
    },
  );

  test(
    'unknown replay keeps known duration while refreshing metadata',
    () async {
      const dataSource = PlayerHistoryDataSource();
      const track = PlayerTrack(
        id: 'duration',
        title: 'Old',
        duration: Duration(seconds: 272),
      );
      await dataSource.appendTrack(track);
      for (final duration in [
        null,
        Duration.zero,
        const Duration(seconds: -1),
      ]) {
        await dataSource.appendTrack(
          PlayerTrack(id: track.id, title: 'Updated', duration: duration),
        );
        final item = (await dataSource.listHistory()).single;
        expect(item.title, 'Updated');
        expect(item.duration, 272);
      }
      await dataSource.appendTrack(
        track.copyWith(duration: const Duration(seconds: 280)),
      );
      expect((await dataSource.listHistory()).single.duration, 280);
    },
  );

  test('appendTrack should increase history count', () async {
    const dataSource = PlayerHistoryDataSource();
    final count = await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );

    expect(count, 1);
    expect(await dataSource.getCount(), 1);
  });

  test('appendTrack should deduplicate same track key', () async {
    const dataSource = PlayerHistoryDataSource();
    const track = PlayerTrack(
      id: 'song-2',
      title: 'Song 2',
      artist: 'Artist 2',
      url: 'https://example.com/2.mp3',
    );

    await dataSource.appendTrack(track);
    final count = await dataSource.appendTrack(track);

    expect(count, 1);
    expect(await dataSource.getCount(), 1);
  });

  test('listHistory should keep latest track first', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-2',
        title: 'Song 2',
        artist: 'Artist 2',
        url: 'https://example.com/2.mp3',
      ),
    );

    final list = await dataSource.listHistory();
    expect(list.length, 2);
    expect(list.first.id, 'song-2');
  });

  test('clearHistory should remove all items', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-1',
        title: 'Song 1',
        artist: 'Artist 1',
        url: 'https://example.com/1.mp3',
      ),
    );

    await dataSource.clearHistory();

    expect(await dataSource.getCount(), 0);
    expect(await dataSource.listHistory(), isEmpty);
  });

  test('appendTrack should persist radio context', () async {
    const dataSource = PlayerHistoryDataSource();
    await dataSource.appendTrack(
      const PlayerTrack(
        id: 'song-radio-1',
        title: 'Radio Song',
        artist: 'Artist 1',
        url: 'https://example.com/radio.mp3',
        platform: 'qq',
      ),
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 3,
      previousPlayModeBeforeRadio: PlayerPlayMode.shuffle,
    );

    final list = await dataSource.listHistory();
    expect(list.single.isRadioMode, isTrue);
    expect(list.single.currentRadioId, 'radio-1');
    expect(list.single.currentRadioPlatform, 'qq');
    expect(list.single.currentRadioPageIndex, 3);
    expect(list.single.previousPlayModeBeforeRadio, PlayerPlayMode.shuffle);
  });
}

class _HistoryQueryLog extends QueryInterceptor {
  final statements = <String>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement.trim());
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement.trim());
    return super.runUpdate(executor, statement, args);
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    statements.add('BEGIN');
    return super.beginTransaction(parent);
  }
}
