import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android activity PiP. Unsupported platforms never expose an entry point.
class VideoPictureInPictureController extends ChangeNotifier {
  VideoPictureInPictureController({
    MethodChannel channel = const MethodChannel('com.hemusic/video_pip'),
    TargetPlatform? platform,
  }) : _channel = channel,
       _platform = platform ?? defaultTargetPlatform;

  final MethodChannel _channel;
  final TargetPlatform _platform;
  bool available = false;
  bool active = false;
  bool entering = false;
  bool _disposed = false;
  VoidCallback? onTogglePlayback;
  VoidCallback? onStopped;

  Future<void> initialize() async {
    if (kIsWeb || _platform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (_disposed) return;
      switch (call.method) {
        case 'modeChanged':
          active = call.arguments == true;
          entering = false;
          notifyListeners();
        case 'togglePlayback':
          onTogglePlayback?.call();
        case 'stopped':
          onStopped?.call();
      }
    });
    try {
      final supported =
          await _channel.invokeMethod<bool>('isSupported') ?? false;
      if (_disposed) return;
      available = supported;
      notifyListeners();
    } on PlatformException {
      // PiP can be unavailable on this device or OS build.
    } on MissingPluginException {
      // Desktop, tests, and older platform shells have no handler.
    }
  }

  Future<bool> enter({
    required double aspectRatio,
    required bool playing,
  }) async {
    if (!available || entering || active || _disposed) return false;
    entering = true;
    notifyListeners();
    try {
      final entered =
          await _channel.invokeMethod<bool>('enter', {
            'aspectRatio': aspectRatio,
            'playing': playing,
          }) ??
          false;
      if (!_disposed) {
        active = entered;
        return entered;
      }
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } finally {
      entering = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> updatePlayback({
    required bool playing,
    required double aspectRatio,
  }) async {
    if (!active || _disposed) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'playing': playing,
        'aspectRatio': aspectRatio,
      });
    } on PlatformException {
      // A disappearing PiP window may race with a final playback event.
    } on MissingPluginException {
      // No native PiP shell.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (!kIsWeb && _platform == TargetPlatform.android) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }
}
