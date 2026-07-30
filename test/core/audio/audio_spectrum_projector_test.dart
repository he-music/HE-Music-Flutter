import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_projector.dart';

void main() {
  group('AudioSpectrumFrame', () {
    test('复制并冻结 64 个规范化频带', () {
      final source = List<double>.filled(AudioSpectrumFrame.bandCount, 0.25);
      final frame = AudioSpectrumFrame(source);

      source[0] = 1;

      expect(frame.bands, hasLength(AudioSpectrumFrame.bandCount));
      expect(frame.bands.first, 0.25);
      expect(() => frame.bands[0] = 0.5, throwsUnsupportedError);
    });

    test('拒绝数量错误或不规范的频带', () {
      expect(() => AudioSpectrumFrame(const <double>[]), throwsArgumentError);
      expect(
        () => AudioSpectrumFrame(<double>[
          ...List<double>.filled(AudioSpectrumFrame.bandCount - 1, 0),
          double.nan,
        ]),
        throwsArgumentError,
      );
      expect(
        () => AudioSpectrumFrame(<double>[
          ...List<double>.filled(AudioSpectrumFrame.bandCount - 1, 0),
          1.01,
        ]),
        throwsArgumentError,
      );
    });
  });

  group('AudioSpectrumProjector', () {
    const projector = AudioSpectrumProjector();

    test('在有效 FFT 区间构造 64 个连续、不重叠且由窄到宽的频带', () {
      final ranges = buildAudioSpectrumBinRanges(513);

      expect(ranges, hasLength(AudioSpectrumFrame.bandCount));
      expect(ranges.first.start, 1);
      expect(ranges.last.end, 385);
      for (var index = 0; index < ranges.length; index++) {
        expect(ranges[index].end, greaterThan(ranges[index].start));
        if (index > 0) {
          expect(ranges[index].start, ranges[index - 1].end);
        }
      }
      expect(
        ranges.last.end - ranges.last.start,
        greaterThan(ranges.first.end - ranges.first.start),
      );
    });

    test('输入 bin 不足时返回零帧', () {
      final frame = projector.project(
        binCount: AudioSpectrumFrame.bandCount,
        magnitudeAt: (_) => 100,
      );

      expect(frame.bands, everyElement(0));
    });

    test('将幅值转换并限制到 0 到 1', () {
      final frame = projector.project(
        binCount: 513,
        magnitudeAt: (bin) => switch (bin % 4) {
          0 => double.nan,
          1 => 0,
          2 => 10,
          _ => 1000,
        },
      );

      expect(frame.bands, hasLength(AudioSpectrumFrame.bandCount));
      expect(frame.bands, everyElement(inInclusiveRange(0.0, 1.0)));
      expect(frame.bands, contains(isNonZero));
    });

    test('低频和高频输入落入不同且有序的频带', () {
      final ranges = buildAudioSpectrumBinRanges(513);
      final lowBin = ranges[4].start;
      final highBin = ranges[52].start;
      final lowFrame = projector.project(
        binCount: 513,
        magnitudeAt: (bin) => bin == lowBin ? 120 : 0,
      );
      final highFrame = projector.project(
        binCount: 513,
        magnitudeAt: (bin) => bin == highBin ? 120 : 0,
      );

      final lowPeak = _peakIndex(lowFrame.bands);
      final highPeak = _peakIndex(highFrame.bands);
      expect(lowPeak, 4);
      expect(highPeak, 52);
      expect(highPeak, greaterThan(lowPeak));
      expect(lowFrame.bands, isNot(equals(lowFrame.bands.reversed.toList())));
    });

    test('真实音乐式高频滚降在最后四分之一仍保留响应', () {
      final frame = projector.project(
        binCount: 513,
        magnitudeAt: (bin) => 60 / math.sqrt(bin),
      );

      final highBands = frame.bands.sublist(48);
      expect(highBands, everyElement(greaterThan(0.1)));
      expect(highBands.toSet(), hasLength(greaterThan(1)));
    });

    test('高频补偿不会把全零输入变成假频谱', () {
      final frame = projector.project(binCount: 513, magnitudeAt: (_) => 0);

      expect(frame.bands, everyElement(0));
    });
  });
}

int _peakIndex(List<double> values) {
  var peakIndex = 0;
  for (var index = 1; index < values.length; index++) {
    if (values[index] > values[peakIndex]) peakIndex = index;
  }
  return peakIndex;
}
