import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

import '../../helpers/artwork_http_client.dart';

const _previewDirectory = String.fromEnvironment('GLASS_PREVIEW_DIR');
const _artworkUrl = 'https://artwork.test/evening.png';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('detail header and actions fit large text in $style', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var backCount = 0;
      var favoriteCount = 0;
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.appleBlue,
      ).resolve(AppSkinRegistry.citySoundCreatorId);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(skin, uiStyle: style),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(3.2)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                MusicDetailSliverAppBar(
                  title: 'A long album title that needs room',
                  subtitle: 'A long artist name',
                  coverUrl: '',
                  description:
                      'A description of this collection and its recordings.',
                  metaItems: const [
                    MusicDetailMetaItem(
                      label: '14 tracks',
                      icon: Icons.music_note,
                    ),
                    MusicDetailMetaItem(
                      label: '2026',
                      icon: Icons.calendar_today,
                    ),
                  ],
                  onBack: () => backCount++,
                  onShowDescription: () {},
                  actions: [
                    MusicDetailActionButton(
                      icon: const Icon(Icons.favorite_border),
                      tooltip: 'Favorite',
                      onPressed: () => favoriteCount++,
                    ),
                  ],
                ),
                SliverList.builder(
                  itemCount: 40,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 64, child: Text('Song $index')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      final header = _headerRect(tester);
      final heading = tester.getRect(
        find.byKey(const ValueKey('music-detail-expanded-title')),
      );
      expect(heading.left, header.left + 16);
      expect(heading.right, lessThanOrEqualTo(header.right - 16));
      expect(heading.bottom, lessThan(header.bottom));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      final titleFinder = find.byKey(
        const ValueKey('music-detail-collapsed-title'),
      );
      final title = tester.widget<Text>(titleFinder);
      final theme = Theme.of(tester.element(titleFinder));
      expect(title.style!.color, theme.textTheme.titleMedium!.color);
      await tester.tap(find.byTooltip('Favorite'));
      await tester.tap(find.byTooltip('Back'));
      expect(favoriteCount, 1);
      expect(backCount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'detail cover fills the header and ignores late previous artwork',
    (tester) async {
      final red = await tester.runAsync(() => _solidArtwork(Colors.red));
      final blue = await tester.runAsync(() => _solidArtwork(Colors.blue));
      final delayed = Completer<Uint8List>();
      var previews = 0;
      final client = ArtworkHttpClient(
        (uri) => uri.path.contains('slow')
            ? delayed.future
            : blue!.buffer.asUint8List(),
      );
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      final url = ValueNotifier('https://artwork.test/slow-red.png');
      addTearDown(url.dispose);
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(
              AppSkinRegistry.builtIn(
                AppThemeAccent.appleBlue,
              ).resolve(AppSkinRegistry.starlitMelodyId),
            ),
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: url,
                builder: (context, cover, _) => CustomScrollView(
                  slivers: [
                    MusicDetailSliverAppBar(
                      title: 'Album',
                      subtitle: 'Artist',
                      coverUrl: cover,
                      description: '',
                      onBack: () {},
                      onShowDescription: () {},
                      onPreviewCover: () => previews++,
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 1200)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            ResizeImage(
              const NetworkImage('https://artwork.test/ready-blue.png'),
              width: 512,
            ),
            tester.element(find.byType(Scaffold)),
          ),
        );
        await tester.pump();
        url.value = 'https://artwork.test/ready-blue.png';
        await tester.pumpAndSettle();
        final image = find.byType(Image);
        expect(image, findsOneWidget);
        final cover = tester.widget<Image>(image);
        expect(cover.fit, BoxFit.cover);
        expect(cover.alignment, Alignment.topCenter);
        expect(tester.getRect(image), _headerRect(tester));
        await tester.tapAt(_headerRect(tester).topLeft + const Offset(30, 100));
        expect(previews, 1);
        final current = tester.widget<RawImage>(find.byType(RawImage)).image;
        expect(current, isNotNull);
        delayed.complete(red!.buffer.asUint8List());
        for (var frame = 0; frame < 8; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, current);
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        if (!delayed.isCompleted) delayed.complete(red!.buffer.asUint8List());
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets('export glass music scenes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
    final bytes = await tester.runAsync(() async {
      final textFonts = FontLoader('GlassPreview');
      for (final file in [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]) {
        textFonts.addFont(
          File(
            'test/assets/fonts/$file',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await textFonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
      return File('test/assets/player/artist_photo.png').readAsBytes();
    });
    final client = ArtworkHttpClient((_) => bytes!);
    debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    for (final style in AppUiStyle.values) {
      for (final brightness in Brightness.values) {
        for (final detail in [true, false]) {
          final skin = AppSkinRegistry.builtIn(
            AppThemeAccent.appleBlue,
          ).resolve(AppSkinRegistry.starlitMelodyId);
          final theme = brightness == Brightness.light
              ? AppTheme.light(
                  skin,
                  uiStyle: style,
                  showContentBackground: true,
                )
              : AppTheme.dark(
                  skin,
                  uiStyle: style,
                  showContentBackground: true,
                );
          const capture = ValueKey('glass-scene-capture');
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'GlassPreview'),
              ),
              home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppSkinBackgroundLayer(
                        skin: skin,
                        enableAnimation: false,
                      ),
                      CustomScrollView(
                        slivers: [
                          if (detail) ...[
                            MusicDetailSliverAppBar(
                              title: 'Evening Tide',
                              subtitle: 'HE Music Collection',
                              coverUrl: _artworkUrl,
                              description:
                                  'A little room for the last light of the day.',
                              metaItems: const [
                                MusicDetailMetaItem(
                                  label: '14 tracks',
                                  icon: Icons.music_note_rounded,
                                ),
                              ],
                              onBack: () {},
                              onShowDescription: () {},
                              onPreviewCover: () {},
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: MusicDetailPlayAllHeader(
                                height: 56,
                                countText: 'Play all · 14 songs',
                                onPlayAll: () {},
                              ),
                            ),
                          ] else
                            SliverToBoxAdapter(
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    20,
                                  ),
                                  child: Builder(
                                    builder: (context) => Text(
                                      'Your collection',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            sliver: SliverList.list(
                              children: [
                                for (final title in [
                                  'Golden Hour',
                                  'Quiet Water',
                                  'After the Rain',
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: SongListItem(
                                      data: SongListItemData(
                                        title: title,
                                        artistAlbumText:
                                            'HE Music · Evening Tide',
                                        subtitleText: '',
                                        coverBytes: bytes,
                                        tags: const ['HQ'],
                                      ),
                                      onTap: () {},
                                      onLikeTap: () {},
                                      onMoreTap: () {},
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                Builder(
                                  builder: (context) => Text(
                                    'Made for the moment',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final (index, title) in [
                                      'Evening Tide',
                                      'Slow Mornings',
                                    ].indexed) ...[
                                      if (index > 0) const SizedBox(width: 12),
                                      Expanded(
                                        child: MediaGridCard(
                                          kind: MediaGridCardKind.playlist,
                                          title: title,
                                          subtitle: 'HE Music',
                                          coverUrl: _artworkUrl,
                                          caption: '14 songs',
                                          onTap: () {},
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            final context = tester.element(find.byKey(capture));
            await precacheImage(const NetworkImage(_artworkUrl), context);
            final wallpaper = skin
                .configFor(brightness)
                .background
                .wallpaper
                .descriptor!;
            await precacheImage(AssetImage(wallpaper.path), context);
          });
          await tester.pumpAndSettle();
          await _waitForWallpaper(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(BackdropFilter), findsNothing);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$_previewDirectory/${style.name}-${brightness.name}-${detail ? 'detail' : 'collection'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    debugNetworkImageHttpClientProvider = null;
  }, skip: _previewDirectory.isEmpty);
}

Rect _headerRect(WidgetTester tester) {
  final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
  return tester.getRect(find.byWidget(appBar.flexibleSpace!));
}

Future<void> _waitForWallpaper(WidgetTester tester) async {
  final wallpaper = find.byKey(const ValueKey('app-skin-wallpaper'));
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final images = find.descendant(
      of: wallpaper,
      matching: find.byType(RawImage),
    );
    if (images.evaluate().isNotEmpty &&
        tester.widget<RawImage>(images).image != null) {
      return;
    }
  }
  throw TestFailure('Wallpaper did not decode before the visual capture.');
}

Future<ByteData> _solidArtwork(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(16, 16);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!;
  } finally {
    image.dispose();
    picture.dispose();
  }
}
