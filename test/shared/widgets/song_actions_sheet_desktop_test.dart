import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final mode in [AppGlassMode.low, AppGlassMode.off]) {
    testWidgets(
      '$mode song action controller closes menu and preserves nested detail page',
      (tester) async {
        var actionCalls = 0;
        void action() => actionCalls++;
        await tester.pumpWidget(
          AppGlassScope(
            enabled: mode.usesGlass,
            mode: mode,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              child: MaterialApp(
                theme: ThemeData(platform: TargetPlatform.macOS),
                home: GlassScaffold(
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
            ),
          ),
        );
        await tester.tap(find.text('Open detail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Song more actions'));
        await tester.pumpAndSettle();
        expect(SongActionsSheetController.hasOpenSheet.value, isTrue);
        expect(
          find.byType(GlassMenu),
          mode.usesGlass ? findsOneWidget : findsNothing,
        );
        expect(SongActionsSheetController.dismissOpenSheet(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(GlassMenu), findsNothing);
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
