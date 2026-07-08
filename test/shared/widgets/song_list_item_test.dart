import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  final basicData = SongListItemData(
    title: '稻香',
    artistAlbumText: '周杰伦',
    subtitleText: '',
  );

  group('SongListItem', () {
    testWidgets('应显示标题和歌手信息', (tester) async {
      await tester.pumpWidget(_wrap(SongListItem(data: basicData)));

      expect(find.text('稻香'), findsOneWidget);
      expect(find.text('周杰伦'), findsOneWidget);
    });

    testWidgets('点击应触发 onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(SongListItem(data: basicData, onTap: () => tapped = true)),
      );

      await tester.tap(find.text('稻香'));
      expect(tapped, isTrue);
    });

    testWidgets('isCurrent 为 true 时标题应使用 primary 颜色', (tester) async {
      final data = SongListItemData(
        title: 'Current',
        artistAlbumText: 'Artist',
        subtitleText: '',
        isCurrent: true,
      );
      await tester.pumpWidget(_wrap(SongListItem(data: data)));

      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('showActions 为 false 时不显示操作按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: basicData,
            showActions: false,
            onLikeTap: () {},
            onMoreTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets('showActions 为 true 且有回调时显示操作按钮', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: basicData,
            showActions: true,
            onLikeTap: () {},
            onMoreTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('isLiked 为 true 时显示实心红心', (tester) async {
      await tester.pumpWidget(
        _wrap(SongListItem(data: basicData, isLiked: true, onLikeTap: () {})),
      );

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('selectable 为 true 时应显示选择指示器', (tester) async {
      await tester.pumpWidget(
        _wrap(SongListItem(data: basicData, selectable: true)),
      );

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('selectable + selected 时应显示勾选图标', (tester) async {
      await tester.pumpWidget(
        _wrap(SongListItem(data: basicData, selectable: true, selected: true)),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('selectable 模式下点击应触发 onSelectTap', (tester) async {
      var selectTapped = false;
      var onTapCalled = false;
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: basicData,
            selectable: true,
            onSelectTap: () => selectTapped = true,
            onTap: () => onTapCalled = true,
          ),
        ),
      );

      await tester.tap(find.text('稻香'));
      expect(selectTapped, isTrue);
      expect(onTapCalled, isFalse);
    });

    testWidgets('subtitleText 非空时应显示', (tester) async {
      final data = SongListItemData(
        title: 'T',
        artistAlbumText: 'A',
        subtitleText: '副标题',
      );
      await tester.pumpWidget(_wrap(SongListItem(data: data)));

      expect(find.text('副标题'), findsOneWidget);
    });

    testWidgets('tags 非空时应显示标签', (tester) async {
      final data = SongListItemData(
        title: 'T',
        artistAlbumText: 'A',
        subtitleText: '',
        tags: ['SQ', 'HQ'],
      );
      await tester.pumpWidget(_wrap(SongListItem(data: data)));

      expect(find.text('SQ'), findsOneWidget);
      expect(find.text('HQ'), findsOneWidget);
    });

    testWidgets('showMoreVersionButton 为 true 时应显示按钮', (tester) async {
      var versionTapped = false;
      final data = SongListItemData(
        title: 'T',
        artistAlbumText: 'A',
        subtitleText: '',
        showMoreVersionButton: true,
      );
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: data,
            onMoreVersionTap: () => versionTapped = true,
          ),
        ),
      );

      expect(find.text('More Versions'), findsOneWidget);
      await tester.tap(find.text('More Versions'));
      expect(versionTapped, isTrue);
    });

    testWidgets('无封面 URL 时应显示音乐图标', (tester) async {
      final data = SongListItemData(
        title: 'T',
        artistAlbumText: 'A',
        subtitleText: '',
      );
      await tester.pumpWidget(_wrap(SongListItem(data: data)));

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 80, child: child)),
  );
}
