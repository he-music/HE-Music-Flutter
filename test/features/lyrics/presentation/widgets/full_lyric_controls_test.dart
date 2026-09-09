import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_auxiliary_mode.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/full_lyric_controls.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_panel.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

const _document = LyricDocument(
  lines: [
    LyricLine(
      start: Duration.zero,
      text: '城市回声',
      translation: 'City echoes',
      romanization: 'Cheng shi hui sheng',
    ),
    LyricLine(
      start: Duration(seconds: 10),
      text: '玻璃天台',
      translation: 'A rooftop of glass',
      romanization: 'Bo li tian tai',
    ),
    LyricLine(
      start: Duration(seconds: 20),
      text: '低频大厅',
      translation: 'Low frequency hall',
      romanization: 'Di pin da ting',
    ),
  ],
);
final _documentProvider = NotifierProvider<_Document, LyricDocument>(
  _Document.new,
);

class _Document extends Notifier<LyricDocument> {
  @override
  LyricDocument build() => _document;
  void replace(LyricDocument document) => state = document;
}

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform footer transport follows platform at narrow width', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(390, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lyric-play-control')),
        platform == TargetPlatform.macOS ? findsNothing : findsOneWidget,
      );
      expect(find.text('词'), findsOneWidget);
      expect(find.text('译'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'options opens within player route and $brightness theme boundary',
      (tester) async {
        await tester.pumpWidget(
          _app(playerBoundary: true, brightness: brightness, store: _Store()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('词'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('搜索歌词'), findsOneWidget);
        final tileContext = tester.element(find.text('搜索歌词'));
        expect(Theme.of(tileContext).brightness, brightness);
        expect(
          Theme.of(tileContext).colorScheme.onSurface,
          isNot(Theme.of(tileContext).colorScheme.surface),
        );
        expect(find.byType(PlayerSheetSurface), findsOneWidget);
        final container = ProviderScope.containerOf(tileContext);
        for (final title in ['歌词大小', '歌词颜色', '歌词样式']) {
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(PlayerSheetSurface), findsNWidgets(2));
          final tiles = find.descendant(
            of: find.byType(PlayerSheetSurface).last,
            matching: find.byType(ListTile),
          );
          expect(tiles, findsWidgets);
          expect(Theme.of(tester.element(tiles.first)).brightness, brightness);
          await tester.ensureVisible(tiles.last);
          await tester.pumpAndSettle();
          await tester.tap(tiles.last);
          await tester.pumpAndSettle();
          expect(find.byType(PlayerSheetSurface), findsOneWidget);
        }
        final config = container.read(appConfigProvider);
        expect(config.lyricFontPreset, AppLyricFontPreset.large);
        expect(config.lyricHighlightPreset, AppLyricHighlightColor.values.last);
        expect(
          config.playerLyricsId,
          AppPlayerLyricsRegistry.instance.options.last.metadata.id,
        );
      },
    );
  }

  testWidgets(
    'legacy model reloads same target when only middle auxiliary content changes',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LyricPanel)),
      );
      final controller = tester
          .widget<fl.LyricView>(find.byType(fl.LyricView))
          .controller;
      final middle = _document.lines[1];
      container
          .read(_documentProvider.notifier)
          .replace(
            LyricDocument(
              lines: [
                _document.lines.first,
                LyricLine(
                  start: middle.start,
                  text: middle.text,
                  translation: 'Replacement translation',
                  romanization: 'Replacement romanization',
                ),
                _document.lines.last,
              ],
            ),
          );
      await tester.pumpAndSettle();
      expect(
        tester.widget<fl.LyricView>(find.byType(fl.LyricView)).controller,
        same(controller),
      );
      expect(
        controller.lyricNotifier.value!.lines[1].translation,
        'Replacement translation',
      );
      await tester.tap(find.text('译'));
      await tester.pumpAndSettle();
      expect(
        controller.lyricNotifier.value!.lines[1].translation,
        'Replacement romanization',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'auxiliary toggles update rendering, play toggles and progress does not rebuild controls',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FullLyricControls)),
      );
      List<String?> renderedTranslations() => tester
          .widget<fl.LyricView>(find.byType(fl.LyricView))
          .controller
          .lyricNotifier
          .value!
          .lines
          .map((line) => line.translation)
          .toList();
      expect(
        renderedTranslations(),
        _document.lines.map((line) => line.translation),
      );
      expect(find.text('译'), findsOneWidget);
      await tester.tap(find.text('译'));
      await tester.pumpAndSettle();
      expect(find.text('音'), findsOneWidget);
      expect(
        renderedTranslations(),
        _document.lines.map((line) => line.romanization),
      );
      expect(
        container
            .read(displayedLyricDocumentProvider)
            .value!
            .lines
            .first
            .translation,
        'Cheng shi hui sheng',
      );
      await tester.tap(find.text('音'));
      await tester.pumpAndSettle();
      expect(find.text('原'), findsOneWidget);
      expect(renderedTranslations(), everyElement(isNull));
      expect(
        container
            .read(displayedLyricDocumentProvider)
            .value!
            .lines
            .first
            .translation,
        isEmpty,
      );
      await tester.tap(find.byTooltip('播放'));
      await tester.pump();
      expect(find.byTooltip('暂停'), findsOneWidget);
      final before = tester.widget(
        find.byKey(const ValueKey('lyric-options-control')),
      );
      (container.read(playerControllerProvider.notifier) as _Player).progress();
      await tester.pump();
      expect(
        tester.widget(find.byKey(const ValueKey('lyric-options-control'))),
        same(before),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty lyrics retain options and large text fits narrow controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(document: const LyricDocument.empty(), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('词'), findsOneWidget);
      expect(find.text('译'), findsNothing);
      expect(find.text('原'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FullLyricControls)),
      );
      final before = container.read(appConfigProvider).lyricAuxiliaryMode;
      await tester.tap(find.text('原'));
      await tester.pump();
      expect(container.read(appConfigProvider).lyricAuxiliaryMode, before);
      expect(
        tester
            .widget<InkResponse>(
              find.descendant(
                of: find.byKey(const ValueKey('lyric-auxiliary-control')),
                matching: find.byType(InkResponse),
              ),
            )
            .onTap,
        isNull,
      );
      expect(tester.widget<Text>(find.text('原')).style!.color, Colors.white54);
      expect(find.byTooltip('播放'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small outlined controls group at left and larger playback sits at right',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
      final auxiliary = rect('lyric-auxiliary-outline');
      final options = rect('lyric-options-outline');
      final play = rect('lyric-play-control');
      expect(auxiliary.width, 28);
      expect(options.width, 28);
      expect(tester.widget<Text>(find.text('词')).style!.fontSize, 14);
      expect(rect('lyric-auxiliary-control').width, greaterThanOrEqualTo(48));
      expect(rect('lyric-options-control').width, greaterThanOrEqualTo(48));
      expect(options.left - auxiliary.right, inInclusiveRange(12, 20));
      expect(options.right, lessThan(130));
      expect(play.width, 52);
      expect(play.right, 374);
      expect(play.left - options.right, greaterThan(150));
      expect(auxiliary.center.dy, play.center.dy);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'player boundary footer and open options visual evidence',
    (tester) async {
      await _loadFonts(tester);
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(playerBoundary: true, golden: true, store: _Store()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('词'));
      await tester.pumpAndSettle();
      expect(find.text('搜索歌词'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('route-golden')),
        matchesGoldenFile('goldens/lyric_options_light.png'),
      );
      await tester.tap(find.text('歌词大小'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('route-golden')),
        matchesGoldenFile('goldens/lyric_size_light.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.physicalSize = const Size(800, 640);
      await tester.pumpWidget(_app(golden: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lyric-play-control')), findsNothing);
      await expectLater(
        find.byKey(const ValueKey('route-golden')),
        matchesGoldenFile('goldens/full_lyric_controls_desktop.png'),
      );
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !Platform.isMacOS,
  );

  testWidgets('full lyric controls reproducible portrait golden', (
    tester,
  ) async {
    await _loadFonts(tester);
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(golden: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('lyric-golden')),
      matchesGoldenFile('goldens/full_lyric_controls.png'),
    );
  }, skip: !Platform.isMacOS);
}

Widget _app({
  LyricDocument document = _document,
  double scale = 1,
  bool golden = false,
  bool playerBoundary = false,
  Brightness brightness = Brightness.light,
  LyricStore? store,
}) => ProviderScope(
  overrides: [
    if (store != null) lyricStoreProvider.overrideWithValue(store),
    appConfigProvider.overrideWith(_Config.new),
    playerControllerProvider.overrideWith(_Player.new),
    currentLyricDocumentProvider.overrideWith(
      (ref) => AsyncData(
        identical(document, _document)
            ? ref.watch(_documentProvider)
            : document,
      ),
    ),
    currentLyricRequestProvider.overrideWithValue(null),
    lyricPositionProvider.overrideWithValue(Duration.zero),
  ],
  child: MaterialApp(
    builder: (context, child) =>
        RepaintBoundary(key: const ValueKey('route-golden'), child: child!),
    theme:
        (playerBoundary ? ThemeData(brightness: brightness) : ThemeData.dark())
            .copyWith(
              textTheme:
                  (playerBoundary
                          ? ThemeData(brightness: brightness)
                          : ThemeData.dark())
                      .textTheme
                      .apply(
                        fontFamily: 'PreviewRoboto',
                        fontFamilyFallback: ['PreviewCjk'],
                      ),
            ),
    home: Builder(
      builder: (context) {
        final body = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('lyric-golden'),
            child: Scaffold(
              backgroundColor: const Color(0xff182532),
              body: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 40, bottom: 20),
                    child: Text('城市回声', style: TextStyle(fontSize: 24)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: golden
                          ? const _GoldenLyricPanel()
                          : const LyricPanel(emptyText: '暂无歌词'),
                    ),
                  ),
                  FullLyricControls(),
                ],
              ),
            ),
          ),
        );
        return playerBoundary ? AppPlayerStyleBoundary(child: body) : body;
      },
    ),
  ),
);

