import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/helpers/local_song_playback_helper.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';

void main() {
  testWidgets(
    'batch queues preserve disk artwork paths without loading image bytes',
    (tester) async {
      final extractor = _Artwork();
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localArtworkExtractorProvider.overrideWithValue(extractor),
          ],
          child: Consumer(
            builder: (_, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      final songs = List.generate(
        1000,
        (index) => LocalSong(
          id: '$index',
          title: 'song $index',
          filePath: '/music/$index.mp3',
          artist: 'artist',
          album: 'album',
          duration: const Duration(minutes: 3),
          mimeType: 'audio/mpeg',
          size: 100,
          hasArtwork: index != 0,
        ),
      );
      final tracks = await localSongsToTracks(widgetRef, songs);
      expect(extractor.directoryReads, 1);
      expect(extractor.artworkReads, 0);
      expect(tracks, hasLength(1000));
      expect(tracks.first.artworkUrl, isNull);
      expect(
        tracks[1].artworkUrl,
        LocalArtworkExtractor.artworkPath('/cached/artwork', '/music/1.mp3'),
      );
      expect(
        tracks.last.artworkUrl,
        LocalArtworkExtractor.artworkPath('/cached/artwork', '/music/999.mp3'),
      );
      expect(tracks.every((track) => track.artworkBytes == null), isTrue);
      final noArtwork = await localSongsToTracks(widgetRef, [songs.first]);
      expect(noArtwork.single.artworkUrl, isNull);
      expect(extractor.directoryReads, 1);
    },
  );
}

class _Artwork implements LocalArtworkExtractor {
  int directoryReads = 0;
  int artworkReads = 0;
  @override
  Future<String> get artworkDir async {
    directoryReads++;
    return '/cached/artwork';
  }

  @override
  Future<List<int>?> getArtworkBytes(String filePath) async {
    artworkReads++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
