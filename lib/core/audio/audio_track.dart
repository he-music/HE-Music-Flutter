import '../../shared/models/he_music_models.dart';

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.url,
    this.path,
    this.duration,
    this.links = const <LinkInfo>[],
    this.artist,
    this.album,
    this.artworkUrl,
    this.platform,
  });

  final String id;
  final String title;
  final String url;
  final String? path;
  final Duration? duration;
  final List<LinkInfo> links;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final String? platform;
}
