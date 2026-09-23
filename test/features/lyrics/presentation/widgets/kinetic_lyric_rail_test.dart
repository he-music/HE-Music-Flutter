import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/kinetic_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/kinetic_lyric_rail.dart';

class _Clock extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 1);
  void set(Duration next) => state = next;
}

class _Playing extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool next) => state = next;
}

final _clock = NotifierProvider<_Clock, Duration>(_Clock.new);
final _playing = NotifierProvider<_Playing, bool>(_Playing.new);
final _document = LyricDocument(
  lines: List.generate(
    100,
    (i) => LyricLine(
      start: Duration(seconds: i * 4),
      end: Duration(seconds: i * 4 + 4),
      text: 'WORD',
      tokens: const [
        LyricToken(
          text: 'WORD',
          startOffset: Duration.zero,
          duration: Duration(seconds: 4),
        ),
      ],
    ),
  ),
);

Widget _app({
  LyricDocument? document,
  VoidCallback? build,
  VoidCallback? layout,
  VoidCallback? paint,
  bool reduce = false,
  bool words = true,
  Size size = const Size(390, 600),
  double textScale = 1,
  Color? highlightColor,
  ValueChanged<Duration>? seek,
  Listenable? revision,
}) => ProviderScope(
  overrides: [
    lyricPositionProvider.overrideWith((ref) => ref.watch(_clock)),
    lyricPlaybackActiveProvider.overrideWith((ref) => ref.watch(_playing)),
  ],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduce,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KineticLyricRail(
            document: document ?? _document,
            fontPreset: AppLyricFontPreset.medium,
            enableWordByWordLyric: words,
            palette: classicPlayerScenePaletteFallback,
            highlightColor: highlightColor,
            onSeek: seek,
            seekListenable: revision,
            debugOnStructureBuild: build,
            debugOnTextLayout: layout,
            debugOnPaint: paint,
          ),
        ),
      ),
    ),
  ),
);
KineticLyricPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('kinetic-lyric-painter')),
            )
            .painter!
        as KineticLyricPainter;
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KineticLyricRail)));
void _time(WidgetTester tester, int ms) =>
    _container(tester).read(_clock.notifier).set(Duration(milliseconds: ms));

class _PaintCounter implements Canvas {
  int layers = 0;
  int paragraphs = 0;
  int filters = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #saveLayer) {
      layers++;
      final paint = invocation.positionalArguments[1] as Paint;
      if (paint.imageFilter != null || paint.colorFilter != null) filters++;
    }
    if (invocation.memberName == #drawParagraph) paragraphs++;
    return null;
  }
}

