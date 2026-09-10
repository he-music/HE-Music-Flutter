import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/shared/widgets/online_platform_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_candidate.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/lyrics/presentation/pages/lyric_search_page.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';

const _track = PlayerTrack(
  id: 'original',
  title: 'Song',
  artist: 'Artist',
  platform: 'B',
  duration: Duration(seconds: 279),
);
const _candidate = LyricCandidate(
  platform: 'A',
  id: 'composite|id',
  name: 'Candidate',
  artistNames: ['Artist'],
  duration: 279,
);
void main() {
  late Directory root;
  late LyricStore store;
  late _Api api;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('search-lyric-test');
    store = LyricStore(
      manualDirectory: () async => Directory('${root.path}/manual'),
      automaticDirectory: () async => Directory('${root.path}/auto'),
    );
    api = _Api();
  });
  tearDown(() async => root.delete(recursive: true));
  Widget app({
    PlayerTrack target = _track,
    bool emptyPlatforms = false,
    Future<List<OnlinePlatform>> Function()? loadPlatforms,
    double textScale = 1,
    bool dark = false,
  }) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_Config.new),
      onlineApiClientProvider.overrideWithValue(api),
      lyricStoreProvider.overrideWithValue(store),
      onlinePlatformsProvider.overrideWith(
        () => _Platforms(emptyPlatforms, loadPlatforms),
      ),
    ],
    child: MaterialApp(
      theme: _theme(dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LyricSearchPage(target: target),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  Future<void> open(
    WidgetTester tester, {
    PlayerTrack target = _track,
    bool emptyPlatforms = false,
    Future<List<OnlinePlatform>> Function()? loadPlatforms,
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      app(
        target: target,
        emptyPlatforms: emptyPlatforms,
        loadPlatforms: loadPlatforms,
        textScale: textScale,
        dark: dark,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, '搜索'));
    await tester.pump();
  }

  testWidgets(
    'platform order and current platform preference; stale A B A searches never overwrite latest result',
    (tester) async {
      await open(tester);
      final tabs = tester.widget<OnlinePlatformTabs>(
        find.byType(OnlinePlatformTabs),
      );
      expect(tabs.platforms.map((p) => p.id), ['A', 'B']);
      expect(tabs.selectedId, 'B');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final loadingArea = tester.getRect(
        find.descendant(
          of: find.byType(SliverFillRemaining),
          matching: find.byType(Center),
        ),
      );
      expect(
        tester.getCenter(find.byType(CircularProgressIndicator)),
        loadingArea.center,
      );
      expect(find.text('多位歌手用顿号或中英文逗号分隔'), findsOneWidget);
      expect(find.text('Platform A'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(OnlinePlatformTabs)).dy,
        lessThan(tester.getTopLeft(find.byType(TextField).first).dy),
      );
      expect(api.calls, ['B']);
      await tester.tap(find.text('QQ'));
      await tester.pump();
      await tester.tap(find.text('网易'));
      await tester.pump();
      await tester.tap(find.text('QQ'));
      await tester.pump();
      await search(tester); // Same in-flight query shares the existing future.
      expect(api.calls, ['B', 'A']);
      expect(api.lastDuration, 279);
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsOneWidget);
      api.pending['B']!.complete([
        const LyricCandidate(
          platform: 'B',
          id: 'old',
          name: 'Old result',
          artistNames: [],
          duration: 0,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Old result'), findsNothing);
      expect(find.text('Candidate'), findsOneWidget);
    },
  );

  testWidgets(
    'input edits invalidate pending results and missing artist is never replaced with a placeholder',
    (tester) async {
      await open(
        tester,
        target: const PlayerTrack(
          id: 'local',
          title: 'Song',
          artist: '未知歌手',
          platform: 'local',
        ),
      );
      await search(tester);
      expect(api.calls, isEmpty);
      expect(find.text('请补齐歌名和歌手'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Artist');
      await search(tester);
      expect(api.lastDuration, 0);
      await tester.enterText(find.byType(TextField).first, 'New name');
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsNothing);
    },
  );

  testWidgets('search sends the supplied target duration in whole seconds', (
    tester,
  ) async {
    await open(
      tester,
      target: _track.copyWith(duration: const Duration(milliseconds: 301900)),
    );
    expect(api.lastDuration, 301);
    await search(tester);
    expect(api.lastDuration, 301);
    expect(api.calls, ['B']);

    api.pending['B']!.complete([]);
    await tester.pumpAndSettle();
    await search(tester);
    expect(api.lastDuration, 301);
    expect(api.calls, ['B', 'B']);
    await tester.tap(find.text('QQ'));
    await tester.pump();
    expect(api.lastDuration, 301);
    expect(api.calls, ['B', 'B', 'A']);
  });

  testWidgets('no capable platforms has explicit empty state', (tester) async {
    await open(tester, emptyPlatforms: true);
    expect(find.text('暂无可用的歌词搜索平台'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets(
    'clear during candidate fetch prevents stale save and leaves search open',
    (tester) async {
      await open(tester);
      await search(tester);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Candidate'));
      await tester.pump();
      await tester.runAsync(() async {
        await store.clearManual();
        api.candidate.complete(const RawLyricBundle(lyric: '[00:00.00]chosen'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LyricSearchPage), findsOneWidget);
      expect(
        await tester.runAsync(
          () => store.hasManual(
            const LyricRequest(trackId: 'original', platform: 'B'),
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'candidate success saves original target identity and closes route',
    (tester) async {
      await open(tester);
      await search(tester);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Candidate'));
      await tester.pump();
      api.candidate.complete(
        const RawLyricBundle(
          lyric: '[00:00.00]chosen',
          romanization: '[00:00.00]roma',
        ),
      );
      for (
        var i = 0;
        i < 100 && find.byType(LyricSearchPage).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(LyricSearchPage), findsNothing);
      final saved = await tester.runAsync(
        () => store.read(
          const LyricRequest(trackId: 'original', platform: 'B'),
          manual: true,
        ),
      );
      expect(saved!.romanization, '[00:00.00]roma');
      expect(
        await tester.runAsync(
          () => store.hasManual(
            const LyricRequest(trackId: 'composite|id', platform: 'A'),
          ),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'startup searches once across platform refresh and selected tab taps',
    (tester) async {
      await open(tester);
      expect(api.calls, ['B']);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LyricSearchPage)),
      );
      container.invalidate(onlinePlatformsProvider);
      await tester.pumpAndSettle();
      (container.read(appConfigProvider.notifier) as _Config).changeLocale();
      await tester.pumpAndSettle();
      await tester.tap(find.text('网易'));
      await tester.pumpAndSettle();
      expect(api.calls, ['B']);
      expect(find.text('Candidate'), findsOneWidget);
    },
  );

  testWidgets(
    'switch submits edited input; clear actions and keyboard search work',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'New song');
      await tester.enterText(
        find.byType(TextField).last,
        'One、Two， Three, Four',
      );
      expect(api.calls, ['B']);
      await tester.tap(find.text('QQ'));
      await tester.pump();
      expect(api.lastName, 'New song');
      expect(api.lastArtists, ['One', 'Two', 'Three', 'Four']);
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('清空歌名'));
      await tester.pump();
      expect(find.text('Candidate'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
      await search(tester);
      expect(find.text('请补齐歌名和歌手'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Keyboard song');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(api.calls, ['B', 'A', 'A']);
      expect(api.lastName, 'Keyboard song');
      await tester.tap(find.byTooltip('清空歌手'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '',
      );
      api.pending['A']!.complete([_candidate]);
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsNothing);
    },
  );

  testWidgets('search failure can retry and empty results are explicit', (
    tester,
  ) async {
    await open(tester);
    api.pending['B']!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('歌词搜索失败，请重试'), findsOneWidget);
    await search(tester);
    expect(api.calls, ['B', 'B']);
    api.pending['B']!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('没有找到歌词，试试其他平台或关键词'), findsOneWidget);
  });

  testWidgets(
    'selection disables form, tabs and submit while preserving target hint',
    (tester) async {
      await open(tester);
      api.pending['B']!.complete([_candidate]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Candidate'));
      await tester.pump();
      expect(find.text('为「Song」选择歌词'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((f) => f.enabled == false),
        isTrue,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '搜索'))
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('QQ'), warnIfMissed: false);
      await tester.pump();
      expect(api.calls, ['B']);
    },
  );

  for (final removeSelected in [true, false]) {
    testWidgets(
      'failed selection reconciles ${removeSelected ? 'removed' : 'unchanged'} platform after refresh',
      (tester) async {
        api = _Api();
        var platforms = [
          for (final id in ['A', 'B'])
            OnlinePlatform(
              id: id,
              name: id,
              shortName: id,
              status: 1,
              featureSupportFlag: PlatformFeatureSupportFlag.searchLyric,
            ),
        ];
        await open(tester, loadPlatforms: () async => platforms);
        api.pending['B']!.complete([_candidate]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Candidate'));
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LyricSearchPage)),
        );
        platforms = platforms
            .where((p) => !removeSelected || p.id == 'A')
            .toList();
        container.invalidate(onlinePlatformsProvider);
        await tester.pump();
        await tester.pump();
        expect(api.calls, ['B']);
        expect(
          tester
              .widget<OnlinePlatformTabs>(find.byType(OnlinePlatformTabs))
              .selectedId,
          'B',
        );
        api.candidate.completeError(StateError('candidate fetch failed'));
        await tester.pump();
        await tester.pump();
        expect(api.calls, removeSelected ? ['B', 'A'] : ['B']);
        expect(
          tester
              .widget<OnlinePlatformTabs>(find.byType(OnlinePlatformTabs))
              .selectedId,
          removeSelected ? 'A' : 'B',
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '搜索'))
              .onPressed,
          isNotNull,
        );
        if (removeSelected) {
          expect(find.text('Candidate'), findsNothing);
          api.pending['A']!.complete([]);
        } else {
          expect(find.text('Candidate'), findsOneWidget);
        }
        await tester.pumpAndSettle();
        expect(api.calls, removeSelected ? ['B', 'A'] : ['B']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'async platform loading retries then auto searches exactly once',
    (tester) async {
      var request = Completer<List<OnlinePlatform>>();
      await open(tester, loadPlatforms: () => request.future);
      expect(api.calls, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      request.completeError(StateError('platform failure'));
      await tester.pumpAndSettle();
      expect(find.text('平台加载失败，重试'), findsOneWidget);
      request = Completer<List<OnlinePlatform>>();
      await tester.tap(find.text('平台加载失败，重试'));
      await tester.pump();
      request.complete([
        OnlinePlatform(
          id: 'A',
          name: 'QQ音乐',
          shortName: 'QQ',
          status: 1,
          featureSupportFlag: PlatformFeatureSupportFlag.searchLyric,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(api.calls, ['A']);
      api.pending['A']!.complete([]);
      await tester.pumpAndSettle();
      expect(api.calls, ['A']);
    },
  );

  testWidgets('missing title never starts an automatic request', (
    tester,
  ) async {
    await open(
      tester,
      target: const PlayerTrack(
        id: 'missing',
        title: '',
        artist: 'Artist',
        platform: 'B',
      ),
    );
    expect(api.calls, isEmpty);
    expect(find.text('请补齐歌名和歌手'), findsOneWidget);
    await tester.tap(find.text('QQ'));
    await tester.pump();
    expect(api.calls, isEmpty);
  });

  testWidgets('late previous-platform failure cannot replace current results', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('QQ'));
    await tester.pump();
    api.pending['A']!.complete([_candidate]);
    await tester.pumpAndSettle();
    api.pending['B']!.completeError(StateError('old failure'));
    await tester.pumpAndSettle();
    expect(find.text('Candidate'), findsOneWidget);
    expect(find.text('歌词搜索失败，请重试'), findsNothing);
  });

  for (final scenario in [
    ('mobile', const Size(390, 780), 1.0, false),
    ('desktop', const Size(1100, 760), 1.0, false),
    ('narrow_large_text', const Size(320, 640), 2.0, true),
  ]) {
    testWidgets('compact actual app theme results ${scenario.$1}', (
      tester,
    ) async {
      await _loadFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.$2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await open(
        tester,
        target: const PlayerTrack(
          id: 'original',
          title: '城市回声',
          artist: '陈一',
          platform: 'B',
        ),
        textScale: scenario.$3,
        dark: scenario.$4,
      );
      api.pending['B']!.complete([
        for (var i = 0; i < 40; i++)
          LyricCandidate(
            platform: 'B',
            id: '$i',
            name: switch (i % 4) {
              0 => '城市回声',
              1 => '城市回声 (Live at the Glass Rooftop)',
              2 => '城市回声 · 钢琴版',
              _ =>
                '城市回声 — A very long alternative recording from the evening concert',
            },
            artistNames: [
              i % 4 == 3
                  ? '陈一、林可 · City Echo Ensemble with Guest Musicians'
                  : '陈一',
            ],
            duration: i % 4 == 2
                ? 0
                : i % 4 == 3
                ? -1
                : 246 + i,
          ),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('0:00'), findsNothing);
      expect(find.text('-1:59'), findsNothing);
      final unknownRow = find.ancestor(
        of: find.text('城市回声 · 钢琴版').first,
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(unknownRow).trailing, isNull);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ListTile).evaluate().length, lessThan(40));
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        final decoration = field.decoration!.applyDefaults(
          _theme(scenario.$4).inputDecorationTheme,
        );
        expect(decoration.filled, isFalse);
        expect(decoration.labelText, isNull);
        expect(decoration.enabledBorder, isA<UnderlineInputBorder>());
        expect(decoration.focusedBorder, isA<UnderlineInputBorder>());
      }
      if (scenario.$3 == 1) {
        expect(
          tester.getSize(find.byType(TextField).first).height,
          lessThanOrEqualTo(50),
        );
        expect(
          tester.getTopLeft(find.byType(ListTile).first).dy,
          lessThan(270),
        );
      }
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/lyric_search_${scenario.$1}.png'),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _Platforms extends OnlinePlatformsController {
  _Platforms(this.empty, [this.load]);
  final Future<List<OnlinePlatform>> Function()? load;
  final bool empty;
  @override
  Future<List<OnlinePlatform>> build() async => load != null
      ? await load!()
      : empty
      ? []
      : [
          for (final id in ['A', 'B', 'unavailable'])
            OnlinePlatform(
              id: id,
              name: 'Platform $id',
              shortName: id == 'A'
                  ? 'QQ'
                  : id == 'B'
                  ? '网易'
                  : id,
              status: id == 'unavailable' ? 0 : 1,
              featureSupportFlag: PlatformFeatureSupportFlag.searchLyric,
            ),
          OnlinePlatform(
            id: 'song-only',
            name: 'song-only',
            shortName: 'song-only',
            status: 1,
            featureSupportFlag: PlatformFeatureSupportFlag.searchLyricSong,
          ),
        ];
}

class _Api extends OnlineApiClient {
  _Api() : super(Dio());
  final calls = <String>[];
  final pending = <String, Completer<List<LyricCandidate>>>{};
  final candidate = Completer<RawLyricBundle>();
  int? lastDuration;
  String? lastName;
  List<String>? lastArtists;
  @override
  Future<List<LyricCandidate>> searchLyricCandidates({
    required String platform,
    required String name,
    required List<String> artistNames,
    String albumName = '',
    int duration = 0,
  }) {
    calls.add(platform);
    lastDuration = duration;
    lastName = name;
    lastArtists = artistNames;
    return (pending[platform] = Completer<List<LyricCandidate>>()).future;
  }

  @override
  Future<RawLyricBundle> fetchLyricCandidate(LyricCandidate candidate) =>
      this.candidate.future;
}

class _Config extends AppConfigController {
  void changeLocale() => state = state.copyWith(localeCode: 'en');
  @override
  AppConfigState build() => AppConfigState.initial;
}

ThemeData _theme(bool dark) {
  final skin = AppSkinRegistry.builtIn(
    AppConfigState.initial.themeAccent,
  ).resolve('classic');
  final theme = dark ? AppTheme.dark(skin) : AppTheme.light(skin);
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'SearchRoboto',
        fontFamilyFallback: ['SearchCjk'],
      ),
    ),
    textTheme: theme.textTheme.apply(
      fontFamily: 'SearchRoboto',
      fontFamilyFallback: ['SearchCjk'],
    ),
  );
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final pair in [
      ('SearchRoboto', 'test/assets/fonts/Roboto-Regular.ttf'),
      (
        'SearchCjk',
        'test/assets/fonts/DroidSansFallback-LyricSearchSubset.ttf',
      ),
    ]) {
      await (FontLoader(pair.$1)
            ..addFont(File(pair.$2).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}
