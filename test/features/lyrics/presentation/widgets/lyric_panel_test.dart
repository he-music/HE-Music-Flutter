import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/lyric_highlight_color_helper.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_panel.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/lyric_photo_dimmer.dart';

final _testLyricPositionProvider =
    NotifierProvider<_TestLyricPositionController, Duration>(
      _TestLyricPositionController.new,
    );

void main() {
  test('wide font scale is opt in and keeps the selected font proportions', () {
    for (final preset in AppLyricFontPreset.values) {
      final normal = buildLyricStyle(
        compact: false,
        fontPreset: preset,
        activeHighlightColor: Colors.cyan,
      );
      final wide = buildLyricStyle(
        compact: false,
        fontPreset: preset,
        activeHighlightColor: Colors.cyan,
        fontScale: 1.5,
      );
      expect(wide.textStyle.fontSize, normal.textStyle.fontSize! * 1.5);
      expect(wide.activeStyle.fontSize, normal.activeStyle.fontSize! * 1.5);
      expect(
        wide.translationStyle.fontSize,
        normal.translationStyle.fontSize! * 1.5,
      );
      expect(wide.lineGap, normal.lineGap * 1.5);
    }
  });

  test('buildFlutterLyricModel should pass lyric offset to flutter_lyric', () {
    const document = LyricDocument(
      offset: 180,
      lines: <LyricLine>[
        LyricLine(
          start: Duration(seconds: 1),
          text: '第一句',
          tokens: <LyricToken>[
            LyricToken(
              text: '第',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 200),
            ),
          ],
        ),
      ],
    );

    final model = buildFlutterLyricModel(document, enableWordByWordLyric: true);

    expect(model, isA<flm.LyricModel>());
    expect(model.offset, 180);
    expect(model.lines, hasLength(1));
    expect(model.lines.single.text, '第一句');
    expect(model.lines.single.words, hasLength(1));
  });

  test('advancing and delaying apply once and preserve the source offset', () {
    const document = LyricDocument(
      offset: 250,
      lines: [
        LyricLine(start: Duration.zero, text: 'first'),
        LyricLine(start: Duration(seconds: 1), text: 'second'),
      ],
    );
    final controller = fl.LyricController();
    addTearDown(controller.dispose);
    for (final correction in [100, -100, 0]) {
      final adjusted = document.withAdditionalOffset(correction);
      expect(adjusted.offset, 250 + correction);
      expect(adjusted.lines, same(document.lines));
      controller.loadLyricModel(
        buildFlutterLyricModel(adjusted, enableWordByWordLyric: true),
      );
      final boundary = Duration(milliseconds: 1000 - adjusted.offset);
      expect(controller.getIndexByProgress(boundary), 1);
      expect(
        controller.getIndexByProgress(
          boundary - const Duration(milliseconds: 1),
        ),
        0,
      );
    }
  });

  for (final offset in [100, -100, 1500]) {
    testWidgets(
      'tap-to-seek accounts for lyric offset $offset and clamps to zero',
      (tester) async {
        final seeks = <Duration>[];
        await tester.pumpWidget(
          _buildLyricPanelTestApp(
            document: LyricDocument(
              offset: offset,
              lines: const [
                LyricLine(start: Duration(seconds: 1), text: 'tap'),
              ],
            ),
            onSeek: seeks.add,
          ),
        );
        await tester.pump();
        final controller = tester
            .widget<fl.LyricView>(find.byType(fl.LyricView))
            .controller;
        controller.notifyEvent(fl.LyricEvent.tapLine, 0);
        final expected = Duration(milliseconds: 1000 - offset);
        expect(seeks, [expected.isNegative ? Duration.zero : expected]);
      },
    );
  }

  test('buildFlutterLyricModel should omit word timeline when disabled', () {
    const document = LyricDocument(
      lines: <LyricLine>[
        LyricLine(
          start: Duration(seconds: 1),
          text: '第一句',
          tokens: <LyricToken>[
            LyricToken(
              text: '第',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 200),
            ),
          ],
        ),
      ],
    );

    final model = buildFlutterLyricModel(
      document,
      enableWordByWordLyric: false,
    );

    expect(model.lines.single.words, isNull);
  });

  test(
    'buildLyricDocumentCacheKey should change when lyric content changes',
    () {
      const first = LyricDocument(
        lines: <LyricLine>[LyricLine(start: Duration(seconds: 1), text: '第一句')],
      );
      const second = LyricDocument(
        lines: <LyricLine>[LyricLine(start: Duration(seconds: 1), text: '第二句')],
      );

      final firstKey = buildLyricDocumentCacheKey(
        'song-1',
        first,
        enableWordByWordLyric: true,
      );
      final secondKey = buildLyricDocumentCacheKey(
        'song-1',
        second,
        enableWordByWordLyric: true,
      );

      expect(firstKey, isNot(secondKey));
    },
  );

  test('buildLyricStyle should apply full preset size and highlight color', () {
    final style = buildLyricStyle(
      compact: false,
      fontPreset: AppLyricFontPreset.large,
      activeHighlightColor: Colors.amber,
    );

    expect(style.textStyle.fontSize, 22);
    expect(style.activeStyle.fontSize, 28);
    expect(style.translationStyle.fontSize, 16);
    expect(style.activeHighlightColor, Colors.amber);
  });

  test(
    'buildLyricStyle should apply compact preset size and highlight color',
    () {
      final style = buildLyricStyle(
        compact: true,
        fontPreset: AppLyricFontPreset.small,
        activeHighlightColor: Colors.cyan,
      );

      expect(style.textStyle.fontSize, 11);
      expect(style.activeStyle.fontSize, 15);
      expect(style.translationStyle.fontSize, 8);
      expect(style.activeHighlightColor, Colors.cyan);
    },
  );

  test(
    'resolveLyricHighlightColor should use auto color when mode is auto',
    () {
      final color = resolveLyricHighlightColor(
        AppConfigState.initial.copyWith(
          lyricHighlightMode: AppLyricHighlightMode.auto,
        ),
        autoColor: Colors.green,
      );

      expect(color, Colors.green);
    },
  );

  test('resolveLyricHighlightColor should fallback to sky on auto failure', () {
    final color = resolveLyricHighlightColor(
      AppConfigState.initial.copyWith(
        lyricHighlightMode: AppLyricHighlightMode.auto,
      ),
    );

    expect(color, AppLyricHighlightColor.sky.color);
  });

  test('resolveLyricHighlightColor should use custom color when available', () {
    final color = resolveLyricHighlightColor(
      AppConfigState.initial.copyWith(
        lyricHighlightMode: AppLyricHighlightMode.custom,
        lyricHighlightCustomColor: 0xFF123456,
      ),
    );

    expect(color, const Color(0xFF123456));
  });

  testWidgets('photo brightness changes do not rebuild lyric content', (
    tester,
  ) async {
    await tester.pumpWidget(_buildLyricPanelTestApp());
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LyricPanel)),
    );
    final initialView = tester.widget<fl.LyricView>(find.byType(fl.LyricView));
    for (var index = 0; index < 10; index++) {
      container
          .read(appConfigProvider.notifier)
          .setLyricPhotoBrightness(0.9 - index * 0.01, persist: false);
      await tester.pump();
      expect(
        tester.widget<fl.LyricView>(find.byType(fl.LyricView)),
        same(initialView),
      );
      final dimmer = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('lyric-photo-dimmer')),
      );
      expect(dimmer.color.a, closeTo((0.1 + index * 0.01) * 0.75, 0.001));
    }
  });

  testWidgets('position updates do not rebuild LyricView', (tester) async {
    await tester.pumpWidget(_buildLyricPanelTestApp());
    await tester.pump();

    final initialView = tester.widget<fl.LyricView>(find.byType(fl.LyricView));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LyricPanel)),
    );

    container
        .read(_testLyricPositionProvider.notifier)
        .update(const Duration(seconds: 2));
    await tester.pump();

    expect(
      tester.widget<fl.LyricView>(find.byType(fl.LyricView)),
      same(initialView),
    );
  });

  testWidgets('lyric color and word timing preferences still update content', (
    tester,
  ) async {
    await tester.pumpWidget(_buildLyricPanelTestApp());
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LyricPanel)),
    );
    final controller =
        container.read(appConfigProvider.notifier) as _TestAppConfigController;
    for (final preset in [
      AppLyricHighlightColor.amber,
      AppLyricHighlightColor.emerald,
    ]) {
      controller.updateConfig(
        container
            .read(appConfigProvider)
            .copyWith(
              lyricHighlightMode: AppLyricHighlightMode.preset,
              lyricHighlightPreset: preset,
            ),
      );
      await tester.pump();
      expect(
        tester
            .widget<fl.LyricView>(find.byType(fl.LyricView))
            .style!
            .activeHighlightColor,
        preset.color,
      );
    }
    for (final color in [0xFF123456, 0xFF654321]) {
      controller.updateConfig(
        container
            .read(appConfigProvider)
            .copyWith(
              lyricHighlightMode: AppLyricHighlightMode.custom,
              lyricHighlightCustomColor: color,
            ),
      );
      await tester.pump();
      expect(
        tester
            .widget<fl.LyricView>(find.byType(fl.LyricView))
            .style!
            .activeHighlightColor,
        Color(color),
      );
    }
    final previousModel = tester
        .widget<fl.LyricView>(find.byType(fl.LyricView))
        .controller
        .lyricNotifier
        .value;
    controller.updateConfig(
      container.read(appConfigProvider).copyWith(enableWordByWordLyric: false),
    );
    await tester.pump();
    expect(
      tester
          .widget<fl.LyricView>(find.byType(fl.LyricView))
          .controller
          .lyricNotifier
          .value,
      isNot(same(previousModel)),
    );
  });

  testWidgets('lyric style updates rebuild LyricView', (tester) async {
    await tester.pumpWidget(_buildLyricPanelTestApp());
    await tester.pump();

    final initialView = tester.widget<fl.LyricView>(find.byType(fl.LyricView));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LyricPanel)),
    );

    container
        .read(appConfigProvider.notifier)
        .setLyricFontPreset(AppLyricFontPreset.large);
    await tester.pump();

    expect(
      tester.widget<fl.LyricView>(find.byType(fl.LyricView)),
      isNot(same(initialView)),
    );
  });
}

Widget _buildLyricPanelTestApp({
  LyricDocument document = const LyricDocument(
    lines: [LyricLine(start: Duration.zero, text: '测试歌词')],
  ),
  ValueChanged<Duration>? onSeek,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      currentLyricRequestProvider.overrideWithValue(null),
      currentLyricDocumentProvider.overrideWithValue(
        AsyncData<LyricDocument>(document),
      ),
      lyricPositionProvider.overrideWith(
        (ref) => ref.watch(_testLyricPositionProvider),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const LyricPhotoDimmer(),
            LyricPanel(emptyText: '暂无歌词', onSeek: onSeek),
          ],
        ),
      ),
    ),
  );
}

class _TestLyricPositionController extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  void update(Duration value) {
    state = value;
  }
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  void updateConfig(AppConfigState config) => state = config;

  @override
  void setLyricFontPreset(AppLyricFontPreset preset) {
    state = state.copyWith(lyricFontPreset: preset);
  }
}
