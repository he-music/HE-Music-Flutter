import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_list_count.dart';

void main() {
  testWidgets(
    'uses compact counts and a load-all action without visible status words',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SongListCount(
            loadedCount: 1000,
            totalCount: 2000,
            hasMore: true,
            onLoadAll: () async {
              taps++;
            },
          ),
        ),
      );
      expect(find.text('1000/2000 首'), findsOneWidget);
      expect(find.textContaining('已加载'), findsNothing);
      expect(find.textContaining('正在加载'), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.byTooltip('已加载 1000 首，共 2000 首歌曲，点击加载全部歌曲'), findsOneWidget);
      await tester.tap(find.text('1000/2000 首'));
      expect(taps, 1);
    },
  );

  testWidgets(
    'loading preserves counts, shows a spinner and prevents repeated taps',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SongListCount(
            loadedCount: 1500,
            totalCount: 2000,
            hasMore: true,
            loading: true,
            onLoadAll: () async {
              taps++;
            },
          ),
        ),
      );
      expect(find.text('1500/2000 首'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      await tester.tap(find.text('1500/2000 首'));
      expect(taps, 0);
    },
  );

  testWidgets(
    'finished state shows actual loaded count as noninteractive text',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SongListCount(
            loadedCount: 1900,
            totalCount: 2000,
            hasMore: false,
            onLoadAll: () async {
              taps++;
            },
          ),
        ),
      );
      expect(find.text('1900 首'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      await tester.tap(find.text('1900 首'));
      expect(taps, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('1900 首')),
        matchesSemantics(label: '1900 首'),
      );
    },
  );

  testWidgets('unknown totals stay compact and errors expose a retry action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        SongListCount(
          loadedCount: 1000,
          hasMore: true,
          error: 'failed page',
          onLoadAll: () async {
            taps++;
          },
        ),
      ),
    );
    expect(find.text('1000 首'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byTooltip('已加载 1000 首歌曲，加载失败，点击继续加载全部歌曲'), findsOneWidget);
    await tester.tap(find.text('1000 首'));
    expect(taps, 1);
  });

  testWidgets(
    'fits narrow layouts with large text and respects reduced motion',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SongListCount(
            loadedCount: 1000,
            totalCount: 2000,
            hasMore: true,
            loading: true,
            onLoadAll: () async {},
          ),
          width: 110,
          textScale: 3,
          reducedMotion: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.75,
      );
    },
  );
}

Widget _app(
  Widget child, {
  double width = 220,
  double textScale = 1,
  bool reducedMotion = false,
}) => MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);
