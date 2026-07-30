import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/realtime_spectrum_controller.dart';
import 'package:he_music_flutter/features/player/presentation/styles/radial_spectrum_player_stage.dart';

void main() {
  test('64 根柱从六点钟开始顺时针排列且只向外生长', () {
    final bands = List<double>.generate(
      AudioSpectrumFrame.bandCount,
      (index) => (index + 1) / AudioSpectrumFrame.bandCount,
    );
    final bars = resolveRadialSpectrumBarsForTest(
      size: const Size.square(320),
      bands: bands,
    );
    const center = Offset(160, 160);

    expect(bars, hasLength(AudioSpectrumFrame.bandCount));
    expect(bars.first.start.dx, closeTo(center.dx, 0.001));
    expect(bars.first.start.dy, greaterThan(center.dy));
    expect(bars.first.end.dy, greaterThan(bars.first.start.dy));
    expect(bars[16].start.dx, lessThan(center.dx));
    expect(bars[16].start.dy, closeTo(center.dy, 0.001));
    for (final bar in bars) {
      expect(
        (bar.end - center).distance,
        greaterThanOrEqualTo((bar.start - center).distance),
      );
    }
  });

  test('相邻两侧消费各自频带，不做左右镜像', () {
    final bands = List<double>.filled(AudioSpectrumFrame.bandCount, 0)
      ..[1] = 0.2
      ..[63] = 0.85;
    final bars = resolveRadialSpectrumBarsForTest(
      size: const Size.square(320),
      bands: bands,
    );

    expect(
      (bars[1].end - bars[1].start).distance,
      lessThan((bars[63].end - bars[63].start).distance),
    );
  });

  test('封面颜色被限制到可读亮度和饱和度', () {
    final palette = resolveRadialSpectrumPaletteForTest(const <Color>[
      Color(0xFF030303),
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
    ]);

    expect(palette, hasLength(3));
    for (final color in palette) {
      final hsl = HSLColor.fromColor(color);
      expect(hsl.saturation, inInclusiveRange(0.48, 0.78));
      expect(hsl.lightness, inInclusiveRange(0.56, 0.72));
    }
  });

  testWidgets('舞台使用 64% 静止圆形封面并把频带交给 painter', (tester) async {
    final spectrum = _TestRealtimeSpectrumController();
    final container = ProviderContainer(
      overrides: [
        realtimeSpectrumControllerProvider.overrideWith(() => spectrum),
      ],
    );
    addTearDown(container.dispose);
    final bands = List<double>.generate(
      AudioSpectrumFrame.bandCount,
      (index) => math.sin(index / 8).abs(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 320,
                child: RadialSpectrumPlayerStage(
                  track: PlayerTrack(
                    id: 'track-a',
                    title: 'Track A',
                    artist: 'Artist',
                    platform: 'local',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    spectrum.setBands(bands);
    await tester.pump();

    final cover = tester.getSize(
      find.byKey(const ValueKey<String>('radial-spectrum-cover')),
    );
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('radial-spectrum-painter')),
    );
    final painter = customPaint.painter! as RadialSpectrumPainter;
    expect(cover.width, closeTo(320 * 0.64, 0.001));
    expect(cover.height, cover.width);
    expect(painter.bands, bands);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('同一歌曲的封面晚到时重新提取频谱色板', (tester) async {
    final artworkBytes = await tester.runAsync(
      () => File('assets/icons/logo.png').readAsBytes(),
    );
    final spectrum = _TestRealtimeSpectrumController();
    final container = ProviderContainer(
      overrides: [
        realtimeSpectrumControllerProvider.overrideWith(() => spectrum),
      ],
    );
    final track = ValueNotifier<PlayerTrack>(
      const PlayerTrack(
        id: 'track-a',
        title: 'Track A',
        artist: 'Artist',
        platform: 'local',
      ),
    );
    addTearDown(container.dispose);
    addTearDown(track.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 320,
                child: ValueListenableBuilder<PlayerTrack>(
                  valueListenable: track,
                  builder: (context, value, child) {
                    return RadialSpectrumPlayerStage(track: value);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(_radialPainter(tester).palette, radialSpectrumFallbackPalette);

    track.value = track.value.copyWith(artworkBytes: artworkBytes);
    await tester.pump();
    for (var attempt = 0; attempt < 80; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (!listEquals(
        _radialPainter(tester).palette,
        radialSpectrumFallbackPalette,
      )) {
        break;
      }
    }

    expect(
      _radialPainter(tester).palette,
      isNot(equals(radialSpectrumFallbackPalette)),
    );
  });
}

RadialSpectrumPainter _radialPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey<String>('radial-spectrum-painter')),
  );
  return customPaint.painter! as RadialSpectrumPainter;
}

class _TestRealtimeSpectrumController extends RealtimeSpectrumController {
  @override
  RealtimeSpectrumState build() => RealtimeSpectrumState.initial();

  void setBands(List<double> bands) {
    state = RealtimeSpectrumState(
      status: RealtimeSpectrumStatus.running,
      bands: List<double>.unmodifiable(bands),
    );
  }
}
