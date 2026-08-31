import 'dart:typed_data';

import '../../../../shared/models/he_music_models.dart';

class PlayerTrack {
  const PlayerTrack({
    required this.id,
    required this.title,
    this.url = '',
    this.path,
    this.duration,
    this.links = const <LinkInfo>[],
    this.artist,
    this.album,
    this.albumId,
    this.artists = const <SongInfoArtistInfo>[],
    this.mvId,
    this.artworkUrl,
    this.artworkBytes,
    this.platform,
    this.format,
    this.bitrate,
    this.sampleRate,
  });

  final String id;
  final String title;
  final String url;
  final String? path;
  final Duration? duration;
  final List<LinkInfo> links;
  final String? artist;
  final String? album;
  final String? albumId;
  final List<SongInfoArtistInfo> artists;
  final String? mvId;
  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final String? platform;
  final String? format;
  final int? bitrate;
  final int? sampleRate;

  String? get audioQualityLabel {
    final parts = <String>[
      if ((format ?? '').trim().isNotEmpty) format!.trim(),
      if (bitrate != null && bitrate! > 0) '$bitrate kbps',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  PlayerTrack copyWith({
    String? id,
    String? title,
    String? url,
    String? path,
    Duration? duration,
    List<LinkInfo>? links,
    String? artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo>? artists,
    String? mvId,
    String? artworkUrl,
    Uint8List? artworkBytes,
    String? platform,
    String? format,
    int? bitrate,
    int? sampleRate,
  }) {
    return PlayerTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      links: links ?? this.links,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artists: artists ?? this.artists,
      mvId: mvId ?? this.mvId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      artworkBytes: artworkBytes ?? this.artworkBytes,
      platform: platform ?? this.platform,
      format: format ?? this.format,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
    );
  }
}
