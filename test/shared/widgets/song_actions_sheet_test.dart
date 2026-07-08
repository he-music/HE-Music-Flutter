import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

void main() {
  testWidgets('song actions sheet shows add to playlist when provided', (
    tester,
  ) async {
    var addToPlaylistTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showSongActionsSheet(
                      context: context,
                      coverUrl: null,
                      title: '测试歌曲',
                      subtitle: '测试歌手',
                      hasMv: false,
                      sourceLabel: 'QQ 音乐',
                      onPlay: () {},
                      onPlayNext: () {},
                      onAddToPlaylist: () {},
                      onAddToUserPlaylist: () {
                        addToPlaylistTapped = true;
                      },
                      onWatchMv: () {},
                      onCopySongName: () {},
                      onCopySongId: () {},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsWidgets);

    await tester.tap(find.text('Add to Playlist').last);
    await tester.pumpAndSettle();

    expect(addToPlaylistTapped, isTrue);
  });

  testWidgets('route-scoped song actions sheet closes before nested route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => child,
          routes: <RouteBase>[
            GoRoute(
              path: '/plaza',
              builder: (context, state) =>
                  const Scaffold(body: Text('plaza page')),
            ),
            GoRoute(
              path: '/detail',
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    Builder(
                      builder: (context) => FilledButton(
                        onPressed: () {
                          showSongActionsSheet(
                            context: context,
                            forceBottomSheet: true,
                            useRootNavigator: false,
                            coverUrl: null,
                            title: '测试歌曲',
                            subtitle: '测试歌手',
                            hasMv: false,
                            sourceLabel: 'QQ 音乐',
                            onPlay: () {},
                            onPlayNext: () {},
                            onAddToPlaylist: () {},
                            onWatchMv: () {},
                            onCopySongName: () {},
                            onCopySongId: () {},
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                    const Text('detail page'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('测试歌曲'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('测试歌曲'), findsNothing);
    expect(find.text('detail page'), findsOneWidget);
    expect(find.text('plaza page'), findsNothing);
  });

  testWidgets('detail shell closes root song actions sheet before route pop', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('home page')),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) => DetailPageShell(
            child: Column(
              children: <Widget>[
                Builder(
                  builder: (context) => FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        forceBottomSheet: true,
                        useRootNavigator: true,
                        coverUrl: null,
                        title: '测试歌曲',
                        subtitle: '测试歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open root sheet'),
                  ),
                ),
                const Text('detail page'),
              ],
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Open root sheet'));
    await tester.pumpAndSettle();
    expect(find.text('测试歌曲'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('测试歌曲'), findsNothing);
    expect(find.text('detail page'), findsOneWidget);
    expect(find.text('home page'), findsNothing);
  });

  testWidgets(
    'detail shell closes desktop song actions menu before route pop',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/detail',
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('home page')),
          ),
          GoRoute(
            path: '/detail',
            builder: (context, state) => DetailPageShell(
              child: Column(
                children: <Widget>[
                  Builder(
                    builder: (context) => FilledButton(
                      onPressed: () {
                        showSongActionsSheet(
                          context: context,
                          coverUrl: null,
                          title: '桌面歌曲',
                          subtitle: '桌面歌手',
                          hasMv: false,
                          sourceLabel: 'QQ 音乐',
                          onPlay: () {},
                          onPlayNext: () {},
                          onAddToPlaylist: () {},
                          onWatchMv: () {},
                          onCopySongName: () {},
                          onCopySongId: () {},
                        );
                      },
                      child: const Text('Open desktop sheet'),
                    ),
                  ),
                  const Text('detail page'),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      );

      await tester.tap(find.text('Open desktop sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.byType(PopupMenuItem<VoidCallback>), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsNothing);
      expect(find.text('detail page'), findsOneWidget);
      expect(find.text('home page'), findsNothing);
    },
  );

  testWidgets('song actions sheet shows view detail only when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onViewDetail: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open with detail'),
                  ),
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '本地歌曲',
                        subtitle: '本地歌手',
                        hasMv: false,
                        sourceLabel: '本地',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open without detail'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open with detail'));
    await tester.pumpAndSettle();
    expect(find.text('View Detail'), findsOneWidget);

    Navigator.of(tester.element(find.text('View Detail'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open without detail'));
    await tester.pumpAndSettle();
    expect(find.text('View Detail'), findsNothing);
  });

  testWidgets('song actions sheet uses view comments label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showSongActionsSheet(
                      context: context,
                      coverUrl: null,
                      title: '在线歌曲',
                      subtitle: '在线歌手',
                      hasMv: false,
                      sourceLabel: 'QQ 音乐',
                      onPlay: () {},
                      onPlayNext: () {},
                      onAddToPlaylist: () {},
                      onWatchMv: () {},
                      onViewComment: () {},
                      onCopySongName: () {},
                      onCopySongId: () {},
                    );
                  },
                  child: const Text('Open with comments'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open with comments'));
    await tester.pumpAndSettle();

    expect(find.text('View Comments'), findsOneWidget);
    expect(find.text('Comments'), findsNothing);
  });

  testWidgets('song actions sheet shows download action only when provided', (
    tester,
  ) async {
    var downloadTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                        onDownload: () {
                          downloadTapped = true;
                        },
                      );
                    },
                    child: const Text('Open online'),
                  ),
                  FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '本地歌曲',
                        subtitle: '本地歌手',
                        hasMv: false,
                        sourceLabel: '本地',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open local'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open online'));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(downloadTapped, isTrue);

    await tester.tap(find.text('Open local'));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  testWidgets(
    'song actions sheet uses custom play action label when provided',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '测试歌曲',
                        subtitle: '测试歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        playActionLabel: '暂停',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open custom play'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open custom play'));
      await tester.pumpAndSettle();

      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
    },
  );

  testWidgets('song actions uses anchored context menu on desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: Builder(
                    builder: (buttonContext) => FilledButton(
                      onPressed: () {
                        showSongActionsSheet(
                          context: context,
                          anchorContext: buttonContext,
                          coverUrl: null,
                          title: '桌面歌曲',
                          subtitle: '桌面歌手',
                          hasMv: false,
                          sourceLabel: 'QQ 音乐',
                          onPlay: () {},
                          onPlayNext: () {},
                          onAddToPlaylist: () {},
                          onWatchMv: () {},
                          onCopySongName: () {},
                          onCopySongId: () {},
                        );
                      },
                      child: const Text('Open desktop'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open desktop'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PopupMenuItem<VoidCallback>), findsWidgets);
    expect(find.text('Play'), findsOneWidget);

    final triggerCenter = tester.getCenter(find.text('Open desktop'));
    final popupTopLeft = tester.getTopLeft(find.text('Play'));
    expect(popupTopLeft.dx, greaterThan(triggerCenter.dx - 160));
    expect(popupTopLeft.dy, greaterThan(triggerCenter.dy - 220));
  });

  testWidgets('song actions sheet stays scrollable on small mobile heights', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 520)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: true,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onDownload: () {},
                        onAddToUserPlaylist: () {},
                        onWatchMv: () {},
                        onViewComment: () {},
                        albumActionLabel: '查看专辑',
                        onViewAlbum: () {},
                        artistActionLabel: '查看歌手',
                        onViewArtists: () {},
                        onCopySongName: () {},
                        onCopySongShareLink: () {},
                        onSearchSameName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open compact'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open compact'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('song actions sheet uses previous mobile list tile style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showSongActionsSheet(
                        context: context,
                        coverUrl: null,
                        title: '在线歌曲',
                        subtitle: '在线歌手',
                        hasMv: false,
                        sourceLabel: 'QQ 音乐',
                        onPlay: () {},
                        onPlayNext: () {},
                        onAddToPlaylist: () {},
                        onDownload: () {},
                        onWatchMv: () {},
                        onCopySongName: () {},
                        onCopySongId: () {},
                      );
                    },
                    child: const Text('Open regular'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open regular'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsWidgets);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('song actions sheet opens above shell navigator', (tester) async {
    final rootObserver = _CountingNavigatorObserver();
    final branchObserver = _CountingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[rootObserver],
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: Navigator(
                  observers: <NavigatorObserver>[branchObserver],
                  onGenerateRoute: (_) {
                    return MaterialPageRoute<void>(
                      builder: (context) => Center(
                        child: FilledButton(
                          onPressed: () {
                            showSongActionsSheet(
                              context: context,
                              coverUrl: null,
                              title: '分支歌曲',
                              subtitle: '分支歌手',
                              hasMv: false,
                              sourceLabel: 'QQ 音乐',
                              onPlay: () {},
                              onPlayNext: () {},
                              onAddToPlaylist: () {},
                              onWatchMv: () {},
                              onCopySongName: () {},
                              onCopySongId: () {},
                            );
                          },
                          child: const Text('Open in branch'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 56, child: Text('mini player')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open in branch'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(rootObserver.pushCount, 1);
    expect(branchObserver.pushCount, 0);
  });
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      pushCount += 1;
    }
    super.didPush(route, previousRoute);
  }
}
