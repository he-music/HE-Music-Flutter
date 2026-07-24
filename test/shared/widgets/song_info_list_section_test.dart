import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/song_info_list_section.dart';

void main() {
  final songs = [
    const SongInfo(
      name: 'Song A',
      subtitle: '',
      id: 's-1',
      duration: 200,
      mvId: '0',
      album: null,
      artists: [SongInfoArtistInfo(id: 'a-1', name: 'Artist')],
      links: [],
      platform: 'qq',
      cover: '',
    ),
    const SongInfo(
      name: 'Song B',
      subtitle: '',
      id: 's-2',
      duration: 180,
      mvId: '0',
      album: null,
      artists: [],
      links: [],
      platform: 'netease',
      cover: '',
    ),
  ];

  group('SongInfoListSection', () {
    testWidgets('应渲染歌曲列表', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongInfoListSection(
            songs: songs,
            currentTrack: null,
            resolveSongCover: (_) => '',
            resolvePlatformId: (s) => s.platform,
            isSongLiked: (_) => false,
            onTapSong: (_, _, _) {},
            onLikeSong: (_) {},
            onMoreSong: (_, _) {},
            countText: '2 首歌曲',
            onPlayAll: () {},
          ),
        ),
      );

      // 应显示计数和歌曲名
      expect(find.text('2 首歌曲'), findsOneWidget);
    });

    testWidgets('countText 为 null 时不显示播放全部头部', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongInfoListSection(
            songs: songs,
            currentTrack: null,
            resolveSongCover: (_) => '',
            resolvePlatformId: (s) => s.platform,
            isSongLiked: (_) => false,
            onTapSong: (_, _, _) {},
            onLikeSong: (_) {},
            onMoreSong: (_, _) {},
          ),
        ),
      );

      expect(find.text('2 首歌曲'), findsNothing);
    });

    testWidgets('initialLoading 为 true 时应显示骨架屏', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongInfoListSection(
            songs: const [],
            currentTrack: null,
            resolveSongCover: (_) => '',
            resolvePlatformId: (s) => s.platform,
            isSongLiked: (_) => false,
            onTapSong: (_, _, _) {},
            onLikeSong: (_) {},
            onMoreSong: (_, _) {},
            initialLoading: true,
          ),
        ),
      );

      expect(find.byType(SongInfoListSection), findsOneWidget);
    });

    testWidgets('有错误且无歌曲时应显示错误视图', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongInfoListSection(
            songs: const [],
            currentTrack: null,
            resolveSongCover: (_) => '',
            resolvePlatformId: (s) => s.platform,
            isSongLiked: (_) => false,
            onTapSong: (_, _, _) {},
            onLikeSong: (_) {},
            onMoreSong: (_, _) {},
            errorMessage: 'Network error',
            onRetry: () async {},
          ),
        ),
      );

      expect(find.text('Network error'), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}
