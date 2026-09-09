import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_candidate.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/lyrics/presentation/pages/lyric_search_page.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';

const _track = PlayerTrack(
  id: 'original',
  title: 'Song',
  artist: 'Artist',
  platform: 'B',
  duration: Duration(seconds: 279),
);
const _candidate = LyricCandidate(
  platform: 'A',
  id: 'composite|id',
  name: 'Candidate',
  artistNames: ['Artist'],
  duration: 279,
);
void main() {
  late Directory root;
  late LyricStore store;
  late _Api api;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('search-lyric-test');
    store = LyricStore(
      manualDirectory: () async => Directory('${root.path}/manual'),
      automaticDirectory: () async => Directory('${root.path}/auto'),
    );
    api = _Api();
  });
  tearDown(() async => root.delete(recursive: true));
  Widget app({PlayerTrack target = _track, bool emptyPlatforms = false}) =>
      ProviderScope(
        overrides: [
          onlineApiClientProvider.overrideWithValue(api),
          lyricStoreProvider.overrideWithValue(store),
          onlinePlatformsProvider.overrideWith(
            () => _Platforms(emptyPlatforms),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LyricSearchPage(target: target),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
  Future<void> open(
    WidgetTester tester, {
    PlayerTrack target = _track,
    bool emptyPlatforms = false,
  }) async {
    await tester.pumpWidget(
      app(target: target, emptyPlatforms: emptyPlatforms),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pump();
  }

  testWidgets(
    'platform order and current platform preference; stale A B A searches never overwrite latest result',
    (tester) async {
      await open(tester);
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(chips.map((c) => (c.label as Text).data), ['A', 'B']);
      expect(chips.last.selected, isTrue);
      await tester.tap(find.widgetWithText(ChoiceChip, 'A'));
      await tester.pump();
      await search(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.pump();
      await search(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'A'));
      await tester.pump();
      await search(tester);
      expect(api.calls, ['A', 'B']);
      expect(api.lastDuration, 279);
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsOneWidget);
      api.pending['B']!.complete([
        const LyricCandidate(
          platform: 'B',
          id: 'old',
          name: 'Old result',
          artistNames: [],
          duration: 0,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Old result'), findsNothing);
      expect(find.text('Candidate'), findsOneWidget);
    },
  );

  testWidgets(
    'input edits invalidate pending results and missing artist is never replaced with a placeholder',
    (tester) async {
      await open(
        tester,
        target: const PlayerTrack(
          id: 'local',
          title: 'Song',
          artist: '未知歌手',
          platform: 'local',
        ),
      );
      await search(tester);
      expect(api.calls, isEmpty);
      expect(find.text('请补齐歌名和歌手'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Artist');
      await search(tester);
      expect(api.lastDuration, 0);
      await tester.enterText(find.byType(TextField).first, 'New name');
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsNothing);
    },
  );

  testWidgets('no capable platforms has explicit empty state', (tester) async {
    await open(tester, emptyPlatforms: true);
    expect(find.text('暂无可用的歌词搜索平台'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets(
    'clear during candidate fetch prevents stale save and leaves search open',
    (tester) async {
      await open(tester);
      await search(tester);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Candidate'));
      await tester.pump();
      await tester.runAsync(() async {
        await store.clearManual();
        api.candidate.complete(const RawLyricBundle(lyric: '[00:00.00]chosen'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LyricSearchPage), findsOneWidget);
      expect(
        await tester.runAsync(
          () => store.hasManual(
            const LyricRequest(trackId: 'original', platform: 'B'),
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'candidate success saves original target identity and closes route',
    (tester) async {
      await open(tester);
      await search(tester);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Candidate'));
      await tester.pump();
      api.candidate.complete(
        const RawLyricBundle(
          lyric: '[00:00.00]chosen',
          romanization: '[00:00.00]roma',
        ),
      );
      for (
        var i = 0;
        i < 100 && find.byType(LyricSearchPage).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(LyricSearchPage), findsNothing);
      final saved = await tester.runAsync(
        () => store.read(
          const LyricRequest(trackId: 'original', platform: 'B'),
          manual: true,
        ),
      );
      expect(saved!.romanization, '[00:00.00]roma');
      expect(
        await tester.runAsync(
          () => store.hasManual(
            const LyricRequest(trackId: 'composite|id', platform: 'A'),
          ),
        ),
        isFalse,
      );
    },
  );
}

class _Platforms extends OnlinePlatformsController {
  _Platforms(this.empty);
  final bool empty;
  @override
  Future<List<OnlinePlatform>> build() async => empty
      ? []
      : [
          for (final id in ['A', 'B', 'unavailable'])
            OnlinePlatform(
              id: id,
              name: id,
              shortName: id,
              status: id == 'unavailable' ? 0 : 1,
              featureSupportFlag: PlatformFeatureSupportFlag.searchLyric,
            ),
          OnlinePlatform(
            id: 'song-only',
            name: 'song-only',
            shortName: 'song-only',
            status: 1,
            featureSupportFlag: PlatformFeatureSupportFlag.searchLyricSong,
          ),
        ];
}

class _Api extends OnlineApiClient {
  _Api() : super(Dio());
  final calls = <String>[];
  final pending = <String, Completer<List<LyricCandidate>>>{};
  final candidate = Completer<RawLyricBundle>();
  int? lastDuration;
  @override
  Future<List<LyricCandidate>> searchLyricCandidates({
    required String platform,
    required String name,
    required List<String> artistNames,
    String albumName = '',
    int duration = 0,
  }) {
    calls.add(platform);
    lastDuration = duration;
    return (pending[platform] = Completer<List<LyricCandidate>>()).future;
  }

  @override
  Future<RawLyricBundle> fetchLyricCandidate(LyricCandidate candidate) =>
      this.candidate.future;
}
