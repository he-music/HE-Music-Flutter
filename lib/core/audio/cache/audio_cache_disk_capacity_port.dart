import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class AudioCacheDiskCapacityPort {
  /// Fresh available bytes on the volume containing this existing cache path.
  Future<int?> availableBytes(String cachePath);
}

final class MethodChannelAudioCacheDiskCapacityPort
    implements AudioCacheDiskCapacityPort {
  const MethodChannelAudioCacheDiskCapacityPort({
    this.channel = const MethodChannel('com.hemusic/audio_cache_capacity'),
  });

  final MethodChannel channel;

  @override
  Future<int?> availableBytes(String cachePath) async {
    final value = await channel.invokeMethod<Object?>('availableBytes', {
      'cachePath': cachePath,
    });
    return value is int && value >= 0 ? value : null;
  }
}

/// Bootstrap must supply Release evidence, never infer it from a query.
/// No platform is activated by this library; iOS is still unverified.
final class AudioCacheCapability {
  const AudioCacheCapability({
    this.androidReleaseVerified = false,
    this.macosReleaseVerified = false,
  });

  final bool androidReleaseVerified;
  final bool macosReleaseVerified;

  bool supports(TargetPlatform platform, {bool isWeb = kIsWeb}) =>
      !isWeb &&
      switch (platform) {
        TargetPlatform.android => androidReleaseVerified,
        TargetPlatform.macOS => macosReleaseVerified,
        _ => false,
      };
}
