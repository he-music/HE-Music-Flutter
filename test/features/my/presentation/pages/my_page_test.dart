import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_overview_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style my page owns account and settings navigation', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.my,
        routes: [
          GoRoute(
            path: AppRoutes.my,
            builder: (_, _) => const Scaffold(body: MyPage()),
          ),
          for (final path in [
            AppRoutes.settingsProfile,
            AppRoutes.settingsDevice,
            AppRoutes.settings,
            AppRoutes.about,
          ])
            GoRoute(
              path: path,
              builder: (_, _) => const Scaffold(body: Text('Destination')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(style: style, router: router));
      await tester.pumpAndSettle();
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('@tester'), findsOneWidget);
      for (final label in [
        'Play History',
        'Local Songs',
        'Downloads',
        'Collections',
        'Created',
        'Favorites',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.byTooltip('New Playlist'), findsNothing);
      for (final entry in [
        ('Profile', AppRoutes.settingsProfile),
        ('Device Management', AppRoutes.settingsDevice),
        ('Settings', AppRoutes.settings),
        ('About', AppRoutes.about),
      ]) {
        await tester.ensureVisible(find.text(entry.$1));
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, entry.$2);
        router.pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$style guest keeps sign in and hides account management', (
      tester,
    ) async {
      await tester.pumpWidget(_app(style: style, signedIn: false));
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Device Management'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });
  }

  testWidgets('my page responds to locale and authentication changes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: 'zh'));
    await tester.pumpAndSettle();
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('设备管理'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyPage)),
    );
    final controller = container.read(appConfigProvider.notifier) as _Config;
    controller.update(
      container.read(appConfigProvider).copyWith(localeCode: 'en'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('个人资料'), findsNothing);
    controller.update(
      container.read(appConfigProvider).copyWith(clearToken: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Tester'), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('photo brightness changes do not rebuild my page content', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final list = find
        .descendant(of: find.byType(MyPage), matching: find.byType(ListView))
        .first;
    final original = tester.widget(list);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyPage)),
    );
    for (var i = 0; i < 10; i++) {
      container
          .read(appConfigProvider.notifier)
          .setLyricPhotoBrightness(0.9 - i * 0.01, persist: false);
      await tester.pump();
      expect(tester.widget(list), same(original));
    }
  });

  for (final locale in ['zh', 'en']) {
    testWidgets('my page fits large text in $locale on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(locale: locale, textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('my page shows only the account skeleton while loading', (
    tester,
  ) async {
    await tester.pumpWidget(_app(loading: true));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('my-account-loading-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('my-playlist-shelf-loading-skeleton')),
      findsNothing,
    );
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Tester'), findsNothing);
  });

  testWidgets('account identity and title keep their typography constraints', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final label in ['Tester', '@tester']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(
      tester.widget<Text>(find.text('My')).style?.fontWeight,
      FontWeight.w500,
    );
  });
}

Widget _app({
  AppUiStyle style = AppUiStyle.material,
  bool signedIn = true,
  bool loading = false,
  String locale = 'en',
  TextScaler textScaler = TextScaler.noScaling,
  GoRouter? router,
}) {
  final theme = AppTheme.light(citySoundCreatorSkin(), uiStyle: style);
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(() => _Config(locale, signedIn)),
      myOverviewControllerProvider.overrideWith(() => _Overview(loading)),
      myCreatedPlaylistsProvider.overrideWith(
        (_) => throw StateError('My must not load playlists'),
      ),
      myFavoritePlaylistsProvider.overrideWith(
        (_) => throw StateError('My must not load favorites'),
      ),
    ],
    child: router == null
        ? MaterialApp(
            theme: theme,
            builder: builder,
            home: const Scaffold(body: MyPage()),
          )
        : MaterialApp.router(
            theme: theme,
            builder: builder,
            routerConfig: router,
          ),
  );
}

class _Config extends AppConfigController {
  _Config(this.locale, this.signedIn);
  final String locale;
  final bool signedIn;

  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: locale,
    authToken: signedIn ? 'token' : '',
  );

  void update(AppConfigState config) => state = config;
}

class _Overview extends MyOverviewController {
  _Overview(this.loading);
  final bool loading;

  @override
  MyOverviewState build() => loading
      ? MyOverviewState.initial
      : const MyOverviewState(
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

  @override
  Future<void> refresh() async {}
}
