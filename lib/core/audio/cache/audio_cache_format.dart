/// Supported output containers, independent of the requested service format.
const audioCacheFormats = <String>{
  'mp3',
  'flac',
  'm4a',
  'aac',
  'ogg',
  'opus',
  'wav',
  'aiff',
  'alac',
};

/// Returns the output container expected for a service request, or null when
/// unsupported. The cache key must continue to use the requested format.
String? resolveAudioCacheFormat({
  required String platform,
  required String requestedFormat,
}) {
  final service = platform.trim().toLowerCase();
  final requested = requestedFormat.trim().toLowerCase();
  if (service == 'kuwo' && requested == 'mflac') return 'flac';
  if (service == 'soda' && (requested == 'aac' || requested == 'flac')) {
    return 'm4a';
  }
  return audioCacheFormats.contains(requested) ? requested : null;
}

/// Equal supported formats remain valid; only the explicit service mappings
/// above may publish or restore a different container.
bool audioCacheFormatsCompatible({
  required String platform,
  required String requestedFormat,
  required String resolvedFormat,
}) =>
    audioCacheFormats.contains(resolvedFormat) &&
    (requestedFormat == resolvedFormat ||
        resolveAudioCacheFormat(
              platform: platform,
              requestedFormat: requestedFormat,
            ) ==
            resolvedFormat);