class _Config extends AppConfigController {
  @override
  void setLyricFontPreset(AppLyricFontPreset preset) {
    state = state.copyWith(lyricFontPreset: preset);
  }

  @override
  void setPlayerLyricsId(String id) {
    state = state.copyWith(playerLyricsId: id);
  }

  @override
  void setLyricHighlightPreset(preset) {
    state = state.copyWith(lyricHighlightPreset: preset);
  }

  @override
  AppConfigState build() => AppConfigState.initial;
  @override
  void setLyricAuxiliaryMode(AppLyricAuxiliaryMode mode) {
    state = state.copyWith(lyricAuxiliaryMode: mode);
  }
}

class _Player extends PlayerController {
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const [
    PlayerTrack(id: 'song', title: '城市回声'),
  ]);
  @override
  Future<void> togglePlayPause() async {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void progress() {
    state = state.copyWith(position: const Duration(seconds: 1));
  }
}

// flutter_lyric paints directly and does not inherit Theme fonts. Apply only
// the deterministic test fonts to the real shared lyric style and model.
class _GoldenLyricPanel extends StatefulWidget {
  const _GoldenLyricPanel();
  @override
  State<_GoldenLyricPanel> createState() => _GoldenLyricPanelState();
}

class _GoldenLyricPanelState extends State<_GoldenLyricPanel> {
  final _controller = fl.LyricController();
  @override
  void initState() {
    super.initState();
    _controller.loadLyricModel(
      buildFlutterLyricModel(_document, enableWordByWordLyric: false),
    );
    _controller.setProgress(Duration.zero);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = buildLyricStyle(
      compact: false,
      fontPreset: AppLyricFontPreset.medium,
      activeHighlightColor: const Color(0xff38bdf8),
    );
    TextStyle font(TextStyle style) => style.copyWith(
      fontFamily: 'PreviewRoboto',
      fontFamilyFallback: ['PreviewCjk'],
    );
    return fl.LyricView(
      controller: _controller,
      width: double.infinity,
      height: double.infinity,
      style: style.copyWith(
        textStyle: font(style.textStyle),
        activeStyle: font(style.activeStyle),
        translationStyle: font(style.translationStyle),
      ),
    );
  }
}

class _Store extends LyricStore {
  _Store()
    : super(
        manualDirectory: () async => Directory('/unused'),
        automaticDirectory: () async => Directory('/unused'),
      );
  @override
  Future<bool> hasManual(target) async => false;
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final pair in [
      ('PreviewRoboto', 'test/assets/fonts/Roboto-Regular.ttf'),
      ('Roboto', 'test/assets/fonts/DroidSansFallback-LyricSubset.ttf'),
      ('PreviewCjk', 'test/assets/fonts/DroidSansFallback-LyricSubset.ttf'),
    ]) {
      final loader = FontLoader(pair.$1)
        ..addFont(File(pair.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}
