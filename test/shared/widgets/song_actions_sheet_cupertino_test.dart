import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';
import 'package:he_music_flutter/shared/widgets/app_list_tile.dart';
import 'package:he_music_flutter/shared/widgets/song_actions_sheet.dart';

const _listKey = ValueKey('song-actions-sheet-list');

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      'song panel closes and dispatches a selection once with $style',
      (tester) async {
        var plays = 0;
        await tester.pumpWidget(
          _app(
            style: style,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => _open(context, onPlay: () => plays++),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Song identity'), findsOneWidget);
        expect(find.text('Source'), findsOneWidget);
        expect(find.text('Watch MV'), findsNothing);
        expect(find.text('More Song Actions'), findsNothing);
        expect(SongActionsSheetController.hasOpenSheet.value, isTrue);
        await tester.tap(find.byKey(const ValueKey('song-actions-close')));
        await tester.pumpAndSettle();
        expect(plays, 0);
        expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final VoidCallback play;
        if (style == AppUiStyle.cupertino) {
          play = tester
              .widget<AppListTile>(
                find.ancestor(
                  of: find.text('Play'),
                  matching: find.byType(AppListTile),
                ),
              )
              .onTap!;
        } else {
          play = tester
              .widget<ListTile>(
                find.ancestor(
                  of: find.text('Play'),
                  matching: find.byType(ListTile),
                ),
              )
              .onTap!;
        }
        play();
        play();
        await tester.pumpAndSettle();
        expect(plays, 1);
        expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(SongActionsSheetController.dismissOpenSheet(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byKey(_listKey), findsNothing);
      },
    );
  }

  testWidgets(
    'Cupertino song actions stay on one layer with fixed header and optional group backgrounds',
    (tester) async {
      var removals = 0;
      var details = 0;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => _open(
                context,
                onViewDetail: () => details++,
                onRemove: () => removals++,
                longMenu: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(CupertinoListSection), findsWidgets);
      expect(find.text('More Song Actions'), findsNothing);
      expect(find.text('View Artist'), findsOneWidget);
      expect(find.text('View Album'), findsOneWidget);
      final headerRect = tester.getRect(find.text('Song identity'));
      final closeRect = tester.getRect(
        find.byKey(const ValueKey('song-actions-close')),
      );
      final list = tester.element(find.byKey(_listKey));
      final container = ProviderScope.containerOf(list);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(_listKey),
          matching: find.byType(Scrollable),
        ),
      );
      await _scrollTo(tester, 'Remove from Playlist');
      expect(tester.getRect(find.text('Song identity')), headerRect);
      expect(
        tester.getRect(find.byKey(const ValueKey('song-actions-close'))),
        closeRect,
      );
      final offset = scrollable.position.pixels;
      expect(offset, greaterThan(0));
      for (final enabled in [false, true, false]) {
        container
            .read(appConfigProvider.notifier)
            .setShowContentBackground(enabled);
        await tester.pumpAndSettle();
        expect(tester.element(find.byKey(_listKey)), same(list));
        expect(scrollable.position.pixels, offset);
        for (final section in tester.widgetList<CupertinoListSection>(
          find.byType(CupertinoListSection),
        )) {
          expect(section.decoration!.color!.a, enabled ? 1 : 0);
        }
      }
      final removeFinder = find.ancestor(
        of: find.text('Remove from Playlist'),
        matching: find.byType(AppListTile),
      );
      final remove = tester.widget<AppListTile>(removeFinder);
      final colors = Theme.of(tester.element(removeFinder)).colorScheme;
      expect((remove.title as Text).style!.color, colors.error);
      expect((remove.leading as AppSkinIcon).color, colors.error);
      remove.onTap!();
      remove.onTap!();
      await tester.pumpAndSettle();
      expect(removals, 1);
      expect(details, 0);
      expect(SongActionsSheetController.hasOpenSheet.value, isFalse);
    },
  );

  testWidgets(
    'Material playback icons use the selected accent while other actions stay neutral',
    (tester) async {
      await tester.pumpWidget(
        _app(
          style: AppUiStyle.material,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => _open(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final label in ['Play', 'Play Next', 'Add to Queue']) {
        final finder = find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        );
        final tile = tester.widget<ListTile>(finder);
        expect(
          (tile.leading as AppSkinIcon).color,
          Theme.of(tester.element(finder)).colorScheme.primary,
        );
      }
      await _scrollTo(tester, 'Copy Song Name');
      final finder = find.ancestor(
        of: find.text('Copy Song Name'),
        matching: find.byType(ListTile),
      );
      final tile = tester.widget<ListTile>(finder);
      expect(
        (tile.leading as AppSkinIcon).color,
        Theme.of(tester.element(finder)).colorScheme.onSurfaceVariant,
      );
    },
  );

  testWidgets(
    'Cupertino song panel remains usable after resize with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => _open(context, longMenu: true),
              child: const Text('Open'),
            ),
          ),
          largeText: true,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Copy Song ID');
      expect(
        find.byKey(const ValueKey('song-actions-close')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('song-actions-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic Cupertino action menus retain native destructive and disabled actions',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAdaptiveActionMenu<int>(
                  context: context,
                  forceBottomSheet: true,
                  title: const Text('Title'),
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
            ),
          ),
          desktop: true,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Unavailable'));
      await tester.pump();
      expect(result, isNull);
      final delete = tester.widget<CupertinoActionSheetAction>(
        find.ancestor(
          of: find.text('Delete'),
          matching: find.byType(CupertinoActionSheetAction),
        ),
      );
      expect(delete.isDestructiveAction, isTrue);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, 1);
    },
  );
}

Future<void> _scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    140,
    scrollable: find.descendant(
      of: find.byKey(_listKey),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(
  BuildContext context, {
  VoidCallback? onPlay,
  VoidCallback? onViewDetail,
  VoidCallback? onRemove,
  bool longMenu = false,
}) => showSongActionsSheet(
  context: context,
  forceBottomSheet: true,
  coverUrl: null,
  title: 'Song identity',
  subtitle: 'Artist',
  sourceLabel: 'Source',
  hasMv: false,
  onPlay: onPlay ?? () {},
  onPlayNext: () {},
  onAddToPlaylist: () {},
  onAddToUserPlaylist: longMenu ? () {} : null,
  onDownload: longMenu ? () {} : null,
  onWatchMv: () {},
  artistActionLabel: longMenu ? 'View Artist' : null,
  onViewArtists: longMenu ? () {} : null,
  albumActionLabel: longMenu ? 'View Album' : null,
  onViewAlbum: longMenu ? () {} : null,
  onViewComment: longMenu ? () {} : null,
  onViewDetail: onViewDetail,
  onRemoveFromPlaylist: onRemove,
  onCopySongName: () {},
  onCopySongId: () {},
);

Widget _app({
  required Widget child,
  AppUiStyle style = AppUiStyle.cupertino,
  bool desktop = false,
  bool largeText = false,
}) => ProviderScope(
  overrides: [appConfigProvider.overrideWith(_Config.new)],
  child: MaterialApp(
    theme: ThemeData(
      platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      extensions: [AppUiTheme(style: style)],
    ),
    builder: largeText
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          )
        : null,
    home: Scaffold(body: child),
  ),
);

class _Config extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  @override
  void setShowContentBackground(bool value) =>
      state = state.copyWith(showContentBackground: value);
}
