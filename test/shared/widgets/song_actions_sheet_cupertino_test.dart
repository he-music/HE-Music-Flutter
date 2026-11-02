import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

void main() {
  testWidgets(
    'mobile song sheet tracks cancel, disabled MV and one selection',
    (tester) async {
      var plays = 0;
      var videos = 0;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showSongActionsSheet(
                  context: context,
                  coverUrl: null,
                  title: 'Song identity',
                  subtitle: 'Artist',
                  sourceLabel: 'Source',
                  hasMv: false,
                  onPlay: () => plays++,
                  onPlayNext: () {},
                  onAddToPlaylist: () {},
                  onWatchMv: () => videos++,
                  onCopySongName: () {},
                  onCopySongId: () {},
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Song identity'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(SongActionsSheetController.hasOpenSheet.value, isTrue);
      final disabled = find.byWidgetPredicate(
        (widget) => widget is CupertinoButton && widget.onPressed == null,
      );
      expect(disabled, findsOneWidget);
      await tester.tap(disabled);
      await tester.pump();
      expect(videos, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plays, 0);
      expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<CupertinoActionSheet>(
        find.byType(CupertinoActionSheet),
      );
      final play = sheet.actions!.first as CupertinoActionSheetAction;
      play.onPressed();
      play.onPressed();
      await tester.pumpAndSettle();
      expect(plays, 1);
      expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(SongActionsSheetController.dismissOpenSheet(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(plays, 1);
    },
  );

  testWidgets(
    'force bottom keeps Cupertino popup on desktop with title and disabled action',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await showAdaptiveActionMenu<int>(
                    context: context,
                    forceBottomSheet: true,
                    title: const Text('Title'),
                    message: const Text('Message'),
                    items: const [
                      AdaptiveActionMenuItem(
                        value: 1,
                        label: 'Delete',
                        destructive: true,
                      ),
                      AdaptiveActionMenuItem(
                        value: 2,
                        label: 'Unavailable',
                        enabled: false,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
          desktop: true,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(
        tester
            .widget<CupertinoActionSheetAction>(
              find.ancestor(
                of: find.text('Delete'),
                matching: find.byType(CupertinoActionSheetAction),
              ),
            )
            .isDestructiveAction,
        isTrue,
      );
      await tester.tap(find.text('Unavailable'));
      await tester.pump();
      expect(result, isNull);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, 1);
    },
  );
}

Widget _app(Widget child, {bool desktop = false}) => MaterialApp(
  theme: ThemeData(
    platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
    extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
  ),
  home: Scaffold(body: child),
);
