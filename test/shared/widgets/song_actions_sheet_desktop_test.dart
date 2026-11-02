import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

void main() {
  for (final mode in AppUiStyle.values) {
    testWidgets(
      '$mode song action controller closes menu and preserves nested detail page',
      (tester) async {
        var actionCalls = 0;
        void action() => actionCalls++;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.macOS,
              extensions: [AppUiTheme(style: mode)],
            ),
            home: Scaffold(
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => Column(
                            children: [
                              const Text('Nested detail page'),
                              TextButton(
                                onPressed: () => showSongActionsSheet(
                                  context: context,
                                  anchorPosition: const Offset(100, 100),
                                  coverUrl: null,
                                  title: 'Online song',
                                  subtitle: 'Artist',
                                  hasMv: false,
                                  sourceLabel: 'Online',
                                  onPlay: action,
                                  onPlayNext: action,
                                  onAddToPlaylist: action,
                                  onWatchMv: action,
                                  onCopySongName: action,
                                  onCopySongId: action,
                                ),
                                child: const Text('Song more actions'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: const Text('Open detail'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open detail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Song more actions'));
        await tester.pumpAndSettle();
        expect(SongActionsSheetController.hasOpenSheet.value, isTrue);
        expect(find.byType(PopupMenuItem<VoidCallback>), findsWidgets);
        expect(SongActionsSheetController.dismissOpenSheet(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<VoidCallback>), findsNothing);
        expect(find.text('Nested detail page'), findsOneWidget);
        expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
        expect(SongActionsSheetController.dismissOpenSheet(), isFalse);
        expect(actionCalls, 0);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}
