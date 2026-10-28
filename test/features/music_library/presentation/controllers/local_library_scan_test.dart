import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/domain/repositories/local_music_repository.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements LocalMusicRepository {
  final scan = Completer<List<LocalSong>>();
  var scanCalls = 0;
  final songs = List.generate(
    120,
    (i) => LocalSong(
      id: '$i',
      title: 'Song $i',
      filePath: '/music/$i.mp3',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      mimeType: 'audio/mpeg',
      size: 100,
    ),
  );

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<LocalSong>> scanSongs() {
    scanCalls++;
    return scan.future;
  }

  @override
  Stream<List<LocalSong>> watchSongs({
    String? searchQuery,
    String sortBy = 'title',
    bool ascending = true,
    int offset = 0,
    int limit = 50,
  }) => Stream.value(songs.skip(offset).take(limit).toList());
  @override
  Stream<List<ArtistGroup>> watchArtists() => const Stream.empty();
  @override
  Stream<List<AlbumGroup>> watchAlbums() => const Stream.empty();
  @override
  Stream<List<GenreGroup>> watchGenres() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Artwork implements LocalArtworkExtractor {
  final finished = Completer<int>();
  var cancellations = 0;
  @override
  Future<void> cancelAndWait() async {
    cancellations++;
  }

  @override
  void cancel() {
    cancellations++;
  }

  @override
  Future<int> extractAll() => finished.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'duplicate scans coalesce and artwork completion does not reset pagination',
    () async {
      final repository = _Repository();
      final artwork = _Artwork();
      final container = ProviderContainer(
        overrides: [
          localMusicRepositoryProvider.overrideWithValue(repository),
          localArtworkExtractorProvider.overrideWithValue(artwork),
        ],
      );
      addTearDown(container.dispose);
      await container.read(localLibraryControllerProvider.future);
      final controller = container.read(
        localLibraryControllerProvider.notifier,
      );
      final observedLengths = <int>[];
      container.listen(localLibraryControllerProvider, (_, next) {
        if (next.hasValue) observedLengths.add(next.requireValue.length);
      });
      final first = controller.scanLibrary();
      final second = controller.scanLibrary();
      expect(identical(first, second), isTrue);
      await _flush(container);
      expect(repository.scanCalls, 1);

      repository.scan.complete(repository.songs);
      await first;
      await _flush(container);
      expect(
        container.read(localLibraryControllerProvider).value,
        hasLength(50),
      );
      expect(observedLengths, isNot(contains(120)));
      expect(artwork.finished.isCompleted, isFalse);
      await controller.loadMore();
      await _flush(container);
      expect(
        container.read(localLibraryControllerProvider).value,
        hasLength(100),
      );

      artwork.finished.complete(1);
      await _flush(container);
      expect(
        container.read(localLibraryControllerProvider).value,
        hasLength(100),
      );
    },
  );

  test('disposing the controller cancels background extraction', () async {
    final repository = _Repository();
    final artwork = _Artwork();
    final container = ProviderContainer(
      overrides: [
        localMusicRepositoryProvider.overrideWithValue(repository),
        localArtworkExtractorProvider.overrideWithValue(artwork),
      ],
    );
    await container.read(localLibraryControllerProvider.future);
    final controller = container.read(localLibraryControllerProvider.notifier);
    final scan = controller.scanLibrary();
    repository.scan.complete(repository.songs);
    await scan;
    container.dispose();
    artwork.finished.complete(0);
    expect(artwork.cancellations, 2);
  });
}

Future<void> _flush(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}
