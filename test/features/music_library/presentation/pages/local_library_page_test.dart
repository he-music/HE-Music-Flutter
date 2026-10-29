import 'dart:io';

import 'package:he_music_flutter/core/database/local_music_database.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_music_dao.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_player_scaffold.dart';
import 'package:he_music_flutter/features/music_library/data/datasources/local_artwork_extractor.dart';
import 'package:he_music_flutter/features/music_library/domain/repositories/local_music_repository.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/controllers/local_library_controller.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';
import 'package:he_music_flutter/shared/widgets/underline_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'macOS add folder stays above the mini-player at text scale $textScale',
      (tester) async {
        const playerKey = ValueKey('folder-test-mini-player');
        await tester.pumpWidget(
          AppGlassScope(
            enabled: true,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              child: _buildTestApp(
                pageBuilder: (page) => Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: AppGlassPlayerScaffold(
                      body: page,
                      miniPlayer: Builder(
                        builder: (context) => SizedBox(
                          key: playerKey,
                          height: MiniPlayerBar.heightFor(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('文件夹'));
        await tester.tap(find.text('文件夹'));
        await tester.pumpAndSettle();
        final addButton = find.ancestor(
          of: find.text('添加文件夹'),
          matching: find.byWidgetPredicate(
            (widget) => widget is OutlinedButton,
          ),
        );
        final buttonWithoutPlayer = tester.getRect(addButton);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LocalLibraryPage)),
        );
        final player = container.read(playerControllerProvider.notifier);
        await player.replaceQueue([
          PlayerTrack(
            id: 'folder-test-song',
            title: '测试歌曲',
            artist: '测试歌手',
            album: '',
            duration: const Duration(minutes: 3),
            path: '/tmp/folder-test.mp3',
          ),
        ]);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('文件夹'));
        await tester.tap(find.text('文件夹'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(addButton).bottom,
          lessThanOrEqualTo(tester.getRect(find.byKey(playerKey)).top),
        );
        expect(addButton.hitTestable(), findsOneWidget);
        await player.replaceQueue(const []);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('文件夹'));
        await tester.tap(find.text('文件夹'));
        await tester.pumpAndSettle();
        expect(tester.getRect(addButton), buttonWithoutPlayer);
        expect(tester.takeException(), isNull);
        await _disposePage(tester);
      },
      skip: !Platform.isMacOS,
    );
  }

  testWidgets(
    'multi-select plays every selected song and updates only playing rows',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(controllerFactory: _PopulatedLocalLibraryController.new),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('歌曲 A'));
      await tester.pump();
      await tester.tap(find.text('歌曲 B'));
      await tester.pump();
      await tester.tap(_findSkinIcon(AppSkinIconRole.batchPlay));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocalLibraryPage)),
      );
      final player =
          container.read(playerControllerProvider.notifier)
              as _TestPlayerController;
      expect(player.played.map((track) => track.path), [
        '/tmp/song-a.mp3',
        '/tmp/song-b.mp3',
      ]);
      expect(_songItem(tester, '歌曲 A').data.isCurrent, isTrue);
      expect(_songItem(tester, '歌曲 B').data.isCurrent, isFalse);
      final firstRow = _songItem(tester, '歌曲 A');
      final secondRow = _songItem(tester, '歌曲 B');
      player.tick();
      await tester.pump();
      expect(_songItem(tester, '歌曲 A'), same(firstRow));
      expect(_songItem(tester, '歌曲 B'), same(secondRow));
      await _disposePage(tester);
    },
  );

  testWidgets(
    'multi-select appends all songs in order without overlapping queue updates',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(controllerFactory: _PopulatedLocalLibraryController.new),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('歌曲 A'));
      await tester.pump();
      await tester.tap(find.text('歌曲 B'));
      await tester.pump();
      await tester.tap(_findSkinIcon(AppSkinIconRole.batchAddToQueue));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocalLibraryPage)),
      );
      final player =
          container.read(playerControllerProvider.notifier)
              as _TestPlayerController;
      expect(player.appended.map((track) => track.path), [
        '/tmp/song-a.mp3',
        '/tmp/song-b.mp3',
      ]);
      expect(tester.takeException(), isNull);
      await _disposePage(tester);
    },
  );

  testWidgets(
    'local sort menu uses glass and preserves the selection callback',
    (tester) async {
      final controller = _SortingLocalLibraryController();
      await tester.pumpWidget(
        AppGlassScope(
          enabled: true,
          child: GlassAdaptiveScope(
            minQuality: GlassQuality.minimal,
            maxQuality: GlassQuality.minimal,
            child: _buildTestApp(controllerFactory: () => controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(GlassMenu), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(GlassMenuItem),
          matching: find.text(SongSortBy.album.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.sortBy, SongSortBy.album);
      expect(tester.takeException(), isNull);
      await _disposePage(tester);
    },
  );

  testWidgets('local library app bar requests skin icon roles', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('本地歌曲'), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.search), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.localLibraryScan), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.localLibraryClear), findsOneWidget);

    await _disposePage(tester);
  });

  testWidgets(
    'local library search focuses immediately and back closes search',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('搜索'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.enterText(find.byType(TextField), '歌曲');
      await tester.pump();

      expect(_findSkinIcon(AppSkinIconRole.close), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('本地歌曲'), findsOneWidget);

      await _disposePage(tester);
    },
  );

  testWidgets('local library search typing does not rebuild the song tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(controllerFactory: _PopulatedLocalLibraryController.new),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    final initialTab = tester.widget<UnderlineTab>(
      find.byType(UnderlineTab).first,
    );

    await tester.enterText(find.byType(TextField), '歌');
    await tester.pump();
    expect(_findSkinIcon(AppSkinIconRole.close), findsOneWidget);
    expect(
      tester.widget<UnderlineTab>(find.byType(UnderlineTab).first),
      same(initialTab),
    );

    await tester.enterText(find.byType(TextField), '歌曲');
    await tester.pump();
    expect(
      tester.widget<UnderlineTab>(find.byType(UnderlineTab).first),
      same(initialTab),
    );

    await _disposePage(tester);
  });

  testWidgets(
    'local library search result changes still rebuild the song tree',
    (tester) async {
      final controller = _PopulatedLocalLibraryController();
      await tester.pumpWidget(
        _buildTestApp(controllerFactory: () => controller),
      );
      await tester.pumpAndSettle();
      final initialTab = tester.widget<UnderlineTab>(
        find.byType(UnderlineTab).first,
      );

      controller.replaceSongs(const <LocalSong>[_searchResultSong]);
      await tester.pump();

      expect(find.text('搜索结果'), findsOneWidget);
      expect(
        tester.widget<UnderlineTab>(find.byType(UnderlineTab).first),
        isNot(same(initialTab)),
      );

      await _disposePage(tester);
    },
  );

  testWidgets('local library selection actions request skin icon roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(controllerFactory: _PopulatedLocalLibraryController.new),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('歌曲 A'));
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.close), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.batchSelectAll), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.batchPlay), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.batchAddToQueue), findsOneWidget);

    await tester.tap(find.byTooltip('全选'));
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.batchDeselectAll), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.close), findsNothing);

    await _disposePage(tester);
  });

  testWidgets('selection toggle rebuilds only the changed song row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(controllerFactory: _PopulatedLocalLibraryController.new),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('歌曲 A'));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final songA = _songItem(tester, '歌曲 A');
    final songB = _songItem(tester, '歌曲 B');
    expect(songA.selected, isTrue);
    expect(songB.selected, isFalse);

    await tester.tap(find.text('歌曲 B'));
    await tester.pump();

    expect(tester.widget<Scaffold>(find.byType(Scaffold)), same(scaffold));
    expect(_songItem(tester, '歌曲 A'), same(songA));
    expect(_songItem(tester, '歌曲 B'), isNot(same(songB)));
    expect(_songItem(tester, '歌曲 B').selected, isTrue);

    await _disposePage(tester);
  });
}

