import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';

void main() {
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
