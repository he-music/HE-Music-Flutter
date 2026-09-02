import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/cadenza_lyric_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cadenza render hints', () {
    test('classifies normal short and micro lines at Folia thresholds', () {
      const normal = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 180),
        text: 'normal',
      );
      const short = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 100),
        text: 'short',
      );
      const micro = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 99),
        text: 'micro',
      );

      expect(resolveCadenzaTimingClass(normal), CadenzaTimingClass.normal);
      expect(resolveCadenzaTimingClass(short), CadenzaTimingClass.short);
      expect(resolveCadenzaTimingClass(micro), CadenzaTimingClass.micro);
      expect(resolveCadenzaRevealProfile(normal), CadenzaRevealProfile.normal);
      expect(resolveCadenzaRevealProfile(short), CadenzaRevealProfile.fast);
      expect(resolveCadenzaRevealProfile(micro), CadenzaRevealProfile.instant);
      expect(
        resolveCadenzaLineTransitionDuration(normal),
        const Duration(milliseconds: 300),
      );
      expect(
        resolveCadenzaLineTransitionDuration(short),
        const Duration(milliseconds: 160),
      );
      expect(resolveCadenzaLineTransitionDuration(micro), Duration.zero);
    });

    test('uses profile lookahead and preserves the micro render floor', () {
      expect(
        resolveCadenzaLookahead(CadenzaTimingClass.normal),
        const Duration(milliseconds: 180),
      );
      expect(
        resolveCadenzaLookahead(CadenzaTimingClass.short),
        const Duration(milliseconds: 45),
      );
      expect(resolveCadenzaLookahead(CadenzaTimingClass.micro), Duration.zero);

      const micro = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(milliseconds: 2050),
        text: 'flash',
      );
      const zero = LyricLine(
        start: Duration(seconds: 3),
        end: Duration(seconds: 3),
        text: 'zero',
      );
      expect(
        resolveCadenzaLineRenderEnd(micro),
        const Duration(milliseconds: 2067),
      );
      expect(
        resolveCadenzaLineRenderEnd(zero),
        const Duration(milliseconds: 3067),
      );
      expect(
        resolveCadenzaWordActiveEnd(
          line: micro,
          start: micro.start,
          end: micro.end,
        ),
        const Duration(milliseconds: 2067),
      );
    });

    test('extends short word activity without exceeding line render end', () {
      const line = LyricLine(
        start: Duration.zero,
        end: Duration(milliseconds: 150),
        text: 'ab',
        tokens: <LyricToken>[
          LyricToken(
            text: 'a',
            startOffset: Duration.zero,
            duration: Duration(milliseconds: 40),
          ),
          LyricToken(
            text: 'b',
            startOffset: Duration(milliseconds: 40),
            duration: Duration(milliseconds: 110),
          ),
        ],
      );

      final renderEnd = resolveCadenzaLineRenderEnd(line)!;
      final activeEnd = resolveCadenzaWordActiveEnd(
        line: line,
        start: Duration.zero,
        end: const Duration(milliseconds: 40),
      )!;
      expect(renderEnd, greaterThanOrEqualTo(line.end!));
      expect(activeEnd, const Duration(milliseconds: 120));
      expect(activeEnd, lessThanOrEqualTo(renderEnd));
    });
  });

  group('Cadenza timeline', () {
    test(
      'applies document offset and inserts only long internal interludes',
      () {
        final engine = CadenzaLyricLayoutEngine.fromDocument(
          const LyricDocument(
            offset: 500,
            lines: <LyricLine>[
              LyricLine(
                start: Duration(seconds: 1),
                end: Duration(seconds: 2),
                text: 'first',
              ),
              LyricLine(
                start: Duration(seconds: 8),
                end: Duration(seconds: 9),
                text: 'second',
              ),
              LyricLine(
                start: Duration(seconds: 10),
                end: Duration(seconds: 11),
                text: 'third',
              ),
            ],
          ),
        );

        final first = engine.resolvePosition(const Duration(milliseconds: 600));
        expect(first.timelinePosition, const Duration(milliseconds: 1100));
        expect(first.activeIndex, 0);
        expect(first.recentIndex, isNull);
        expect(first.upcomingIndex, 1);
        expect(engine.lineCount, 4);

        final gap = engine.resolvePosition(const Duration(seconds: 4));
        expect(gap.timelinePosition, const Duration(milliseconds: 4500));
        expect(gap.activeIndex, 1);
        expect(gap.recentIndex, 0);
        expect(gap.upcomingIndex, 2);
        expect(engine.isInterludeAt(1), isTrue);
        expect(engine.lineAt(1)?.text, '......');
        expect(engine.lineAt(1)?.start, const Duration(milliseconds: 2050));
        expect(engine.lineAt(1)?.end, const Duration(milliseconds: 7950));
        expect(engine.lineAt(1)?.tokens, hasLength(6));
        expect(engine.isInterludeAt(3), isFalse);
        expect(engine.document.lines, hasLength(3));
      },
    );

    test('adds a leading interlude with insets and gives it no hero', () {
      final engine = CadenzaLyricLayoutEngine.fromDocument(
        const LyricDocument(
          lines: <LyricLine>[
            LyricLine(
              start: Duration(seconds: 5),
              end: Duration(seconds: 6),
              text: 'late opening',
            ),
          ],
        ),
      );

      expect(engine.lineCount, 2);
      expect(engine.isInterludeAt(0), isTrue);
      expect(engine.lineAt(0)?.start, const Duration(milliseconds: 500));
      expect(engine.lineAt(0)?.end, const Duration(milliseconds: 4500));
      expect(engine.resolvePosition(const Duration(seconds: 2)).activeIndex, 0);

      final layout = engine.layoutLine(
        renderLineIndex: 0,
        options: _options(),
      )!;
      expect(layout.isInterlude, isTrue);
      expect(layout.sourceLineIndex, -1);
      expect(layout.heroWordIndex, isNull);
      expect(layout.fragments, isNotEmpty);
    });

    test(
      'resolves empty pre-roll and render-end positions deterministically',
      () {
        final empty = CadenzaLyricLayoutEngine.fromDocument(
          const LyricDocument.empty(),
        ).resolvePosition(Duration.zero);
        expect(empty.activeIndex, isNull);
        expect(empty.recentIndex, isNull);
        expect(empty.upcomingIndex, isNull);

        final engine = CadenzaLyricLayoutEngine.fromDocument(
          const LyricDocument(
            lines: <LyricLine>[
              LyricLine(
                start: Duration(seconds: 1),
                end: Duration(seconds: 2),
                text: 'one',
              ),
            ],
          ),
        );
        expect(engine.resolvePosition(Duration.zero).upcomingIndex, 0);
        final renderEnd = resolveCadenzaLineRenderEnd(engine.lineAt(0)!)!;
        expect(engine.resolvePosition(renderEnd).activeIndex, 0);
        expect(
          engine
              .resolvePosition(renderEnd + const Duration(microseconds: 1))
              .activeIndex,
          isNull,
        );
      },
    );
  });

  group('Cadenza display words and strict timing', () {
    test(
      'preserves CJK emoji combining graphemes punctuation and whitespace',
      () {
        const line = LyricLine(
          start: Duration.zero,
          text: '你 A e\u0301 👩🏽‍🚀，你',
        );

        final words = buildCadenzaDisplayWords(line);
        final slices = words.expand((word) => word.graphemes).toList();
        expect(words.map((word) => word.text).join(), line.text);
        expect(slices.map((slice) => slice.grapheme).join(), line.text);
        expect(
          slices.where((slice) => slice.grapheme == 'e\u0301'),
          hasLength(1),
        );
        expect(
          slices.where((slice) => slice.grapheme == '👩🏽‍🚀'),
          hasLength(1),
        );
        expect(words.every((word) => word.sourceTokenIndexes.isEmpty), isTrue);
        for (var index = 1; index < slices.length; index++) {
          expect(
            slices[index].textStartOffset,
            slices[index - 1].textEndOffset,
          );
        }
      },
    );

    test(
      'keeps repeated token occurrences distinct with sticky text intact',
      () {
        final line = _timedLine(
          text: 'echo echo， echo',
          tokenTexts: const <String>['echo', ' ', 'echo', '，', ' ', 'echo'],
        );

        final words = buildCadenzaDisplayWords(line);
        expect(hasValidCadenzaTokenTiming(line), isTrue);
        expect(words.map((word) => word.text), <String>[
          'echo ',
          'echo， ',
          'echo',
        ]);
        expect(words[0].sourceTokenIndexes, <int>[0, 1]);
        expect(words[1].sourceTokenIndexes, <int>[2, 3, 4]);
        expect(words[2].sourceTokenIndexes, <int>[5]);
        expect(words.map((word) => word.id).toSet(), hasLength(3));
        expect(words.map((word) => word.text).join(), line.text);
      },
    );

    test('valid timing is absolute and divides a token by grapheme', () {
      const line = LyricLine(
        start: Duration(seconds: 2),
        end: Duration(seconds: 3),
        text: '你好',
        tokens: <LyricToken>[
          LyricToken(
            text: '你好',
            startOffset: Duration.zero,
            duration: Duration(seconds: 1),
          ),
        ],
      );

      final word = buildCadenzaDisplayWords(line).single;
      expect(hasValidCadenzaTokenTiming(line), isTrue);
      expect(word.isTimed, isTrue);
      expect(word.start, const Duration(seconds: 2));
      expect(word.end, const Duration(seconds: 3));
      expect(word.graphemes, hasLength(2));
      expect(word.graphemes.first.start, const Duration(seconds: 2));
      expect(word.graphemes.first.end, const Duration(milliseconds: 2500));
      expect(word.graphemes.last.start, const Duration(milliseconds: 2500));
      expect(word.graphemes.last.end, const Duration(seconds: 3));
    });

    test('invalid timing cases fall back for the complete line', () {
      const invalidLines = <String, LyricLine>{
        'zero duration': LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration.zero,
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration.zero,
              duration: Duration(seconds: 1),
            ),
          ],
        ),
        'negative offset': LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration(milliseconds: -1),
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration(milliseconds: 499),
              duration: Duration(milliseconds: 501),
            ),
          ],
        ),
        'non-monotonic overlap': LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 600),
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration(milliseconds: 500),
              duration: Duration(milliseconds: 400),
            ),
          ],
        ),
        'outside line duration': LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration(milliseconds: 500),
              duration: Duration(milliseconds: 501),
            ),
          ],
        ),
        'text mismatch': LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'ab',
          tokens: <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 500),
            ),
            LyricToken(
              text: 'x',
              startOffset: Duration(milliseconds: 500),
              duration: Duration(milliseconds: 500),
            ),
          ],
        ),
      };

      for (final entry in invalidLines.entries) {
        final words = buildCadenzaDisplayWords(entry.value);
        expect(
          hasValidCadenzaTokenTiming(entry.value),
          isFalse,
          reason: entry.key,
        );
        expect(
          words.map((word) => word.text).join(),
          entry.value.text,
          reason: entry.key,
        );
        expect(words.every((word) => !word.isTimed), isTrue, reason: entry.key);
        expect(
          words
              .expand((word) => word.graphemes)
              .every((slice) => !slice.isTimed),
          isTrue,
          reason: entry.key,
        );

        final layout = _layout(entry.value);
        expect(layout.hasFineTiming, isFalse, reason: entry.key);
        expect(
          layout.fragments.every(
            (fragment) => fragment.start == null && fragment.end == null,
          ),
          isTrue,
          reason: entry.key,
        );
      }
    });
  });

  group('Cadenza measured layout', () {
    test('selects one complete unsplit primary fragment as the hero', () {
      final layout = _layout(
        const LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 2),
          text: 'a centerword z',
        ),
        width: 800,
        height: 420,
      );

      expect(layout.heroWordIndex, 1);
      final heroFragments = layout.fragments
          .where((fragment) => fragment.wordIndex == layout.heroWordIndex)
          .toList();
      expect(heroFragments, hasLength(1));
      final hero = heroFragments.single;
      expect(hero.isPrimaryFragment, isTrue);
      expect(hero.isSplitAcrossLines, isFalse);
      expect(hero.fragmentIndexInWord, 0);
      expect(hero.fragmentCountInWord, 1);
      expect(hero.fragmentStartInWord, 0);
      expect(hero.fragmentEndInWord, hero.word.graphemes.length);
      expect(hero.text, hero.word.text);
      expect(hero.paintScale, greaterThan(1.01));
    });

    test('repeated layout has identical placement and transform values', () {
      const line = LyricLine(
        start: Duration(milliseconds: 1234),
        end: Duration(seconds: 4),
        text: 'first orbit centerword final glow',
      );
      final first = _layout(line, width: 520, height: 380);
      final second = _layout(line, width: 520, height: 380);

      expect(second.heroWordIndex, first.heroWordIndex);
      expect(second.fitScale, first.fitScale);
      expect(second.contentBounds, first.contentBounds);
      expect(second.visualBounds, first.visualBounds);
      expect(second.fragments, hasLength(first.fragments.length));
      for (var index = 0; index < first.fragments.length; index++) {
        final a = first.fragments[index];
        final b = second.fragments[index];
        expect(b.id, a.id);
        expect(b.center, a.center);
        expect(b.paintScale, a.paintScale);
        expect(b.rotation, a.rotation);
        expect(b.passedRotation, a.passedRotation);
        expect(b.passedDrift, a.passedDrift);
        expect(b.bounds, a.bounds);
        expect(b.visualBounds, a.visualBounds);
        expect(b.hitRect, a.hitRect);
      }
    });

    test('ordinary measured fragments do not overlap', () {
      final layout = _layout(
        const LyricLine(
          start: Duration.zero,
          end: Duration(seconds: 4),
          text: 'first orbit centerword final glow',
        ),
        width: 520,
        height: 380,
      );
      expect(layout.fragments.length, greaterThan(3));
      for (var first = 0; first < layout.fragments.length; first++) {
        for (
          var second = first + 1;
          second < layout.fragments.length;
          second++
        ) {
          expect(
            layout.fragments[first].bounds.overlaps(
              layout.fragments[second].bounds,
            ),
            isFalse,
            reason:
                '${layout.fragments[first].text} overlaps '
                '${layout.fragments[second].text}',
          );
        }
      }
    });

    test('splits a narrow long word without splitting or losing graphemes', () {
      const grapheme = 'e\u0301';
      final text = List<String>.filled(48, grapheme).join();
      final layout = _layout(
        LyricLine(start: Duration.zero, text: text),
        width: 120,
        height: 240,
      );

      expect(layout.displayWords, hasLength(1));
      expect(layout.fragments.length, greaterThan(1));
      expect(layout.heroWordIndex, isNull);
      expect(
        layout.fragments.every((fragment) => fragment.isSplitAcrossLines),
        isTrue,
      );
      expect(layout.fragments.map((fragment) => fragment.text).join(), text);
      expect(
        layout.fragments
            .expand((fragment) => fragment.graphemes)
            .map((geometry) => geometry.slice.grapheme),
        everyElement(grapheme),
      );
      expect(
        layout.fragments
            .expand((fragment) => fragment.graphemes)
            .map((geometry) => geometry.slice.grapheme),
        hasLength(48),
      );
      for (var index = 0; index < layout.fragments.length; index++) {
        final fragment = layout.fragments[index];
        expect(fragment.fragmentIndexInWord, index);
        expect(fragment.fragmentCountInWord, layout.fragments.length);
        if (index > 0) {
          expect(
            fragment.fragmentStartInWord,
            layout.fragments[index - 1].fragmentEndInWord,
          );
        }
      }
    });

    test('keeps RTL long CJK and long Latin geometry inside the stage', () {
      final cases = <({String name, String text, TextDirection direction})>[
        (
          name: 'rtl',
          text: 'مرحبا بالعالم هذه كلمات طويلة تتدفق من اليمين إلى اليسار',
          direction: TextDirection.rtl,
        ),
        (
          name: 'long CJK',
          text: List<String>.filled(10, '云海之间星光流转心声回响').join(),
          direction: TextDirection.ltr,
        ),
        (
          name: 'long Latin',
          text: List<String>.filled(5, 'extraordinarycomposition').join(),
          direction: TextDirection.ltr,
        ),
      ];

      for (final value in cases) {
        final layout = _layout(
          LyricLine(start: Duration.zero, text: value.text),
          width: 176,
          height: 210,
          textDirection: value.direction,
        );
        expect(layout.fragments, isNotEmpty, reason: value.name);
        _expectRectInside(
          layout.contentBounds,
          layout.stageBounds,
          '${value.name} content bounds',
        );
        _expectRectInside(
          layout.visualBounds,
          layout.stageBounds,
          '${value.name} visual bounds',
        );
        for (final fragment in layout.fragments) {
          _expectRectInside(
            fragment.bounds,
            layout.stageBounds,
            '${value.name} fragment bounds',
          );
          _expectRectInside(
            fragment.visualBounds,
            layout.stageBounds,
            '${value.name} fragment visual bounds',
          );
          _expectRectInside(
            fragment.hitRect,
            layout.stageBounds,
            '${value.name} hit rect',
          );
          expect(fragment.bounds.isEmpty, isFalse, reason: value.name);
          expect(fragment.visualBounds.isEmpty, isFalse, reason: value.name);
          expect(fragment.hitRect.isEmpty, isFalse, reason: value.name);
          expect(
            fragment.hitRect.left,
            lessThanOrEqualTo(fragment.visualBounds.left),
            reason: value.name,
          );
          expect(
            fragment.hitRect.top,
            lessThanOrEqualTo(fragment.visualBounds.top),
            reason: value.name,
          );
          expect(
            fragment.hitRect.right,
            greaterThanOrEqualTo(fragment.visualBounds.right),
            reason: value.name,
          );
          expect(
            fragment.hitRect.bottom,
            greaterThanOrEqualTo(fragment.visualBounds.bottom),
            reason: value.name,
          );
        }
      }
    });

    test('uses translation before romanization and otherwise romanization', () {
      final translated = _layout(
        const LyricLine(
          start: Duration.zero,
          text: 'primary',
          translation: 'translated',
          romanization: 'romanized',
        ),
      );
      final romanized = _layout(
        const LyricLine(
          start: Duration.zero,
          text: 'primary',
          romanization: 'romanized',
        ),
      );
      final blank = _layout(
        const LyricLine(start: Duration.zero, text: 'primary'),
      );

      expect(translated.auxiliaryText, 'translated');
      expect(romanized.auxiliaryText, 'romanized');
      expect(blank.auxiliaryText, isNull);
    });
  });

  group('Cadenza layout cache', () {
    test(
      'key covers document token viewport font display and configuration',
      () {
        final baseLine = _timedLine(
          text: 'ab',
          tokenTexts: const <String>['a', 'b'],
        );
        final baseDocument = LyricDocument(lines: <LyricLine>[baseLine]);
        final baseEngine = CadenzaLyricLayoutEngine.fromDocument(baseDocument);
        final tokenChanged = LyricLine(
          start: Duration.zero,
          end: baseLine.end,
          text: 'ab',
          tokens: const <LyricToken>[
            LyricToken(
              text: 'a',
              startOffset: Duration.zero,
              duration: Duration(milliseconds: 19),
            ),
            LyricToken(
              text: 'b',
              startOffset: Duration(milliseconds: 19),
              duration: Duration(milliseconds: 21),
            ),
          ],
        );
        final tokenEngine = CadenzaLyricLayoutEngine.fromDocument(
          LyricDocument(lines: <LyricLine>[tokenChanged]),
        );
        final offsetEngine = CadenzaLyricLayoutEngine.fromDocument(
          LyricDocument(lines: <LyricLine>[baseLine], offset: 1),
        );
        const baseStyle = TextStyle(
          fontFamily: 'Test Sans',
          fontFamilyFallback: <String>['Fallback One'],
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.1,
        );
        final baseOptions = _options(textStyle: baseStyle);
        String key(
          CadenzaLyricLayoutEngine engine,
          LyricLine line,
          CadenzaLyricLayoutOptions options,
        ) {
          return buildCadenzaLineLayoutCacheKey(
            documentSignature: engine.documentSignature,
            renderLineIndex: 0,
            line: line,
            options: options,
          );
        }

        final baseKey = key(baseEngine, baseLine, baseOptions);
        final changedKeys = <String>[
          key(offsetEngine, baseLine, baseOptions),
          key(tokenEngine, tokenChanged, baseOptions),
          key(baseEngine, baseLine, _options(width: 361, textStyle: baseStyle)),
          key(
            baseEngine,
            baseLine,
            _options(height: 421, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(textStyle: baseStyle.copyWith(fontFamily: 'Other Sans')),
          ),
          key(
            baseEngine,
            baseLine,
            _options(
              textStyle: baseStyle.copyWith(
                fontFamilyFallback: const <String>['Fallback Two'],
              ),
            ),
          ),
          key(
            baseEngine,
            baseLine,
            _options(textStyle: baseStyle.copyWith(fontSize: 31)),
          ),
          key(
            baseEngine,
            baseLine,
            _options(
              textStyle: baseStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          key(
            baseEngine,
            baseLine,
            _options(textStyle: baseStyle.copyWith(height: 1.2)),
          ),
          key(
            baseEngine,
            baseLine,
            _options(textScaleFactor: 1.2, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(textDirection: TextDirection.rtl, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(locale: const Locale('ar'), textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(fontScale: 1.2, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(widthRatio: 0.66, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(horizontalInset: 25, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(verticalInset: 21, textStyle: baseStyle),
          ),
          key(
            baseEngine,
            baseLine,
            _options(hitSlop: 11, textStyle: baseStyle),
          ),
        ];

        expect(changedKeys, everyElement(isNot(baseKey)));
        expect(changedKeys.toSet(), hasLength(changedKeys.length));
        expect(
          key(
            baseEngine,
            baseLine,
            _options(textStyle: baseStyle.copyWith(color: Colors.red)),
          ),
          baseKey,
          reason: 'paint-only color must not invalidate measured geometry',
        );
      },
    );

    test('reuses identity and evicts the oldest entry at its bound', () {
      final engine = CadenzaLyricLayoutEngine.fromDocument(_document);
      final cache = CadenzaLyricLayoutCache(maximumEntries: 2);
      final first = engine.layoutLine(
        renderLineIndex: 0,
        options: _options(),
        cache: cache,
      )!;
      final firstAgain = engine.layoutLine(
        renderLineIndex: 0,
        options: _options(),
        cache: cache,
      )!;
      expect(firstAgain, same(first));
      expect(cache.length, 1);

      engine.layoutLine(renderLineIndex: 1, options: _options(), cache: cache);
      expect(
        engine.layoutLine(
          renderLineIndex: 0,
          options: _options(),
          cache: cache,
        ),
        same(first),
        reason: 'cache hits do not change FIFO insertion order',
      );
      engine.layoutLine(renderLineIndex: 2, options: _options(), cache: cache);
      expect(cache.length, 2);
      expect(
        engine.layoutLine(
          renderLineIndex: 0,
          options: _options(),
          cache: cache,
        ),
        isNot(same(first)),
      );
    });
  });
}

CadenzaLineLayout _layout(
  LyricLine line, {
  double width = 360,
  double height = 420,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final engine = CadenzaLyricLayoutEngine.fromDocument(
    LyricDocument(lines: <LyricLine>[line]),
  );
  return engine.layoutLine(
    renderLineIndex: 0,
    options: _options(
      width: width,
      height: height,
      textDirection: textDirection,
    ),
  )!;
}

CadenzaLyricLayoutOptions _options({
  double width = 360,
  double height = 420,
  TextDirection textDirection = TextDirection.ltr,
  Locale? locale,
  double textScaleFactor = 1,
  double fontScale = cadenzaDefaultFontScale,
  double widthRatio = cadenzaDefaultWidthRatio,
  double horizontalInset = 24,
  double verticalInset = 20,
  double hitSlop = 10,
  TextStyle textStyle = const TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
  ),
}) {
  return CadenzaLyricLayoutOptions(
    stageSize: Size(width, height),
    textStyle: textStyle,
    textDirection: textDirection,
    locale: locale,
    textScaleFactor: textScaleFactor,
    fontScale: fontScale,
    widthRatio: widthRatio,
    horizontalInset: horizontalInset,
    verticalInset: verticalInset,
    hitSlop: hitSlop,
  );
}

LyricLine _timedLine({required String text, required List<String> tokenTexts}) {
  var offset = Duration.zero;
  final tokens = <LyricToken>[];
  for (final tokenText in tokenTexts) {
    final duration = Duration(milliseconds: tokenText.trim().isEmpty ? 2 : 20);
    tokens.add(
      LyricToken(text: tokenText, startOffset: offset, duration: duration),
    );
    offset += duration;
  }
  return LyricLine(
    start: Duration.zero,
    end: offset,
    text: text,
    tokens: tokens,
  );
}

void _expectRectInside(Rect rect, Rect stage, String reason) {
  expect(rect.left.isFinite, isTrue, reason: reason);
  expect(rect.top.isFinite, isTrue, reason: reason);
  expect(rect.right.isFinite, isTrue, reason: reason);
  expect(rect.bottom.isFinite, isTrue, reason: reason);
  expect(rect.left, greaterThanOrEqualTo(stage.left), reason: reason);
  expect(rect.top, greaterThanOrEqualTo(stage.top), reason: reason);
  expect(rect.right, lessThanOrEqualTo(stage.right), reason: reason);
  expect(rect.bottom, lessThanOrEqualTo(stage.bottom), reason: reason);
}

const _document = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      text: 'first line',
    ),
    LyricLine(
      start: Duration(seconds: 2),
      end: Duration(seconds: 3),
      text: 'second line',
    ),
    LyricLine(
      start: Duration(seconds: 3),
      end: Duration(seconds: 4),
      text: 'third line',
    ),
  ],
);
