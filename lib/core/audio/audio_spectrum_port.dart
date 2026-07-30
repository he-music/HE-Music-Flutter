import 'audio_spectrum_frame.dart';

abstract interface class AudioSpectrumPort {
  Stream<AudioSpectrumFrame> get spectrumFrameStream;

  Future<void> startSpectrumCapture();

  Future<void> stopSpectrumCapture();
}
