import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/music_control_surface.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final style in AppUiStyle.values) {
    for (final textScale in [1.0, 3.2]) {
      testWidgets(
        'detail loading matches loaded header in $style at $textScale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _detailApp(style: style, textScale: textScale, loading: true),
          );
          await tester.pump();
          final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          final header = tester.getRect(find.byWidget(appBar.flexibleSpace!));
          final background = tester.getRect(
            find.byKey(const ValueKey('detail-hero-skeleton-background')),
          );
          final meta = tester.getRect(
            find.byKey(const ValueKey('detail-hero-skeleton-meta')),
          );
          final playAll = tester.getRect(
            find.byType(MusicControlSurface).first,
          );
          expect(background, header);
          expect(meta.left, header.left + 16);
          expect(meta.right, header.right - 16);
          expect(meta.bottom, header.bottom - 18);
          expect(meta.top, greaterThanOrEqualTo(kToolbarHeight + 24));
          expect(playAll.top, header.bottom);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(NestedScrollView),
            const Offset(0, -800),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.getSize(find.byWidget(appBar.flexibleSpace!)).height,
            kToolbarHeight + 24,
          );
          expect(tester.takeException(), isNull);

          // Remove the loading scroll view so the comparison starts expanded.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            _detailApp(style: style, textScale: textScale, loading: false),
          );
          await tester.pump();
          final loaded = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          expect(tester.getRect(find.byWidget(loaded.flexibleSpace!)), header);
          expect(
            tester.getRect(find.byType(MusicControlSurface).first),
            playAll,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('artist videos loading skeleton uses compact video cover size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArtistVideosLoadingView())),
    );

    final firstSkeleton = find.byType(SkeletonBox).first;
    expect(tester.getSize(firstSkeleton), const Size(112, 64));
  });
}

Widget _detailApp({
  required AppUiStyle style,
  required double textScale,
  required bool loading,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(extensions: [AppUiTheme(style: style)]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: loading
            ? const GenericDetailLoadingBody(title: 'Playlist')
            : NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  MusicDetailSliverAppBar(
                    title: 'Playlist',
                    subtitle: 'Creator',
                    coverUrl: '',
                    description: 'Description',
                    onBack: () {},
                    onShowDescription: () {},
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: MusicDetailPlayAllHeader(
                      height: MusicDetailPlayAllHeader.heightFor(context),
                      countText: 'Play all',
                      onPlayAll: () {},
                    ),
                  ),
                ],
                body: ListView(children: const [SizedBox(height: 1200)]),
              ),
      ),
    ),
  );
}
