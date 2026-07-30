import 'dart:math' as math;

import 'audio_spectrum_frame.dart';

typedef AudioSpectrumMagnitudeAt = double Function(int bin);

class AudioSpectrumBinRange {
  const AudioSpectrumBinRange({required this.start, required this.end});

  final int start;
  final int end;
}

class AudioSpectrumProjector {
  const AudioSpectrumProjector({
    this.minimumDecibels = 12,
    this.maximumDecibels = 42,
    this.maximumBinRatio = 0.75,
    this.highFrequencyBoostDecibels = 12,
  }) : assert(maximumDecibels > minimumDecibels),
       assert(maximumBinRatio > 0 && maximumBinRatio <= 1),
       assert(highFrequencyBoostDecibels >= 0);

  final double minimumDecibels;
  final double maximumDecibels;
  final double maximumBinRatio;
  final double highFrequencyBoostDecibels;

  AudioSpectrumFrame project({
    required int binCount,
    required AudioSpectrumMagnitudeAt magnitudeAt,
  }) {
    final ranges = buildAudioSpectrumBinRanges(
      binCount,
      maximumBinRatio: maximumBinRatio,
    );
    if (ranges.isEmpty) return AudioSpectrumFrame.zero;

    final bands = List<double>.generate(ranges.length, (index) {
      final range = ranges[index];
      var squareSum = 0.0;
      for (var bin = range.start; bin < range.end; bin++) {
        final magnitude = magnitudeAt(bin);
        if (!magnitude.isFinite || magnitude <= 0) continue;
        squareSum += magnitude * magnitude;
      }
      if (squareSum == 0) return 0;
      final rootMeanSquare = math.sqrt(squareSum / (range.end - range.start));
      final decibels = 20 * math.log(rootMeanSquare) / math.ln10;
      // 对数频带越靠后频率越高，补偿音乐信号自然的高频能量滚降。
      final compensatedDecibels =
          decibels + highFrequencyBoostDecibels * index / (ranges.length - 1);
      return ((compensatedDecibels - minimumDecibels) /
              (maximumDecibels - minimumDecibels))
          .clamp(0.0, 1.0);
    }, growable: false);
    return AudioSpectrumFrame(bands);
  }
}

List<AudioSpectrumBinRange> buildAudioSpectrumBinRanges(
  int binCount, {
  double maximumBinRatio = 0.75,
}) {
  assert(maximumBinRatio > 0 && maximumBinRatio <= 1);
  const bandCount = AudioSpectrumFrame.bandCount;
  final availableBins = binCount - 1; // 忽略不代表可听频率变化的 DC bin。
  if (availableBins < bandCount) {
    return const <AudioSpectrumBinRange>[];
  }
  // 顶部 FFT bins 通常位于 16kHz 以上，真实音乐能量很少；收束后避免末段长期空白。
  final usableBins = math.max(
    bandCount,
    (availableBins * maximumBinRatio).floor(),
  );

  final boundaries = List<int>.filled(bandCount + 1, 0);
  boundaries[bandCount] = usableBins;
  for (var index = 1; index < bandCount; index++) {
    final exponential =
        math.pow(usableBins + 1, index / bandCount).toDouble() - 1;
    final minimum = boundaries[index - 1] + 1;
    final maximum = usableBins - (bandCount - index);
    boundaries[index] = exponential.round().clamp(minimum, maximum);
  }

  return List<AudioSpectrumBinRange>.generate(bandCount, (index) {
    return AudioSpectrumBinRange(
      start: boundaries[index] + 1,
      end: boundaries[index + 1] + 1,
    );
  }, growable: false);
}
