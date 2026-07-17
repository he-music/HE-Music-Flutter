import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_content.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_page_chunk.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_request.dart';
import 'package:he_music_flutter/features/artist/domain/repositories/artist_detail_repository.dart';
import 'package:he_music_flutter/features/artist/presentation/pages/artist_detail_page.dart';
import 'package:he_music_flutter/features/artist/presentation/providers/artist_detail_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';

void main() {
  testWidgets(
    'artist detail albums tab shows english no more text for en locale',
    (tester) async {
      final repository = _PagedArtistDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(
              () => _TestAppConfigController(localeCode: 'en'),
            ),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(repository),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'en',
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: 'Artist',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Albums'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      repository.completeSecondAlbumPage();
      await tester.pump();

      expect(find.text('No more'), findsOneWidget);
    },
  );

  testWidgets('artist detail reuses songs from detail payload on first paint', (
    tester,
  ) async {
    final repository = _TestArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(repository.fetchSongsCallCount, 0);
    expect(find.text('首屏歌曲'), findsOneWidget);
  });

  testWidgets('artist albums tab shows first page before later pages finish', (
    tester,
  ) async {
    final repository = _PagedArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('专辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('第一页专辑'), findsOneWidget);
    expect(find.text('第二页专辑'), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);

    repository.completeSecondAlbumPage();
    await tester.pump();

    expect(find.text('第二页专辑'), findsOneWidget);
  });

  testWidgets(
    'artist detail favorite action uses white icon theme when expanded',
    (tester) async {
      const themeIconColor = Colors.teal;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            artistDetailRepositoryProvider.overrideWithValue(
              _TestArtistDetailRepository(),
            ),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            theme: ThemeData(
              iconTheme: const IconThemeData(color: themeIconColor),
            ),
            child: const ArtistDetailPage(
              id: 'artist-1',
              platform: 'qq',
              title: '测试歌手',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final iconElement = tester.element(
        find.byIcon(Icons.favorite_border_rounded).first,
      );
      expect(IconTheme.of(iconElement).color, Colors.white);
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-expanded-title'),
        ),
        1,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-collapsed-title'),
        ),
        0,
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pump();

      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-expanded-title'),
        ),
        0,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('artist-detail-collapsed-title'),
        ),
        greaterThan(0),
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
      await tester.pumpAndSettle();

      final overlayStyle = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byWidgetPredicate(
              (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
            ),
          )
          .last
          .value;
      expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
      expect(overlayStyle.statusBarBrightness, Brightness.light);
    },
  );

  testWidgets('artist songs batch mode clears when leaving songs tab', (
    tester,
  ) async {
    final repository = _TestArtistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          artistDetailRepositoryProvider.overrideWithValue(repository),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: _buildTestApp(
          localeCode: 'zh',
          child: const ArtistDetailPage(
            id: 'artist-1',
            platform: 'qq',
            title: '测试歌手',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('批量操作'));
    await tester.pump();
    await tester.tap(find.text('首屏歌曲'));
    await tester.pump();

    expect(find.text('已选 1 首'), findsOneWidget);

    await tester.tap(find.text('专辑'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 首'), findsNothing);
  });
}

double _nearestOpacity(WidgetTester tester, Key key) {
  final element = tester.element(find.byKey(key));
  double? opacity;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Opacity) {
      opacity = widget.opacity;
      return false;
    }
    return true;
  });
  return opacity!;
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({this.localeCode = 'zh'});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: localeCode);
  }
}

Widget _buildTestApp({
  required String localeCode,
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: Locale(localeCode),
    supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: theme,
    home: child,
  );
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _TestArtistDetailRepository implements ArtistDetailRepository {
  int fetchDetailCallCount = 0;
  int fetchSongsCallCount = 0;

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    fetchDetailCallCount += 1;
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: 'desc',
        mvCount: '1',
        songCount: '1',
        albumCount: '0',
        alias: '',
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
          sublist: <SongInfo>[],
          originalType: 0,
        ),
      ],
    );
  }

  @override
  Future<List<AlbumInfo>> fetchAlbums(ArtistDetailRequest request) async {
    return const <AlbumInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    return const ArtistDetailPageChunk<AlbumInfo>(
      items: <AlbumInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }

  @override
  Future<List<SongInfo>> fetchSongs(ArtistDetailRequest request) async {
    fetchSongsCallCount += 1;
    return const <SongInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<SongInfo>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    fetchSongsCallCount += 1;
    return const ArtistDetailPageChunk<SongInfo>(
      items: <SongInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }

  @override
  Future<List<MvInfo>> fetchVideos(ArtistDetailRequest request) async {
    return const <MvInfo>[];
  }

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    return const ArtistDetailPageChunk<MvInfo>(
      items: <MvInfo>[],
      hasMore: false,
      nextPageIndex: 2,
    );
  }
}

class _PagedArtistDetailRepository extends _TestArtistDetailRepository {
  final Completer<ArtistDetailPageChunk<AlbumInfo>> _secondAlbumPageCompleter =
      Completer<ArtistDetailPageChunk<AlbumInfo>>();

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    return ArtistDetailContent(
      info: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: 'desc',
        mvCount: '1',
        songCount: '1',
        albumCount: '2',
        alias: '',
      ),
      songs: const <SongInfo>[
        SongInfo(
          name: '首屏歌曲',
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
          sublist: <SongInfo>[],
          originalType: 0,
        ),
      ],
    );
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    if (pageIndex == 1) {
      return ArtistDetailPageChunk<AlbumInfo>(
        items: <AlbumInfo>[_buildAlbum(id: 'album-1', name: '第一页专辑')],
        hasMore: true,
        nextPageIndex: 2,
      );
    }
    return _secondAlbumPageCompleter.future;
  }

  void completeSecondAlbumPage() {
    if (_secondAlbumPageCompleter.isCompleted) {
      return;
    }
    _secondAlbumPageCompleter.complete(
      ArtistDetailPageChunk<AlbumInfo>(
        items: <AlbumInfo>[_buildAlbum(id: 'album-2', name: '第二页专辑')],
        hasMore: false,
        nextPageIndex: 3,
      ),
    );
  }

  AlbumInfo _buildAlbum({required String id, required String name}) {
    return AlbumInfo(
      name: name,
      id: id,
      cover: '',
      artists: const <SongInfoArtistInfo>[
        SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
      ],
      songCount: '10',
      publishTime: '2024-01-01',
      songs: const <SongInfo>[],
      description: '',
      platform: 'qq',
      language: '',
      genre: '',
      type: 0,
      isFinished: true,
      playCount: '0',
    );
  }
}
