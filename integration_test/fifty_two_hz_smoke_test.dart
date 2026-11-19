import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_palette.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/fifty_two_hz_lyric_rail.dart';
import 'package:integration_test/integration_test.dart';

final _clock = NotifierProvider<_Clock, Duration>(_Clock.new);

class _Clock extends Notifier<Duration> {
  @override
  Duration build() => const Duration(seconds: 2);

  void seek(Duration position) => state = position;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('52Hz paints on the device and only changes with playback time', (
    tester,
  ) async {
    final actualWindow = tester.view.physicalSize;
    if (actualWindow.width < actualWindow.height) {
      tester.view.physicalSize = Size(actualWindow.height, actualWindow.width);
      addTearDown(tester.view.resetPhysicalSize);
    }
    final reduceMotion = ValueNotifier(false);
    addTearDown(reduceMotion.dispose);
    final player = ProviderContainer(
      overrides: [
        lyricPositionProvider.overrideWith((ref) => ref.watch(_clock)),
        lyricPlaybackActiveProvider.overrideWithValue(false),
      ],
    );
    addTearDown(player.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: player,
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reduceMotion,
            builder: (context, reduced, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            child: RepaintBoundary(
              key: capture,
              child: const ColoredBox(
                color: Colors.black,
                child: FiftyTwoHzLyricRail(
                  document: LyricDocument(
                    lines: [LyricLine(start: Duration.zero, text: 'A      B')],
                  ),
                  fontPreset: AppLyricFontPreset.medium,
                  enableWordByWordLyric: true,
                  palette: classicPlayerScenePaletteFallback,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final ready = find.byKey(const ValueKey('52hz-ripples-ready'));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (ready.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(ready, findsOneWidget);
    expect(tester.getSize(ready).aspectRatio, greaterThan(1));

    Future<List<int>> pixels({bool centerOnly = false}) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final image = await boundary.toImage(pixelRatio: .5);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rgba = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        if (!centerOnly) return rgba;
        final left = image.width ~/ 2 - 8;
        final top = image.height ~/ 2 - 8;
        return [
          for (var y = top; y < top + 16; y++)
            ...rgba.sublist(
              (y * image.width + left) * 4,
              (y * image.width + left + 16) * 4,
            ),
        ];
      } finally {
        image.dispose();
      }
    }

    final initial = await pixels();
    await tester.pump(const Duration(milliseconds: 800));
    expect(await pixels(), orderedEquals(initial));
    player.read(_clock.notifier).seek(const Duration(milliseconds: 2250));
    await tester.pump();
    final afterSeek = await pixels();
    final animatedGap = await pixels(centerOnly: true);
    expect(afterSeek, isNot(orderedEquals(initial)));

    reduceMotion.value = true;
    await tester.pump();
    expect(ready, findsNothing);
    expect(await pixels(), isNot(orderedEquals(afterSeek)));
    expect(
      await pixels(centerOnly: true),
      orderedEquals(animatedGap),
      reason:
          'Turning ripples off must leave the pixels between glyphs untouched',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
