import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/lyric_panel.dart';

void main() {
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
}
