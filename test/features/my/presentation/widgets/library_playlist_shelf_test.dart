import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_collection_repository.dart';
import 'package:he_music_flutter/features/my/presentation/widgets/library_playlist_shelf.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final brightness in Brightness.values) {
      for (final error in [false, true]) {
        testWidgets(
          '$style $brightness shelf error=$error follows content background',
          (tester) async {
            tester.view.physicalSize = const Size(430, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final pending = error ? Completer<List<MyFavoriteItem>>() : null;
            State? pageState;
            for (final enabled in [false, true, false]) {
              final skin = citySoundCreatorSkin();
              final theme = brightness == Brightness.light
                  ? AppTheme.light(
                      skin,
                      uiStyle: style,
                      showContentBackground: enabled,
                    )
                  : AppTheme.dark(
                      skin,
                      uiStyle: style,
                      showContentBackground: enabled,
                    );
              await tester.pumpWidget(
                _buildTestApp(
                  localeCode: 'en',
                  themeOverride: theme,
                  playlistsFuture: pending?.future,
                ),
              );
              if (pending != null && !pending.isCompleted) {
                pending.completeError(StateError('Offline'));
              }
              await tester.pumpAndSettle();
              pageState ??= tester.state(find.byType(LibraryPlaylistShelf));
              expect(
                tester.state(find.byType(LibraryPlaylistShelf)),
                same(pageState),
              );
              final message = find.text(
                error ? 'Failed to load playlists' : 'No playlists yet',
              );
              expect(message, findsOneWidget);
              final card = tester.widget<Container>(
                find
                    .ancestor(of: message, matching: find.byType(Container))
                    .first,
              );
              final fill = (card.decoration as BoxDecoration).color!;
              expect(
                fill.a,
                style == AppUiStyle.cupertino && !enabled ? 0 : greaterThan(0),
              );
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  testWidgets(
    'favorites tab refreshes the shared collection after remote changes',
    (tester) async {
      final repository = _TestCollectionRepository();
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildTestApp(localeCode: 'zh', collectionRepository: repository),
      );
      await tester.pumpAndSettle();
      expect(repository.playlistFetches, 1);

      const playlist = MyFavoriteItem(
        id: 'remote',
        platform: 'qq',
        type: MyFavoriteType.playlists,
        title: '远端收藏歌单',
        subtitle: '',
        coverUrl: '',
      );
      repository.playlists = const [playlist];
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('远端收藏歌单'), findsOneWidget);
      expect(repository.playlistFetches, 2);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LibraryPlaylistShelf)),
      );
      expect(container.read(myCollectionControllerProvider).playlists, [
        playlist,
      ]);

      repository.playlists = const [];
      await container
          .read(myCollectionControllerProvider.notifier)
          .refreshAll();
      await tester.pumpAndSettle();
      expect(find.text('远端收藏歌单'), findsNothing);
      expect(find.text('当前没有歌单内容'), findsOneWidget);
      expect(repository.playlistFetches, 3);
    },
  );
  testWidgets('创建歌单弹窗点击取消后应无异常', (tester) async {
    await tester.pumpWidget(_buildTestApp(localeCode: 'zh'));
    await tester.pump();

    await tester.tap(find.byTooltip('新建歌单'));
    await tester.pumpAndSettle();
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.autofocus, isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
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

    await tester.tap(find.byTooltip('新建歌单'));
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
  OnlineApiClient? onlineApiClient,
  Future<List<MyFavoriteItem>>? playlistsFuture,
  MyCollectionRepository? collectionRepository,
  ThemeData? themeOverride,
}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWith(() => _TestAppConfigController(localeCode)),
    myCreatedPlaylistsProvider.overrideWith(
      (_) => playlistsFuture ?? Future.value(const <MyFavoriteItem>[]),
    ),
    if (collectionRepository != null)
      myCollectionRepositoryProvider.overrideWithValue(collectionRepository)
    else
      myFavoritePlaylistsProvider.overrideWith(
        (_) => const AsyncData(<MyFavoriteItem>[]),
      ),
    if (onlineApiClient != null)
      onlineApiClientProvider.overrideWithValue(onlineApiClient),
  ],
  child: MaterialApp(
    theme: themeOverride ?? ThemeData(platform: TargetPlatform.android),
    home: Scaffold(body: ListView(children: const [LibraryPlaylistShelf()])),
  ),
);

class _TestCollectionRepository implements MyCollectionRepository {
  List<MyFavoriteItem> playlists = const [];
  int playlistFetches = 0;

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) async {
    if (type == MyFavoriteType.playlists) {
      playlistFetches++;
      return playlists;
    }
    return const [];
  }

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {}
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
  _TestAppConfigController(this.localeCode);
  final String localeCode;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: localeCode,
    authToken: 'token',
  );
}
