import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cadenza_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/cadenza_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/tilt_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/pendolo_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/pendolo_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/tilt_lyric_painter.dart';

final _position = NotifierProvider<_Position, Duration>(_Position.new);

class _Position extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 1);
  void update(int milliseconds) => state = Duration(milliseconds: milliseconds);
}

final _active = NotifierProvider<_Active, bool>(_Active.new);

class _Active extends Notifier<bool> {
  @override
  bool build() => true;
  void update(bool value) => state = value;
}

const _document = LyricDocument(
  lines: [
    LyricLine(
      start: Duration.zero,
      end: Duration(seconds: 10),
      text: 'keep singing',
      tokens: [
        LyricToken(
          text: 'keep singing',
          startOffset: Duration.zero,
          duration: Duration(seconds: 10),
        ),
      ],
    ),
  ],
);

void main() {
  for (final style in ['monet', 'tilt', 'cadenza', 'partita', 'pendolo']) {
    testWidgets(
      '$style interpolates locally and snaps pause seek hidden reduced motion and replacement',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            lyricPositionProvider.overrideWith((ref) => ref.watch(_position)),
            lyricPlaybackActiveProvider.overrideWith(
              (ref) => ref.watch(_active),
            ),
          ],
        );
        addTearDown(container.dispose);
        final seek = ValueNotifier(0);
        addTearDown(seek.dispose);
        var builds = 0;
        Widget app({
          bool ticker = true,
          bool reduced = false,
          LyricDocument document = _document,
        }) {
          void built() => builds++;
          final rail = switch (style) {
            'monet' => MonetLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: classicPlayerScenePaletteFallback,
              onSeek: null,
              seekListenable: seek,
              debugOnStructureBuild: built,
            ),
            'pendolo' => PendoloLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: classicPlayerScenePaletteFallback,
              onSeek: null,
              seekListenable: seek,
              debugOnStructureBuild: built,
            ),
            'tilt' => TiltLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: classicPlayerScenePaletteFallback,
              onSeek: null,
              seekListenable: seek,
              debugOnStructureBuild: built,
            ),
            'cadenza' => CadenzaLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: classicPlayerScenePaletteFallback,
              onSeek: null,
              seekListenable: seek,
              debugOnStructureBuild: built,
            ),
            _ => PartitaLyricRail(
              document: document,
              fontPreset: AppLyricFontPreset.medium,
              enableWordByWordLyric: true,
              palette: classicPlayerScenePaletteFallback,
              onSeek: null,
              seekListenable: seek,
              breathingEnabled: false,
              debugOnStructureBuild: built,
            ),
          };
          return UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: TickerMode(
                  enabled: ticker,
                  child: Scaffold(
                    body: SizedBox(width: 430, height: 620, child: rail),
                  ),
                ),
              ),
            ),
          );
        }

        CustomPainter painter() => tester
            .widget<CustomPaint>(find.byKey(ValueKey('$style-lyric-painter')))
            .painter!;
        Duration position() => switch (painter()) {
          MonetLyricPainter p => p.position.value,
          PendoloLyricPainter p => p.positionListenable.value,
          TiltLyricPainter p => p.positionListenable!.value,
          CadenzaLyricPainter p => p.position.value,
          PartitaLyricPainter p => p.position.value,
          _ => throw StateError('Unexpected painter'),
        };
        await tester.pumpWidget(app());
        await tester.pump();
        final initialBuilds = builds;
        container.read(_position.notifier).update(1033);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(position().inMilliseconds, inExclusiveRange(1000, 1033));
        expect(builds, initialBuilds);
        container.read(_active.notifier).update(false);
        await tester.pump();
        expect(position().inMilliseconds, 1033);
        container.read(_position.notifier).update(1066);
        await tester.pump();
        expect(position().inMilliseconds, 1066);
        container.read(_active.notifier).update(true);
        seek.value++;
        container.read(_position.notifier).update(1099);
        await tester.pump();
        expect(position().inMilliseconds, 1099);
        await tester.pumpWidget(app(ticker: false));
        container.read(_position.notifier).update(1132);
        await tester.pump();
        expect(position().inMilliseconds, 1132);
        await tester.pumpWidget(app(reduced: true));
        container.read(_position.notifier).update(1165);
        await tester.pump();
        expect(position().inMilliseconds, 1165);
        await tester.pumpWidget(app());
        container.read(_position.notifier).update(1198);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 8));
        await tester.pumpWidget(
          app(
            document: const LyricDocument(
              lines: [
                LyricLine(
                  start: Duration.zero,
                  end: Duration(seconds: 10),
                  text: 'replacement',
                ),
              ],
            ),
          ),
        );
        expect(position().inMilliseconds, 1198);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }
}
