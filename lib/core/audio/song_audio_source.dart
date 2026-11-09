import 'decrypt/audio_transform_parameters.dart';

/// The resolver's CDN source. Execution material is kept out of playback URLs
/// and media metadata; only the source owner may hand it to the decryptor.
final class SongAudioSource {
  const SongAudioSource({
    required this.url,
    required this.format,
    this.audioParams,
  });

  factory SongAudioSource.fromPayload(
    Map<String, dynamic> payload, {
    required String requestedFormat,
  }) {
    final url = '${payload['url'] ?? ''}'.trim();
    final rawParams = payload['audio_params'];
    if (url.isEmpty || (rawParams != null && rawParams is! String)) {
      throw const FormatException('Invalid audio source');
    }
    final audioParams = rawParams is String && rawParams.isNotEmpty
        ? rawParams
        : null;
    if (audioParams != null) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Invalid encrypted audio source');
      }
      AudioTransformParameters.parse(audioParams);
    } else if (payload['key'] != null && '${payload['key']}'.isNotEmpty) {
      throw const FormatException('Audio parameters require a newer server');
    }
    final format = '${payload['format'] ?? ''}'.trim().toLowerCase();
    final fallback = requestedFormat.trim().toLowerCase();
    return SongAudioSource(
      url: url,
      format: format.isNotEmpty
          ? format
          : (fallback.isEmpty ? 'mp3' : fallback),
      audioParams: audioParams,
    );
  }

  final String url;
  final String format;
  final String? audioParams;
}
