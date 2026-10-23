import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/cadenza_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/lyric_layout_cache_key.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/partita_lyric_layout.dart';

void main() {
  final builders = <String, LyricLayoutCacheKey Function(LyricDocument)>{
    'Cadenza': (document) {
      final engine = CadenzaLyricLayoutEngine(document);
      return buildCadenzaLineLayoutCacheKey(
        documentSignature: engine.documentSignature,
        renderLineIndex: 0,
        line: document.lines.first,
        options: const CadenzaLyricLayoutOptions(
          stageSize: Size(400, 600),
          textStyle: TextStyle(fontSize: 40),
        ),
      );
    },
    'Partita': (document) {
      final engine = PartitaLyricLayoutEngine(document);
      return buildPartitaLineLayoutCacheKey(
        documentSignature: engine.documentSignature,
        sourceLineIndex: 0,
        line: document.lines.first,
        options: const PartitaLyricLayoutOptions(
          stageSize: Size(400, 600),
          textStyle: TextStyle(fontSize: 40),
        ),
      );
    },
    'Monet': (document) {
      final engine = MonetLyricLayoutEngine(document);
      return buildMonetLyricLayoutCacheKey(
        documentSignature: engine.documentSignature,
        entry: engine
            .buildVisibleWindow(position: engine.resolvePosition(Duration.zero))
            .first,
        options: const MonetLyricLayoutOptions(
          railSize: Size(400, 600),
          activeTextStyle: TextStyle(fontSize: 40),
          inactiveTextStyle: TextStyle(fontSize: 24),
          translationTextStyle: TextStyle(fontSize: 16),
        ),
      );
    },
  };

  for (final entry in builders.entries) {
    test('${entry.key} line keys do not copy the rest of the document', () {
      const first = LyricLine(
        start: Duration.zero,
        end: Duration(seconds: 3),
        text: 'first line',
      );
      const shortDocument = LyricDocument(lines: [first]);
      final longDocument = LyricDocument(
        lines: [
          first,
          for (var index = 1; index < 200; index++)
            LyricLine(
              start: Duration(seconds: index * 3),
              end: Duration(seconds: index * 3 + 3),
              text: 'Additional lyric line $index with translation and timing',
              translation: '第 $index 行翻译',
            ),
        ],
      );
      final shortKey = entry.value(shortDocument);
      final longKey = entry.value(longDocument);

      expect(longKey.layoutSignature, shortKey.layoutSignature);
      expect(
        longKey.documentSignature.length,
        greaterThan(shortKey.documentSignature.length * 100),
      );
      expect(longKey, isNot(shortKey));
      expect(entry.value(longDocument), longKey);
      expect(
        entry.value(LyricDocument(lines: longDocument.lines, offset: 1)),
        isNot(longKey),
      );
    });
  }

  test('line keys retain the shared signature across layout variants', () {
    final signature = List.filled(1000, 'document').join();
    const line = LyricLine(start: Duration.zero, text: 'line');
    final keys = [
      for (var width = 300; width < 348; width++)
        buildCadenzaLineLayoutCacheKey(
          documentSignature: signature,
          renderLineIndex: 0,
          line: line,
          options: CadenzaLyricLayoutOptions(
            stageSize: Size(width.toDouble(), 600),
            textStyle: const TextStyle(fontSize: 40),
          ),
        ),
    ];
    expect(
      keys.every((key) => identical(key.documentSignature, signature)),
      isTrue,
    );
    expect(
      keys.map((key) => key.layoutSignature.length),
      everyElement(lessThan(500)),
    );
    expect(keys.toSet(), hasLength(48));
  });
}
