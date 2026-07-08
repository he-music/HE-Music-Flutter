import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';

void main() {
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
    expect(find.text('Select all'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
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