class _TestPlayerController extends PlayerController {
  List<PlayerTrack> played = [];
  final appended = <PlayerTrack>[];
  bool _appending = false;

  @override
  Future<void> appendTrack(PlayerTrack track) async {
    if (_appending) throw StateError('overlapping queue updates');
    _appending = true;
    await Future<void>.delayed(Duration.zero);
    appended.add(track);
    _appending = false;
  }

  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);

  @override
  Future<void> replaceQueue(
    List<PlayerTrack> tracks, {
    int startIndex = 0,
    bool autoplay = true,
    PlayerQueueSource? queueSource,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    played = tracks;
    state = PlayerPlaybackState.initial(
      tracks,
    ).copyWith(currentIndex: startIndex);
  }

  void tick() => state = state.copyWith(position: const Duration(seconds: 1));
}

class _TestArtworkExtractor implements LocalArtworkExtractor {
  @override
  void cancel() {}

  @override
  Future<File?> getArtworkFile(String filePath) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLocalMusicDao implements LocalMusicDao {
  @override
  Future<List<ScanFolder>> getScanFolders(String platform) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLocalRepository implements LocalMusicRepository {
  @override
  Future<void> incrementPlayCount(String songId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp({
  LocalLibraryController Function()? controllerFactory,
  Widget Function(Widget page)? pageBuilder,
}) {
  return ProviderScope(
    overrides: [
      localMusicDaoProvider.overrideWithValue(_TestLocalMusicDao()),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      localArtworkExtractorProvider.overrideWithValue(_TestArtworkExtractor()),
      localMusicRepositoryProvider.overrideWithValue(_TestLocalRepository()),
      localLibraryControllerProvider.overrideWith(
        controllerFactory ?? _EmptyLocalLibraryController.new,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(citySoundCreatorSkin()),
      home:
          pageBuilder?.call(const LocalLibraryPage()) ??
          const LocalLibraryPage(),
    ),
  );
}

Finder _findSkinIcon(AppSkinIconRole role) {
  return find.byWidgetPredicate(
    (widget) => widget is AppSkinIcon && widget.role == role,
  );
}

SongListItem _songItem(WidgetTester tester, String title) {
  return tester.widget<SongListItem>(
    find.ancestor(of: find.text(title), matching: find.byType(SongListItem)),
  );
}

Future<void> _disposePage(WidgetTester tester) async {
  // 销毁 widget 树，触发 drift 流取消，再 pump 掉残留 timer。
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 200));
}

class _SortingLocalLibraryController extends _PopulatedLocalLibraryController {
  @override
  void changeSortBy(SongSortBy newSortBy) {
    sortBy = newSortBy;
    ref.notifyListeners();
  }
}

class _EmptyLocalLibraryController extends LocalLibraryController {
  @override
  Future<List<LocalSong>> build() async => const <LocalSong>[];

  @override
  void startWatchingSongs() {}

  @override
  void updateSearchQuery(String query) {
    searchState = LocalLibrarySearchState(isActive: true, query: query);
    ref.notifyListeners();
  }
}

class _PopulatedLocalLibraryController extends LocalLibraryController {
  @override
  Future<List<LocalSong>> build() async {
    await super.build();
    return _songs;
  }

  @override
  void startWatchingSongs() {}

  void replaceSongs(List<LocalSong> songs) {
    state = AsyncData(songs);
  }
}

const _songs = <LocalSong>[
  LocalSong(
    id: 'song-a',
    title: '歌曲 A',
    filePath: '/tmp/song-a.mp3',
    artist: '歌手 A',
    album: '专辑 A',
    duration: Duration(minutes: 3),
    mimeType: 'audio/mpeg',
    size: 1024,
  ),
  LocalSong(
    id: 'song-b',
    title: '歌曲 B',
    filePath: '/tmp/song-b.mp3',
    artist: '歌手 B',
    album: '专辑 B',
    duration: Duration(minutes: 4),
    mimeType: 'audio/mpeg',
    size: 2048,
  ),
];

const _searchResultSong = LocalSong(
  id: 'search-result',
  title: '搜索结果',
  filePath: '/tmp/search-result.mp3',
  artist: '歌手',
  album: '专辑',
  duration: Duration(minutes: 2),
  mimeType: 'audio/mpeg',
  size: 512,
);
