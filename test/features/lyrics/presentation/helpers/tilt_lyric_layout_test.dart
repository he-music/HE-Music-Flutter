import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/tilt_lyric_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 32);
  const tiltStyle = TextStyle(fontSize: 32, fontStyle: FontStyle.italic);

  TiltLyricLayoutOptions options({Size size = const Size(360, 240)}) {
    return TiltLyricLayoutOptions(
      stageSize: size,
      normalStyle: style,
      tiltStyle: tiltStyle,
    );
  }

  test('splits only at grapheme boundaries and preserves source text', () {
    const line = LyricLine(
      start: Duration(seconds: 1),
      end: Duration(seconds: 5),
      text: '你👩‍💻好，世界',
    );
    final engine = TiltLyricLayoutEngine.fromDocument(
      const LyricDocument(lines: <LyricLine>[line]),
    );
    final layout = engine.layoutLine(sourceLineIndex: 0, options: options());

    expect(layout, isNotNull);
    expect(layout!.segments.map((segment) => segment.text).join(), line.text);
    for (final segment in layout.segments) {
      for (final grapheme in segment.graphemes) {
        expect(
          segment.text.substring(
            grapheme.startOffset - segment.startOffset,
            grapheme.endOffset - segment.startOffset,
          ),
          grapheme.text,
        );
      }
    }
  });

  test('projects valid token timing to graphemes and falls back as a line', () {
    const valid = LyricLine(
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      text: '你好',
      tokens: <LyricToken>[
        LyricToken(
          text: '你',
          startOffset: Duration.zero,
          duration: Duration(seconds: 1),
        ),
        LyricToken(
          text: '好',
          startOffset: Duration(seconds: 1),
          duration: Duration(seconds: 1),
        ),
      ],
    );
    const invalid = LyricLine(
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      text: '你好',
      tokens: <LyricToken>[
        LyricToken(
          text: '你',
          startOffset: Duration.zero,
          duration: Duration(seconds: 3),
        ),
        LyricToken(
          text: '好',
          startOffset: Duration(seconds: 1),
          duration: Duration(seconds: 1),
        ),
      ],
    );
    final validLayout = TiltLyricLayoutEngine.fromDocument(
      const LyricDocument(lines: <LyricLine>[valid]),
    ).layoutLine(sourceLineIndex: 0, options: options());
    final invalidLayout = TiltLyricLayoutEngine.fromDocument(
      const LyricDocument(lines: <LyricLine>[invalid]),
    ).layoutLine(sourceLineIndex: 0, options: options());

    expect(validLayout!.hasFineTiming, isTrue);
    expect(
      validLayout.segments
          .expand((segment) => segment.graphemes)
          .every((item) => item.isTimed),
      isTrue,
    );
    expect(invalidLayout!.hasFineTiming, isFalse);
    expect(
      invalidLayout.segments
          .expand((segment) => segment.graphemes)
          .every((item) => !item.isTimed),
      isTrue,
    );
  });

  test('applies document offset for active lines and seek targets', () {
    const document = LyricDocument(
      offset: 500,
      lines: <LyricLine>[
        LyricLine(
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          text: 'first',
        ),
      ],
    );
    final engine = TiltLyricLayoutEngine.fromDocument(document);
    final position = engine.resolvePosition(const Duration(milliseconds: 600));

    expect(position.timelinePosition, const Duration(milliseconds: 1100));
    expect(position.activeIndex, 0);
    expect(engine.seekPositionFor(0), const Duration(milliseconds: 500));
  });

  test('keeps layout cache bounded and keys style/size changes', () {
    final engine = TiltLyricLayoutEngine.fromDocument(
      const LyricDocument(
        lines: <LyricLine>[
          LyricLine(start: Duration.zero, text: 'one'),
          LyricLine(start: Duration(seconds: 1), text: 'two'),
        ],
      ),
    );
    final cache = TiltLyricLayoutCache(maximumEntries: 1);
    final first = engine.layoutLine(
      sourceLineIndex: 0,
      options: options(),
      cache: cache,
    );
    final second = engine.layoutLine(
      sourceLineIndex: 1,
      options: options(),
      cache: cache,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(cache.length, 1);
    expect(first!.cacheKey, isNot(second!.cacheKey));
  });

  test(
    'keeps hit rectangles within a finite stage after constrained scaling',
    () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(seconds: 2),
        text: '这是一句非常长的歌词用于检查布局缩放和命中区域',
      );
      final layout =
          TiltLyricLayoutEngine.fromDocument(
            const LyricDocument(lines: <LyricLine>[line]),
          ).layoutLine(
            sourceLineIndex: 0,
            options: options(size: const Size(120, 100)),
          );

      expect(layout, isNotNull);
      expect(
        layout!.segments.every((segment) => segment.size.width <= 120),
        isTrue,
      );
      expect(
        layout.segments.every((segment) => segment.hitRect.isFinite),
        isTrue,
      );
    },
  );
}
