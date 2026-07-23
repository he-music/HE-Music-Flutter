import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/controllers/local_library_controller.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('local library search waits for user focus', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.enterText(find.byType(TextField), '歌曲');
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.close), findsOneWidget);

    await _disposePage(tester);
  });

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

    await _disposePage(tester);
  });
}

Widget _buildTestApp({LocalLibraryController Function()? controllerFactory}) {
  return ProviderScope(
    overrides: [
      localLibraryControllerProvider.overrideWith(
        controllerFactory ?? _EmptyLocalLibraryController.new,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(citySoundCreatorSkin()),
      home: const LocalLibraryPage(),
    ),
  );
}

Finder _findSkinIcon(AppSkinIconRole role) {
  return find.byWidgetPredicate(
    (widget) => widget is AppSkinIcon && widget.role == role,
  );
}

Future<void> _disposePage(WidgetTester tester) async {
  // 销毁 widget 树，触发 drift 流取消，再 pump 掉残留 timer。
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 200));
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
  Future<List<LocalSong>> build() async => _songs;

  @override
  void startWatchingSongs() {}
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
