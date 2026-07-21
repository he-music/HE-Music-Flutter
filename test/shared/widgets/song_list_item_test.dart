import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
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

    testWidgets('操作按钮应使用 48dp 点击区域且不触发歌曲点击', (tester) async {
      var songTapCount = 0;
      var likeTapCount = 0;
      var moreTapCount = 0;
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: basicData,
            onTap: () => songTapCount += 1,
            onLikeTap: () => likeTapCount += 1,
            onMoreTap: () => moreTapCount += 1,
          ),
        ),
      );

      final likeButton = find.ancestor(
        of: find.byIcon(Icons.favorite_border_rounded),
        matching: find.byType(IconButton),
      );
      final moreButton = find.ancestor(
        of: find.byIcon(Icons.more_horiz_rounded),
        matching: find.byType(IconButton),
      );

      expect(tester.getSize(likeButton), const Size.square(48));
      expect(tester.getSize(moreButton), const Size.square(48));

      await tester.tap(likeButton);
      await tester.tap(moreButton);

      expect(likeTapCount, 1);
      expect(moreTapCount, 1);
      expect(songTapCount, 0);
    });

    testWidgets('点击右侧操作按钮间隙不应触发歌曲点击', (tester) async {
      var songTapCount = 0;
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: basicData,
            onTap: () => songTapCount += 1,
            onLikeTap: () {},
            onMoreTap: () {},
          ),
        ),
      );

      final likeButton = find.ancestor(
        of: find.byIcon(Icons.favorite_border_rounded),
        matching: find.byType(IconButton),
      );
      final moreButton = find.ancestor(
        of: find.byIcon(Icons.more_horiz_rounded),
        matching: find.byType(IconButton),
      );
      final likeRect = tester.getRect(likeButton);
      final moreRect = tester.getRect(moreButton);

      await tester.tapAt(
        Offset((likeRect.right + moreRect.left) / 2, likeRect.center.dy),
      );

      expect(songTapCount, 0);
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
      var songTapCount = 0;
      var versionTapCount = 0;
      final data = SongListItemData(
        title: 'T',
        artistAlbumText: 'A',
        subtitleText: '副标题',
        showMoreVersionButton: true,
      );
      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: data,
            onTap: () => songTapCount += 1,
            onMoreVersionTap: () => versionTapCount += 1,
          ),
          height: 128,
        ),
      );

      final versionLabel = find.text('More Versions');
      final subtitle = find.text('副标题');
      expect(versionLabel, findsOneWidget);

      await tester.tap(versionLabel);
      final titleRect = tester.getRect(find.text('T'));
      final subtitleRect = tester.getRect(subtitle);
      final labelRect = tester.getRect(versionLabel);
      await tester.tapAt(Offset(titleRect.right - 4, labelRect.center.dy));

      expect(versionTapCount, 2);
      expect(songTapCount, 0);
      expect(labelRect.top, greaterThan(subtitleRect.bottom));
      expect((labelRect.left - subtitleRect.left).abs(), lessThanOrEqualTo(4));
    });

    testWidgets('窄屏同时显示三个操作时不应发生布局异常', (tester) async {
      final data = SongListItemData(
        title: '一首标题非常长的歌曲',
        artistAlbumText: '歌手与专辑信息',
        subtitleText: '副标题',
        showMoreVersionButton: true,
      );

      await tester.pumpWidget(
        _wrap(
          SongListItem(
            data: data,
            onLikeTap: () {},
            onMoreTap: () {},
            onMoreVersionTap: () {},
          ),
          width: 320,
          height: 128,
        ),
      );

      expect(tester.takeException(), isNull);
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

    testWidgets('沉浸式皮肤使用共享滚动内容表面且不增加模糊', (tester) async {
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.citySoundCreatorId);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(skin),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 80,
              child: SongListItem(data: basicData),
            ),
          ),
        ),
      );

      expect(find.byType(AppSkinSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      final surfaceDecoration = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppSkinSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (surfaceDecoration.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(skin.light.geometry.cardRadius),
      );
    });
  });
}

Widget _wrap(Widget child, {double width = 400, double height = 80}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  );
}
