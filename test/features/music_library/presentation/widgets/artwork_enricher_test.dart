import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:he_music_flutter/features/music_library/presentation/widgets/artwork_enricher.dart';

void main() {
  testWidgets(
    'completed covers appear before the list finishes in one frame update',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app(List.generate(6, _song)));
      expect(harness.extractor.requests, hasLength(3));
      final initialBuilds = harness.builds;

      for (var index = 0; index < 3; index++) {
        harness.extractor.complete('/song$index.mp3', [index + 1]);
      }
      await tester.idle();
      await tester.pump();

      expect(harness.extractor.requests, hasLength(6));
      expect(harness.extractor.maxActive, 3);
      expect(
        harness.songs.take(3).every((song) => song.artworkBytes != null),
        isTrue,
      );
      expect(
        harness.songs.skip(3).every((song) => song.artworkBytes == null),
        isTrue,
      );
      expect(harness.builds, initialBuilds + 1);

      harness.extractor.complete('/song3.mp3', [4]);
      await tester.idle();
      await tester.pump();
      expect(harness.songs[3].artworkBytes, [4]);
      expect(harness.songs[4].artworkBytes, isNull);
      await harness.close(tester);
    },
  );

  testWidgets('metadata updates preserve completed covers and pending reads', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app([_song(0), _song(1)]));
    harness.extractor.complete('/song0.mp3', [1]);
    await tester.idle();
    await tester.pump();

    await tester.pumpWidget(
      harness.app([
        _song(0, title: 'updated first'),
        _song(1, title: 'updated second'),
      ]),
    );
    expect(harness.extractor.requests, hasLength(2));
    expect(harness.songs.first.title, 'updated first');
    expect(harness.songs.first.artworkBytes, [1]);

    harness.extractor.complete('/song1.mp3', [2]);
    await tester.idle();
    await tester.pump();
    expect(harness.songs.last.title, 'updated second');
    expect(harness.songs.last.artworkBytes, [2]);
    expect(harness.extractor.requests, hasLength(2));
    await harness.close(tester);
  });

  testWidgets('changed file paths reject late reads for the same song id', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app([_song(0)]));
    await tester.pumpWidget(
      harness.app([_song(0, path: '/replacement.mp3', title: 'replacement')]),
    );
    harness.extractor.complete('/song0.mp3', [1]);
    await tester.idle();
    await tester.pump();
    expect(harness.songs.single.artworkBytes, isNull);

    harness.extractor.complete('/replacement.mp3', [2]);
    await tester.idle();
    await tester.pump();
    expect(harness.songs.single.title, 'replacement');
    expect(harness.songs.single.artworkBytes, [2]);
    await harness.close(tester);
  });

  testWidgets('list changes retain matching artwork and honor supplied bytes', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app([_song(0), _song(1)]));
    harness.extractor.complete('/song0.mp3', [1]);
    harness.extractor.complete('/song1.mp3', [2]);
    await tester.idle();
    await tester.pump();

    await tester.pumpWidget(harness.app([_song(1), _song(0)]));
    expect(harness.songs.map((song) => song.id), ['1', '0']);
    expect(harness.songs.first.artworkBytes, [2]);
    expect(harness.extractor.requests, hasLength(2));

    await tester.pumpWidget(
      harness.app([
        _song(1, bytes: Uint8List.fromList([9])),
        _song(0, hasArtwork: false),
      ]),
    );
    expect(harness.songs.first.artworkBytes, [9]);
    expect(harness.songs.last.artworkBytes, isNull);
    expect(harness.extractor.requests, hasLength(2));
    await harness.close(tester);
  });

  testWidgets('unreadable and empty covers do not block other rows', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app(List.generate(5, _song)));
    harness.extractor.fail('/song0.mp3');
    harness.extractor.complete('/song1.mp3', null);
    harness.extractor.complete('/song2.mp3', []);
    await tester.idle();
    await tester.pump();
    expect(harness.extractor.requests, hasLength(5));

    harness.extractor.complete('/song3.mp3', [4]);
    await tester.idle();
    await tester.pump();
    expect(harness.songs[3].artworkBytes, [4]);
    expect(
      harness.songs.take(3).every((song) => song.artworkBytes == null),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets('empty lists and existing artwork do not start reads', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app([]));
    await tester.pumpWidget(
      harness.app([
        _song(0, hasArtwork: false),
        _song(1, bytes: Uint8List.fromList([2])),
      ]),
    );
    expect(harness.extractor.requests, isEmpty);
    expect(harness.songs.last.artworkBytes, [2]);
    await harness.close(tester);
  });

  testWidgets('dispose cancels a queued publication and stops new reads', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app(List.generate(6, _song)));
    harness.extractor.complete('/song0.mp3', [1]);
    await tester.idle();
    final started = harness.extractor.requests.length;
    await harness.close(tester);
    expect(harness.extractor.requests, hasLength(started));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

LocalSong _song(
  int index, {
  String? title,
  String? path,
  bool hasArtwork = true,
  Uint8List? bytes,
}) => LocalSong(
  id: '$index',
  title: title ?? 'song $index',
  filePath: path ?? '/song$index.mp3',
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  mimeType: 'audio/mpeg',
  size: 1024,
  hasArtwork: hasArtwork,
  artworkBytes: bytes,
);

class _Harness {
  final extractor = _DeferredExtractor();
  List<LocalSong> songs = [];
  int builds = 0;

  Widget app(List<LocalSong> source) => ProviderScope(
    overrides: [localArtworkExtractorProvider.overrideWithValue(extractor)],
    child: MaterialApp(
      home: ArtworkEnricher(
        songs: source,
        builder: (context, enriched) {
          songs = enriched;
          builds++;
          return const SizedBox();
        },
      ),
    ),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (final request in extractor.requests) {
      if (!request.completer.isCompleted) request.completer.complete(null);
    }
    await tester.pump();
  }
}

class _DeferredExtractor implements LocalArtworkExtractor {
  final requests = <({String path, Completer<List<int>?> completer})>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<List<int>?> getArtworkBytes(String filePath) async {
    final completer = Completer<List<int>?>();
    requests.add((path: filePath, completer: completer));
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await completer.future;
    } finally {
      active--;
    }
  }

  void complete(String path, List<int>? bytes) => requests
      .lastWhere((request) => request.path == path)
      .completer
      .complete(bytes);

  void fail(String path) => requests
      .lastWhere((request) => request.path == path)
      .completer
      .completeError(StateError('unreadable cover'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
