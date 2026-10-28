import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/presentation/widgets/local_songs_stream_view.dart';

void main() {
  testWidgets(
    'desktop song list can return to top through its shared controller',
    (tester) async {
      await tester.pumpWidget(
        _app(
          () => Stream.value(const [_song]),
          platform: TargetPlatform.macOS,
          builder: (context, songs) => ListView.builder(
            itemExtent: 64,
            itemCount: 100,
            itemBuilder: (context, index) => Text('歌曲 $index'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final controller = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      expect(controller.pixels, greaterThan(0));
      final button = find
          .byIcon(Icons.vertical_align_top_rounded)
          .hitTestable();
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(controller.pixels, controller.minScrollExtent);
      expect(button, findsNothing);
    },
  );
  testWidgets(
    'changing query hides old results until the new stream responds',
    (tester) async {
      final nextSongs = StreamController<List<LocalSong>>();
      addTearDown(nextSongs.close);
      await tester.pumpWidget(_app(() => Stream.value(const [_song])));
      await tester.pumpAndSettle();
      expect(find.text('歌曲'), findsOneWidget);
      await tester.pumpWidget(_app(() => nextSongs.stream, sourceKey: 'other'));
      await tester.pump();
      expect(find.text('歌曲'), findsNothing);
      nextSongs.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('没有歌曲'), findsOneWidget);
    },
  );

  testWidgets('a stream completing without data shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() => const Stream.empty()));
    await tester.pumpAndSettle();
    expect(find.text('没有歌曲'), findsOneWidget);
  });

  testWidgets('read failure shows retry, then successful retry shows songs', (
    tester,
  ) async {
    var subscriptions = 0;
    Stream<List<LocalSong>> watchSongs() {
      subscriptions++;
      return subscriptions == 1
          ? Stream.error(StateError('database unavailable'))
          : Stream.value(const [_song]);
    }

    await tester.pumpWidget(_app(watchSongs));
    await tester.pumpAndSettle();
    expect(find.text('本地歌曲读取失败，请重试。'), findsOneWidget);
    expect(find.text('没有歌曲'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(subscriptions, 2);
    expect(find.text('歌曲'), findsOneWidget);
  });

  testWidgets(
    'unrelated parent rebuild preserves subscription and empty state',
    (tester) async {
      var subscriptions = 0;
      Stream<List<LocalSong>> watchSongs() {
        subscriptions++;
        return Stream.value(const []);
      }

      await tester.pumpWidget(_app(watchSongs));
      await tester.pumpAndSettle();
      expect(find.text('没有歌曲'), findsOneWidget);
      await tester.pumpWidget(_app(watchSongs, dark: true));
      await tester.pumpAndSettle();
      expect(subscriptions, 1);
      expect(find.text('没有歌曲'), findsOneWidget);
    },
  );
}

Widget _app(
  Stream<List<LocalSong>> Function() watchSongs, {
  bool dark = false,
  String sourceKey = 'artist',
  TargetPlatform platform = TargetPlatform.android,
  Widget Function(BuildContext, List<LocalSong>)? builder,
}) => ProviderScope(
  child: MaterialApp(
    theme: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
      platform: platform,
    ),
    locale: const Locale('zh'),
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: LocalSongsStreamView(
        sourceKey: sourceKey,
        watchSongs: watchSongs,
        localeCode: 'zh',
        emptyText: '没有歌曲',
        builder: builder ?? (context, songs) => Text(songs.single.title),
      ),
    ),
  ),
);

const _song = LocalSong(
  id: 'song',
  title: '歌曲',
  artist: '歌手',
  album: '专辑',
  filePath: '/tmp/song.mp3',
  duration: Duration(minutes: 3),
  mimeType: 'audio/mpeg',
  size: 1024,
);
