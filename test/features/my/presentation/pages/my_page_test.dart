import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_overview_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('my page shows chinese labels when locale is zh', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    expect(find.text('我的'), findsOneWidget);
    expect(find.byTooltip('扫描'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('播放历史'), findsOneWidget);
    expect(find.text('本地歌曲'), findsOneWidget);
    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('Tester'), findsOneWidget);
    expect(find.text('@tester'), findsOneWidget);
    expect(find.text('已登录'), findsNothing);
    expect(find.text('退出帐号'), findsNothing);
    expect(find.text('自建'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('当前没有歌单内容'), findsOneWidget);
    expect(find.byTooltip('创建歌单'), findsOneWidget);
  });

  testWidgets('my collection entry does not show favorite song count', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('8'), findsNothing);
  });

  testWidgets('my page actions request skin icon roles', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh', useCitySkin: true));
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.scan), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.settings), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.myPlaylistCreate), findsOneWidget);
  });

  testWidgets('my page title does not use bold font weight', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    final title = tester.widget<Text>(find.text('我的'));

    expect(
      title.style?.fontWeight,
      isNot(anyOf(FontWeight.w600, FontWeight.w700, FontWeight.w800)),
    );
  });

  testWidgets('my page shows english labels when locale is en', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'en'));
    await tester.pump();

    expect(find.text('My'), findsOneWidget);
    expect(find.byTooltip('Scan'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Play History'), findsOneWidget);
    expect(find.text('Local Songs'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Tester'), findsOneWidget);
    expect(find.text('@tester'), findsOneWidget);
    expect(find.text('Signed In'), findsNothing);
    expect(find.text('Sign Out'), findsNothing);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(find.byTooltip('Create Playlist'), findsOneWidget);
  });

  testWidgets('my page keeps mobile single-column layout on wide width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTestApp(localeCode: 'en'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('my-page-primary-column')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('my-page-secondary-column')),
      findsNothing,
    );
    expect(find.text('Play History'), findsOneWidget);
    expect(find.text('No playlists yet'), findsOneWidget);
  });

  testWidgets('signed out account card keeps sign in action', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh', authToken: null));
    await tester.pump();

    expect(find.text('立即登录'), findsOneWidget);
    expect(find.text('个人资料'), findsNothing);
  });

  testWidgets('my page shows account and playlist skeletons while loading', (
    tester,
  ) async {
    final playlistsCompleter = Completer<List<MyFavoriteItem>>();

    await tester.pumpWidget(
      _buildTestApp(
        localeCode: 'zh',
        overviewLoading: true,
        playlistsFuture: playlistsCompleter.future,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('my-account-loading-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('my-playlist-shelf-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.text('访客'), findsNothing);
    expect(find.text('播放历史'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    playlistsCompleter.complete(const <MyFavoriteItem>[]);
    await tester.pump();
  });

  testWidgets('account identity text is constrained to one line', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    final nickname = tester.widget<Text>(find.text('Tester'));
    final username = tester.widget<Text>(find.text('@tester'));
    expect(nickname.maxLines, 1);
    expect(nickname.overflow, TextOverflow.ellipsis);
    expect(username.maxLines, 1);
    expect(username.overflow, TextOverflow.ellipsis);
  });

  testWidgets('创建歌单弹窗点击取消后应无异常', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    await tester.tap(find.byTooltip('创建歌单'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('创建歌单弹窗点击确定后应提交名称且无异常', (tester) async {
    final apiClient = _TestOnlineApiClient();
    await tester.pumpWidget(
      _buildTestApp(localeCode: 'zh', onlineApiClient: apiClient),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('创建歌单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(apiClient.createdPlaylistNames, <String>['旅行']);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildTestApp({
  required String localeCode,
  String? authToken = 'token',
  OnlineApiClient? onlineApiClient,
  bool overviewLoading = false,
  Future<List<MyFavoriteItem>>? playlistsFuture,
  bool useCitySkin = false,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          localeCode: localeCode,
          authToken: authToken,
        ),
      ),
      myOverviewControllerProvider.overrideWith(
        overviewLoading
            ? _LoadingMyOverviewController.new
            : _TestMyOverviewController.new,
      ),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      myCreatedPlaylistsProvider.overrideWith(
        (ref) => playlistsFuture ?? Future.value(const <MyFavoriteItem>[]),
      ),
      myFavoritePlaylistsProvider.overrideWith(
        (ref) => playlistsFuture ?? Future.value(const <MyFavoriteItem>[]),
      ),
      if (onlineApiClient != null)
        onlineApiClientProvider.overrideWithValue(onlineApiClient),
    ],
    child: MaterialApp(
      theme: useCitySkin
          ? AppTheme.light(citySoundCreatorSkin())
          : ThemeData(platform: TargetPlatform.android),
      home: const Scaffold(body: MyPage()),
    ),
  );
}

Finder _findSkinIcon(AppSkinIconRole role) {
  return find.byWidgetPredicate(
    (widget) => widget is AppSkinIcon && widget.role == role,
  );
}

class _TestOnlineApiClient extends OnlineApiClient {
  _TestOnlineApiClient() : super(Dio());

  final List<String> createdPlaylistNames = <String>[];

  @override
  Future<Map<String, dynamic>> createPlaylist(String name) async {
    createdPlaylistNames.add(name);
    return const <String, dynamic>{};
  }
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.localeCode, required this.authToken});

  final String localeCode;
  final String? authToken;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      authToken: authToken,
      clearToken: authToken == null,
    );
  }
}

class _TestMyOverviewController extends MyOverviewController {
  @override
  MyOverviewState build() {
    return const MyOverviewState(
      loading: false,
      overview: MyOverview(
        profile: MyProfile(
          id: '1',
          username: 'tester',
          nickname: 'Tester',
          email: '',
          status: 1,
          avatarUrl: '',
        ),
        summary: MySummary(
          favoriteSongCount: 8,
          favoritePlaylistCount: 3,
          favoriteArtistCount: 2,
          favoriteAlbumCount: 1,
          createdPlaylistCount: 4,
        ),
      ),
    );
  }
}

class _LoadingMyOverviewController extends MyOverviewController {
  @override
  MyOverviewState build() {
    return MyOverviewState.initial;
  }

  @override
  Future<void> refresh() async {}
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(
      const <PlayerTrack>[],
    ).copyWith(historyCount: 12);
  }
}
