import 'package:flutter/foundation.dart';

@immutable
class AudioSpectrumFrame {
  AudioSpectrumFrame(Iterable<double> bands)
    : bands = List<double>.unmodifiable(bands) {
    if (this.bands.length != bandCount) {
      throw ArgumentError.value(
        this.bands.length,
        'bands.length',
        '频谱帧必须包含 $bandCount 个频带。',
      );
    }
    for (final value in this.bands) {
      if (!value.isFinite || value < 0 || value > 1) {
        throw ArgumentError.value(value, 'bands', '频谱值必须是 0 到 1 之间的有限数。');
      }
    }
  }

  static const int bandCount = 64;

  static final AudioSpectrumFrame zero = AudioSpectrumFrame(
    List<double>.filled(bandCount, 0),
  );

  final List<double> bands;
}
