import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/shared/widgets/music_control_surface.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'play all sliver frosts and keeps actions usable in $brightness',
      (tester) async {
        var played = 0;
        var batched = 0;
        await tester.pumpWidget(
          _buildControlTestApp(
            brightness: brightness,
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 240)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: MusicDetailPlayAllHeader(
                    height: 56,
                    countText: 'Play All 30',
                    onPlayAll: () => played++,
                    onBatchAction: () => batched++,
                  ),
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 64, child: Text('Track $index')),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final expandedTint = tester
            .widget<GlassContainer>(find.byType(GlassContainer))
            .settings!
            .backerColor!
            .a;
        expect(expandedTint, inExclusiveRange(0, 1));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        final pinnedTint = tester
            .widget<GlassContainer>(find.byType(GlassContainer))
            .settings!
            .backerColor!
            .a;
        expect(pinnedTint, greaterThan(expandedTint));
        expect(pinnedTint, lessThan(1));
        await tester.tap(find.text('Play All 30'));
        await tester.tap(find.text('Batch'));
        expect(played, 1);
        expect(batched, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'fixed play all uses same material and preserves trailing action',
    (tester) async {
      var played = false;
      var shuffled = false;
      await tester.pumpWidget(
        _buildControlTestApp(
          body: Column(
            children: [
              MusicDetailPlayAllHeaderBox(
                countText: 'Play All 30',
                onPlayAll: () => played = true,
                trailing: TextButton(
                  onPressed: () => shuffled = true,
                  child: const Text('Shuffle'),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MusicControlSurface>(find.byType(MusicControlSurface))
            .collapseProgress,
        1,
      );
      expect(find.byType(GlassContainer), findsOneWidget);
      await tester.tap(find.text('Play All 30'));
      await tester.tap(find.text('Shuffle'));
      expect(played, isTrue);
      expect(shuffled, isTrue);
    },
  );

  for (final fallback in ['classic', 'off', 'powerSaving', 'highContrast']) {
    testWidgets('play all falls back to opaque material for $fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildControlTestApp(
          fallback: fallback,
          body: MusicDetailPlayAllHeaderBox(
            countText: 'Play All 1',
            onPlayAll: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassContainer), findsNothing);
      expect(
        tester
            .widgetList<Material>(
              find.ancestor(
                of: find.text('Play All 1'),
                matching: find.byType(Material),
              ),
            )
            .any((material) => material.color?.a == 1),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final batchMode in [false, true]) {
    testWidgets('large text fits pinned playback actions, batch=$batchMode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: Builder(
              builder: (context) => Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: MusicDetailPlayAllHeader(
                        height: MusicDetailPlayAllHeader.heightFor(context),
                        countText: 'Play all (1000)',
                        onPlayAll: () {},
                        onBatchAction: () {},
                        onMore: () {},
                        batchMode: batchMode,
                        selectedCount: 1000,
                        onSelectAll: () {},
                        onCancelBatch: () {},
                      ),
                    ),
                    SliverList.builder(
                      itemCount: 30,
                      itemBuilder: (_, index) =>
                          SizedBox(height: 60, child: Text('Track $index')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('glass detail navigation remains interactive after collapsing', (
    tester,
  ) async {
    var backed = false;
    var favorited = false;
    await tester.pumpWidget(
      AppGlassScope(
        enabled: true,
        child: GlassAdaptiveScope(
          minQuality: GlassQuality.minimal,
          maxQuality: GlassQuality.minimal,
          initialQuality: GlassQuality.minimal,
          child: MaterialApp(
            home: DetailPageShell(
              child: CustomScrollView(
                slivers: [
                  MusicDetailSliverAppBar(
                    title: 'Album',
                    subtitle: 'Artist',
                    coverUrl: '',
                    description: '',
                    onBack: () => backed = true,
                    onShowDescription: () {},
                    actions: [
                      MusicDetailActionButton(
                        icon: const Icon(Icons.favorite_border),
                        tooltip: 'Favorite',
                        onPressed: () => favorited = true,
                      ),
                    ],
                  ),
                  SliverList.builder(
                    itemCount: 40,
                    itemBuilder: (_, index) =>
                        SizedBox(height: 60, child: Text('Track $index')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassScaffold), findsOneWidget);
    expect(find.byType(GlassAppBar), findsOneWidget);
    expect(find.byType(GlassIconButton), findsNWidgets(2));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorite'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(favorited, isTrue);
    expect(backed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play all header shows batch actions in batch mode', (
    tester,
  ) async {
    var selectAllTapped = false;
    var cancelTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: MusicDetailPlayAllHeader(
                  height: 56,
                  countText: '全部播放 10',
                  onPlayAll: () {},
                  batchMode: true,
                  selectedCount: 2,
                  allSelected: false,
                  onSelectAll: () {
                    selectAllTapped = true;
                  },
                  onCancelBatch: () {
                    cancelTapped = true;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('2'), findsOneWidget);
    expect(find.byTooltip('Select all'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);

    await tester.tap(find.byTooltip('Select all'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();

    expect(selectAllTapped, isTrue);
    expect(cancelTapped, isTrue);
  });

  testWidgets(
    'detail sliver app bar action icon follows toolbar color animation',
    (tester) async {
      const themeIconColor = Colors.teal;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            iconTheme: const IconThemeData(color: themeIconColor),
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                MusicDetailSliverAppBar(
                  title: '测试标题',
                  subtitle: '测试副标题',
                  coverUrl: '',
                  description: '测试描述',
                  onBack: () {},
                  onShowDescription: () {},
                  actions: const <Widget>[Icon(Icons.favorite_border_rounded)],
                ),
                SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (context, index) =>
                      const SizedBox(height: 60, child: Text('item')),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(
        _iconThemeColor(tester, Icons.favorite_border_rounded)?.toARGB32(),
        Colors.white.toARGB32(),
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('music-detail-expanded-title'),
        ),
        1,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('music-detail-collapsed-title'),
        ),
        0,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -165));
      await tester.pump();

      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('music-detail-expanded-title'),
        ),
        0,
      );
      expect(
        _nearestOpacity(
          tester,
          const ValueKey<String>('music-detail-collapsed-title'),
        ),
        greaterThan(0),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(
        _iconThemeColor(tester, Icons.favorite_border_rounded)?.toARGB32(),
        themeIconColor.toARGB32(),
      );

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
}

Widget _buildControlTestApp({
  required Widget body,
  Brightness brightness = Brightness.light,
  String? fallback,
}) {
  final skin = citySoundCreatorSkin();
  final theme = brightness == Brightness.light
      ? AppTheme.light(skin)
      : AppTheme.dark(skin);
  final mode = switch (fallback) {
    'off' => AppGlassMode.off,
    'powerSaving' => AppGlassMode.powerSaving,
    _ => AppGlassMode.low,
  };
  return AppGlassScope(
    enabled: mode != AppGlassMode.off,
    mode: mode,
    child: GlassAdaptiveScope(
      minQuality: GlassQuality.minimal,
      maxQuality: GlassQuality.minimal,
      initialQuality: GlassQuality.minimal,
      child: MaterialApp(
        theme: fallback == 'classic' ? ThemeData() : theme,
        home: MediaQuery(
          data: MediaQueryData(highContrast: fallback == 'highContrast'),
          child: DetailPageShell(child: body),
        ),
      ),
    ),
  );
}

Color? _iconThemeColor(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon));
  return IconTheme.of(element).color;
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