void main() {
  testWidgets(
    'side note halo fades before the viewport clip without moving the note',
    (tester) async {
      const size = Size(320, 500);
      await tester.pumpWidget(
        _app(
          size: size,
          words: false,
          document: const LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 4),
                text: 'A long lyric that fills the available paragraph width',
              ),
            ],
          ),
        ),
      );
      final painter = _painter(tester);
      final pose = painter.noteAt(painter.timeline, size)!;
      expect(pose.point.dx, lessThan(30));
      final withoutNote = KineticLyricPainter(
        rows: painter.rows,
        anchor: painter.anchor,
        position: painter.position,
        followPlayback: false,
        documentOffset: 0,
        wordHighlight: false,
        reducedMotion: false,
        color: painter.color,
        trailStart: painter.trailStart,
      );
      Future<ByteData> pixels(KineticLyricPainter p) async {
        final recorder = ui.PictureRecorder();
        p.paint(Canvas(recorder), size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        picture.dispose();
        return bytes;
      }

      await tester.runAsync(() async {
        final lit = await pixels(painter);
        final base = await pixels(withoutNote);
        final y = (size.height * .48 + painter.cameraShift + pose.point.dy + 10)
            .round();
        int alpha(ByteData bytes, int x) =>
            bytes.getUint8((y * size.width.toInt() + x) * 4 + 3);
        expect(alpha(lit, 0), alpha(base, 0));
        expect(
          alpha(lit, pose.point.dx.round()),
          greaterThan(alpha(base, pose.point.dx.round())),
        );
      });
    },
  );

  testWidgets(
    'note and effects follow the actual text color after a setting change',
    (tester) async {
      Color? previous;
      for (final color in [Colors.red, Colors.blue]) {
        await tester.pumpWidget(_app(highlightColor: color));
        final painter = _painter(tester);
        final textColor =
            painter.rows.first.glyphs.first.painter.text!.style!.color;
        expect(painter.color, textColor);
        if (previous != null) expect(painter.color, isNot(previous));
        previous = painter.color;
      }
    },
  );

  testWidgets(
    'lower rows are prepared before scrolling and keep their position at a boundary',
    (tester) async {
      await tester.pumpWidget(_app());
      const size = Size(390, 600);
      _time(tester, 3999);
      await tester.pump();
      final before = _painter(tester);
      final lower = before.rows.firstWhere((row) => row.entry.index == 2);
      final previousY =
          lower.y + before.cameraShiftAt(const Duration(milliseconds: 3999));
      final previousIds = before.rows.map((row) => row.entry.index).toSet();
      expect(before.lineFocusAt(1, const Duration(milliseconds: 3350)), 0);
      expect(
        before.lineFocusAt(1, const Duration(milliseconds: 3700)),
        inExclusiveRange(0, 1),
      );
      expect(
        before.lineFocusAt(1, const Duration(milliseconds: 3999)),
        closeTo(1, .001),
      );
      _time(tester, 4000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final after = _painter(tester);
      final retained = after.rows.firstWhere((row) => row.entry.index == 2);
      expect(identical(retained, lower), isTrue);
      expect(retained.y + after.cameraShift, closeTo(previousY, .01));
      for (final row in after.rows.where(
        (row) => !previousIds.contains(row.entry.index),
      )) {
        expect(
          row.y + row.glyphTop + size.height * .48 + after.cameraShift,
          greaterThan(size.height),
        );
      }
      expect(after.lineFocusAt(1, const Duration(seconds: 4)), 1);
    },
  );

  testWidgets(
    'line-only note glides with the scroll and remains visible across the boundary',
    (tester) async {
      await tester.pumpWidget(_app(words: false));
      const size = Size(390, 600);
      _time(tester, 3999);
      await tester.pump();
      final before = _painter(tester);
      final time = const Duration(milliseconds: 3999);
      final point =
          before.noteAt(time, size)!.point +
          Offset(0, before.cameraShiftAt(time));
      _time(tester, 4000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final after = _painter(tester);
      final arrived = after.noteAt(const Duration(seconds: 4), size)!;
      expect(
        (arrived.point + Offset(0, after.cameraShift) - point).distance,
        lessThan(.01),
      );
      expect(
        after.noteAt(const Duration(milliseconds: 4300), size)!.point,
        arrived.point,
      );
    },
  );

  testWidgets(
    'mixed timing retains the note while interludes fade and open-ended lines breathe',
    (tester) async {
      const size = Size(390, 600);
      await tester.pumpWidget(
        _app(
          document: const LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 4),
                text: 'AB',
                tokens: [
                  LyricToken(
                    text: 'AB',
                    startOffset: Duration.zero,
                    duration: Duration(seconds: 4),
                  ),
                ],
              ),
              LyricLine(
                start: Duration(seconds: 4),
                end: Duration(seconds: 6),
                text: 'Whole line',
              ),
              LyricLine(start: Duration(seconds: 12), text: 'Last line'),
            ],
          ),
        ),
      );
      for (final ms in [3999, 4000, 5000]) {
        _time(tester, ms);
        await tester.pump();
        expect(
          _painter(tester).noteAt(Duration(milliseconds: ms), size),
          isNotNull,
        );
      }
      _time(tester, 8000);
      await tester.pump();
      expect(_painter(tester).noteAt(const Duration(seconds: 8), size), isNull);
      _time(tester, 30000);
      await tester.pump();
      expect(
        _painter(tester).noteAt(const Duration(seconds: 30), size),
        isNotNull,
      );
    },
  );

  testWidgets(
    'camera arrives with the first note and never kicks after landing',
    (tester) async {
      await tester.pumpWidget(_app());
      const size = Size(390, 600);
      Offset screenNote(KineticLyricPainter p, int ms) {
        final time = Duration(milliseconds: ms);
        return p.noteAt(time, size)!.point +
            Offset(0, size.height * .48 + p.cameraShiftAt(time));
      }

      _time(tester, 3999);
      await tester.pump();
      final before = _painter(tester);
      expect(
        before.cameraShiftAt(const Duration(milliseconds: 3700)),
        lessThan(0),
      );
      final approaching = screenNote(before, 3999);
      final arriving = screenNote(before, 4000);
      expect((arriving - approaching).distance, lessThan(1));
      _time(tester, 4000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final after = _painter(tester);
      expect((screenNote(after, 4000) - arriving).distance, lessThan(.001));
      for (final ms in [4001, 4050, 4100, 4200, 4300]) {
        expect(after.cameraShiftAt(Duration(milliseconds: ms)), 0);
        expect(screenNote(after, ms), screenNote(after, 4000));
      }
    },
  );

  testWidgets(
    'wrapped-row camera finishes at the new row onset without following letter jitter',
    (tester) async {
      const text = 'ABCDEFGHIJKLMNOP';
      await tester.pumpWidget(
        _app(
          document: const LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 16),
                text: text,
                tokens: [
                  LyricToken(
                    text: text,
                    startOffset: Duration.zero,
                    duration: Duration(seconds: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final painter = _painter(tester);
      final firstWrapped = painter.rows.single.glyphs.firstWhere(
        (g) => g.rowY > 0,
      );
      final onset = firstWrapped.source.start!;
      final target = -firstWrapped.rowY;
      expect(
        painter.cameraShiftAt(onset - const Duration(milliseconds: 1)),
        closeTo(target, .01),
      );
      expect(painter.cameraShiftAt(onset), target);
      expect(
        painter.cameraShiftAt(onset + const Duration(milliseconds: 300)),
        target,
      );
    },
  );

  testWidgets(
    'visible neighbors share opacity layers and text needs no blur filters',
    (tester) async {
      await tester.pumpWidget(_app());
      _time(tester, 5500);
      await tester.pump();
      final counter = _PaintCounter();
      _painter(tester).paint(counter, const Size(390, 600));
      expect(counter.paragraphs, greaterThanOrEqualTo(12));
      expect(counter.layers, lessThanOrEqualTo(counter.paragraphs ~/ 4 + 2));
      expect(counter.filters, 0);
    },
  );

  testWidgets(
    'samples repaint without rebuilding or laying out; line change follows',
    (tester) async {
      var builds = 0;
      var layouts = 0;
      var paints = 0;
      await tester.pumpWidget(
        _app(
          build: () => builds++,
          layout: () => layouts++,
          paint: () => paints++,
        ),
      );
      final initial = (builds, layouts);
      final initialPaints = paints;
      for (var i = 1; i <= 20; i++) {
        _time(tester, 1000 + i * 20);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect((builds, layouts), initial);
      expect(paints, greaterThan(initialPaints));
      _time(tester, 3900);
      await tester.pump();
      final entering = _painter(
        tester,
      ).rows.firstWhere((row) => row.entry.index == 1);
      final beforeBoundaryLayouts = layouts;
      _time(tester, 4000);
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      expect(identical(_painter(tester).rows[1], entering), isTrue);
      expect(layouts - beforeBoundaryLayouts, 1);
      final boundary = (builds, layouts);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester).cameraShift, closeTo(0, .001));
      expect((builds, layouts), boundary);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('camera freezes on pause and resumes with playback time', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    _time(tester, 3700);
    await tester.pump();
    _container(tester).read(_playing.notifier).set(false);
    await tester.pump();
    final frozen = _painter(tester).cameraShift;
    expect(frozen, lessThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).cameraShift, frozen);
    _container(tester).read(_playing.notifier).set(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).cameraShift, frozen);
    _time(tester, 4000);
    await tester.pump();
    expect(_painter(tester).cameraShift, 0);
  });

  testWidgets('joining scripts retain paragraph shaping', (tester) async {
    await tester.pumpWidget(
      _app(
        document: const LyricDocument(
          lines: [
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 3),
              text: 'مرحبا',
              tokens: [
                LyricToken(
                  text: 'مرحبا',
                  startOffset: Duration.zero,
                  duration: Duration(seconds: 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    expect(_painter(tester).rows.single.glyphs, isEmpty);
    expect(_painter(tester).rows.single.fallback.text!.toPlainText(), 'مرحبا');
    expect(_painter(tester).animated(_painter(tester).rows.single), isFalse);
    expect(
      _painter(tester).noteAt(const Duration(seconds: 1), const Size(390, 600)),
      isNotNull,
    );
  });

  testWidgets(
    'adjacent lines fit in portrait and short landscape without overlap',
    (tester) async {
      for (final size in [const Size(390, 600), const Size(700, 230)]) {
        final document = LyricDocument(
          lines: List.generate(
            5,
            (i) => LyricLine(
              start: Duration(seconds: i * 4),
              end: Duration(seconds: i * 4 + 4),
              text: 'WORD',
              translation: size.height > 300 ? 'Translation' : '',
              tokens: const [
                LyricToken(
                  text: 'WORD',
                  startOffset: Duration.zero,
                  duration: Duration(seconds: 4),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(_app(size: size, document: document));
        _time(tester, 5000);
        await tester.pump();
        final painter = _painter(tester);
        expect(painter.rows.length, greaterThanOrEqualTo(3));
        final origin = size.height * .48 + painter.cameraShift;
        for (final row in painter.rows.where(
          (row) => (row.entry.index - painter.anchor).abs() <= 1,
        )) {
          for (final glyph in row.glyphs) {
            final y = origin + row.y + glyph.center.dy;
            expect(y - glyph.painter.height / 2, greaterThanOrEqualTo(0));
            expect(
              y + glyph.painter.height / 2,
              lessThanOrEqualTo(size.height),
            );
          }
        }
        for (var i = 1; i < painter.rows.length; i++) {
          final previous = painter.rows[i - 1];
          final next = painter.rows[i];
          final gap =
              next.y +
              next.glyphTop -
              (previous.y + previous.bounds(true).bottom);
          expect(gap, greaterThanOrEqualTo(28));
          expect(gap, lessThanOrEqualTo(52));
        }
      }
    },
  );

  testWidgets(
    'note lands on real onsets, breathes in place and fades during gaps',
    (tester) async {
      const document = LyricDocument(
        offset: 200,
        lines: [
          LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 4),
            text: 'AB',
            tokens: [
              LyricToken(
                text: 'A',
                startOffset: Duration.zero,
                duration: Duration(seconds: 2),
              ),
              LyricToken(
                text: 'B',
                startOffset: Duration(seconds: 2),
                duration: Duration(seconds: 2),
              ),
            ],
          ),
          LyricLine(
            start: Duration(seconds: 12),
            end: Duration(seconds: 14),
            text: 'C',
            tokens: [
              LyricToken(
                text: 'C',
                startOffset: Duration.zero,
                duration: Duration(seconds: 2),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(document: document));
      _time(tester, 1800);
      await tester.pump();
      final painter = _painter(tester);
      expect(painter.timeline, const Duration(seconds: 2));
      final row = painter.rows.first;
      final glyph = row.glyphs[1];
      final landing =
          glyph.center + Offset(0, row.y - glyph.painter.height * .7);
      expect(
        painter.noteAt(painter.timeline, const Size(390, 600))!.point,
        landing,
      );
      final hovering = painter.noteAt(
        const Duration(seconds: 3),
        const Size(390, 600),
      )!;
      final later = painter.noteAt(
        const Duration(milliseconds: 3250),
        const Size(390, 600),
      )!;
      expect(hovering.point, landing);
      expect(later.point, landing);
      expect(hovering.rotation, 0);
      expect(hovering.glow, greaterThan(1));
      expect(hovering.glow, isNot(later.glow));
      expect(
        painter.noteAt(const Duration(seconds: 3), const Size(390, 600))!.point,
        hovering.point,
      );
      expect(
        painter.noteAt(const Duration(seconds: 4), const Size(390, 600))!.point,
        landing,
      );
      final takeoff = painter.noteAt(
        const Duration(milliseconds: 1350),
        const Size(390, 600),
      )!;
      for (final ms in [1349, 1351]) {
        final neighbor = painter.noteAt(
          Duration(milliseconds: ms),
          const Size(390, 600),
        )!;
        expect((neighbor.point - takeoff.point).distance, lessThan(1));
      }
      expect(
        painter.noteAt(const Duration(seconds: 6), const Size(390, 600)),
        isNull,
      );
    },
  );

  testWidgets(
    'pause freezes painting; seeks clear trail and snap even within a line',
    (tester) async {
      final revision = ChangeNotifier();
      var paints = 0;
      await tester.pumpWidget(
        _app(
          revision: revision,
          paint: () => paints++,
          document: const LyricDocument(
            lines: [
              LyricLine(
                start: Duration.zero,
                end: Duration(seconds: 4),
                text: 'A',
                tokens: [
                  LyricToken(
                    text: 'A',
                    startOffset: Duration.zero,
                    duration: Duration(seconds: 4),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      _container(tester).read(_playing.notifier).set(false);
      await tester.pump();
      final stopped = paints;
      final position = _painter(tester).position.value;
      final pose = _painter(tester).noteAt(position, const Size(390, 600))!;
      expect(pose.glow, greaterThan(1));
      await tester.pump(const Duration(seconds: 2));
      expect(paints, stopped);
      expect(_painter(tester).position.value, position);
      final paused = _painter(
        tester,
      ).noteAt(_painter(tester).timeline, const Size(390, 600))!;
      expect(paused.point, pose.point);
      expect(paused.glow, pose.glow);
      revision.notifyListeners();
      _time(tester, 1050);
      await tester.pump();
      expect(
        _painter(tester).position.value,
        const Duration(milliseconds: 1050),
      );
      expect(_painter(tester).trailStart, const Duration(milliseconds: 1050));
      expect(_painter(tester).cameraShift, 0);
      _time(tester, 0);
      await tester.pump();
      expect(_painter(tester).trailStart, Duration.zero);
      await tester.pumpWidget(const SizedBox.shrink());
      revision.dispose();
    },
  );

  testWidgets(
    'ordinary LRC, disabled word mode and reduced motion have no invented hops',
    (tester) async {
      for (final mode in ['plain', 'disabled', 'reduce']) {
        await tester.pumpWidget(
          _app(
            document: mode == 'plain'
                ? const LyricDocument(
                    lines: [
                      LyricLine(
                        start: Duration.zero,
                        end: Duration(seconds: 3),
                        text: 'Whole line',
                      ),
                    ],
                  )
                : _document,
            words: mode != 'disabled',
            reduce: mode == 'reduce',
          ),
        );
        final painter = _painter(tester);
        final first = painter.noteAt(
          const Duration(seconds: 1),
          const Size(390, 600),
        )!;
        final later = painter.noteAt(
          const Duration(milliseconds: 1400),
          const Size(390, 600),
        )!;
        expect(first.point, later.point);
        expect(first.rotation, 0);
        expect(first.glow, mode == 'reduce' ? equals(1) : greaterThan(1));
        expect(painter.cameraShift, 0);
      }
    },
  );

  testWidgets(
    'manual browse seeks with offset then returns to current playback',
    (tester) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _app(
          document: LyricDocument(lines: _document.lines, offset: 200),
          seek: seeks.add,
        ),
      );
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(KineticLyricRail)),
          scrollDelta: const Offset(0, 70),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      expect(_painter(tester).anchor, 1);
      final origin = tester.getTopLeft(find.byType(KineticLyricRail));
      await tester.tapAt(origin + const Offset(195, 288));
      expect(seeks, [const Duration(milliseconds: 3800)]);
      _time(tester, 20000);
      await tester.pump(const Duration(seconds: 3));
      expect(_painter(tester).anchor, 5);
      expect(_painter(tester).rows.length, lessThanOrEqualTo(24));
    },
  );

  testWidgets(
    'replacement and unmount retire painters; long timed text stays within width',
    (tester) async {
      await tester.pumpWidget(_app());
      final old = _painter(tester).rows.first;
      final text = List.filled(30, 'Long lyric ').join();
      for (final size in [const Size(320, 500), const Size(700, 230)]) {
        await tester.pumpWidget(
          _app(
            size: size,
            textScale: 1.4,
            document: LyricDocument(
              lines: [
                LyricLine(
                  start: Duration.zero,
                  end: const Duration(seconds: 20),
                  text: text,
                  tokens: [
                    LyricToken(
                      text: text,
                      startOffset: Duration.zero,
                      duration: const Duration(seconds: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        for (final glyph in _painter(tester).rows.single.glyphs) {
          expect(
            glyph.center.dx - glyph.painter.width / 2,
            greaterThanOrEqualTo(20),
          );
          expect(
            glyph.center.dx + glyph.painter.width / 2,
            lessThanOrEqualTo(size.width - 20),
          );
        }
        _time(tester, 15000);
        await tester.pump();
        expect(_painter(tester).focusY, greaterThan(0));
        expect(tester.takeException(), isNull);
      }
      expect(old.fallback.debugDisposed, isTrue);
      final last = _painter(tester).rows.single;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(last.fallback.debugDisposed, isTrue);
      expect(last.glyphs.every((g) => g.painter.debugDisposed), isTrue);
    },
  );
}
