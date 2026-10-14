import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/domain/repositories/local_music_repository.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_album_detail_page.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_artist_detail_page.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:he_music_flutter/features/music_library/presentation/widgets/local_song_list_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  for (final artist in [true, false]) {
    testWidgets(
      '${artist ? 'artist' : 'album'} detail ignores brightness but updates songs and locale',
      (tester) async {
        final songs = StreamController<List<LocalSong>>();
        addTearDown(songs.close);
        final repository = _TestLocalMusicRepository(songs.stream);
        final page = artist
            ? const LocalArtistDetailPage(artistName: '歌手')
            : const LocalAlbumDetailPage(albumName: '专辑');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(_TestAppConfigController.new),
              localMusicRepositoryProvider.overrideWithValue(repository),
              playerControllerProvider.overrideWith(_TestPlayerController.new),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              supportedLocales: const [Locale('zh'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: page,
            ),
          ),
        );
        await tester.pump();
        songs.add(const [_song]);
        await tester.pumpAndSettle();
        final row = tester.widget<LocalSongListItem>(
          find.byType(LocalSongListItem),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byWidget(page)),
        );
        final config =
            container.read(appConfigProvider.notifier)
                as _TestAppConfigController;
        for (var index = 0; index < 10; index++) {
          config.setLyricPhotoBrightness(0.9 - index * 0.01, persist: false);
          await tester.pump();
          expect(
            tester.widget<LocalSongListItem>(find.byType(LocalSongListItem)),
            same(row),
          );
        }
        expect(repository.watchCount, 1);
        songs.add(const []);
        await tester.pumpAndSettle();
        expect(find.byType(LocalSongListItem), findsNothing);
        expect(find.text(artist ? '暂无歌手信息' : '暂无专辑信息'), findsOneWidget);
        config.updateLocale('en');
        await tester.pump();
        expect(
          find.text(artist ? 'No artist data' : 'No album data'),
          findsOneWidget,
        );
        expect(repository.watchCount, 1);
      },
    );
  }
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');

  void updateLocale(String locale) =>
      state = state.copyWith(localeCode: locale);
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);
}

class _TestLocalMusicRepository implements LocalMusicRepository {
  _TestLocalMusicRepository(this.songs);

  final Stream<List<LocalSong>> songs;
  int watchCount = 0;

  @override
  Stream<List<LocalSong>> watchSongsByArtist(String artistName) {
    watchCount++;
    return songs;
  }

  @override
  Stream<List<LocalSong>> watchSongsByAlbum(String albumName) {
    watchCount++;
    return songs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _song = LocalSong(
  id: 'local-song',
  title: '歌曲',
  artist: '歌手',
  album: '专辑',
  filePath: '/tmp/song.mp3',
  duration: Duration(minutes: 3),
  mimeType: 'audio/mpeg',
  size: 1024,
);
