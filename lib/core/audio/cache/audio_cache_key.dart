import 'dart:convert';

import 'package:crypto/crypto.dart';

/// An immutable media representation, independent of resolver and account.
final class AudioCacheKey {
  const AudioCacheKey._({
    required this.schema,
    required this.platform,
    required this.trackId,
    required this.quality,
    required this.requestedFormat,
  });

  static const currentSchema = 1;

  static AudioCacheKey? tryCreate({
    int schema = currentSchema,
    required String? platform,
    required String? trackId,
    required int? quality,
    required String? requestedFormat,
  }) {
    final normalizedPlatform = platform?.trim().toLowerCase() ?? '';
    final normalizedTrack = trackId?.trim() ?? '';
    final normalizedFormat = requestedFormat?.trim().toLowerCase() ?? '';
    if (schema <= 0 ||
        normalizedPlatform.isEmpty ||
        normalizedTrack.isEmpty ||
        quality == null ||
        quality <= 0 ||
        normalizedFormat.isEmpty) {
      return null;
    }
    return AudioCacheKey._(
      schema: schema,
      platform: normalizedPlatform,
      trackId: normalizedTrack,
      quality: quality,
      requestedFormat: normalizedFormat,
    );
  }

  final int schema;
  final String platform;
  final String trackId;
  final int quality;
  final String requestedFormat;

  // JSON framing prevents delimiter-containing IDs from aliasing another key.
  String get canonicalIdentity => jsonEncode([
    'audio-cache:v$schema',
    platform,
    trackId,
    quality,
    requestedFormat,
  ]);
  String get digest =>
      sha256.convert(utf8.encode(canonicalIdentity)).toString();
  (String, String) get trackIdentity => (platform, trackId);

  Map<String, Object> toJson() => {
    'platform': platform,
    'track_id': trackId,
    'quality': quality,
    'requested_format': requestedFormat,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioCacheKey && canonicalIdentity == other.canonicalIdentity;
  @override
  int get hashCode => canonicalIdentity.hashCode;
}
