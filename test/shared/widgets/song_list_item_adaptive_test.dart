import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style song title wraps while actions retain independent targets',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var rowTaps = 0;
        var likes = 0;
        var more = 0;
        const title = 'A longer song title with a second readable line';
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(style),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SongListItem(
                    data: const SongListItemData(
                      title: title,
                      artistAlbumText: 'Artist and album',
                      subtitleText: 'Released 2026',
                      showMoreVersionButton: true,
                    ),
                    onTap: () => rowTaps++,
                    onLikeTap: () => likes++,
                    onMoreTap: () => more++,
                    onMoreVersionTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.widget<Text>(find.text(title)).maxLines, 2);
        final buttonType = style == AppUiStyle.cupertino
            ? CupertinoButton
            : IconButton;
        final like = find.ancestor(
          of: find.byIcon(Icons.favorite_border_rounded),
          matching: find.byType(buttonType),
        );
        final menu = find.ancestor(
          of: find.byIcon(Icons.more_horiz_rounded),
          matching: find.byType(buttonType),
        );
        final likeRect = tester.getRect(like);
        final menuRect = tester.getRect(menu);
        expect(likeRect.width, greaterThanOrEqualTo(48));
        expect(menuRect.height, greaterThanOrEqualTo(48));
        expect(likeRect.overlaps(menuRect), isFalse);
        await tester.tap(like);
        await tester.tap(menu);
        expect((rowTaps, likes, more), (0, 1, 1));
        Focus.of(
          tester.element(find.byIcon(Icons.more_horiz_rounded)),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect((rowTaps, likes, more), (0, 1, 2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$style song secondary click anchors the desktop menu at the pointer',
      (tester) async {
        var rowTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(style).copyWith(platform: TargetPlatform.macOS),
            home: Builder(
              builder: (context) => Scaffold(
                body: Padding(
                  padding: const EdgeInsets.only(top: 150),
                  child: SongListItem(
                    data: const SongListItemData(
                      title: 'Track',
                      artistAlbumText: 'Artist',
                      subtitleText: '',
                    ),
                    onTap: () => rowTaps++,
                    onMoreTap: () => showAdaptiveActionMenu<int>(
                      context: context,
                      items: const [
                        AdaptiveActionMenuItem(value: 1, label: 'Add to queue'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final point = tester.getCenter(find.byIcon(Icons.more_horiz_rounded));
        await tester.tapAt(
          point,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        final menuItem = find.byType(PopupMenuItem<int>);
        expect(menuItem, findsOneWidget);
        expect(tester.getRect(menuItem).top, closeTo(point.dy + 8, 2));
        expect(rowTaps, 0);
        await tester.tap(find.text('Add to queue'));
        await tester.pumpAndSettle();
        expect(menuItem, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

ThemeData _theme(AppUiStyle style) => AppTheme.light(
  AppSkinRegistry.builtIn(AppThemeAccent.appleBlue).resolve('classic'),
  uiStyle: style,
);
