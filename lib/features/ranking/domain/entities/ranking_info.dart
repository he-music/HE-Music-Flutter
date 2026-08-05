import '../../../../shared/models/he_music_models.dart';
import 'ranking_preview_song.dart';

class RankingInfo {
  const RankingInfo({
    required this.id,
    required this.platform,
    required this.name,
    required this.coverUrl,
    required this.previewSongs,
  });

  final String id;
  final String platform;
  final String name;
  final String coverUrl;
  final List<RankingPreviewSong> previewSongs;

  factory RankingInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
    String? fallbackId,
  }) {
    final id = _readString(raw, const <String>['id']);
    final platform = _readString(raw, const <String>['platform']);
    final name = _readString(raw, const <String>['name', 'title']);
    final coverUrl = _readString(raw, const <String>[
      'cover',
      'pic',
      'imgurl',
      'image',
    ]);
    final songsRaw = raw['songs'];
    final songs = songsRaw is List ? songsRaw : const <dynamic>[];
    final previewSongs = songs
        .whereType<Map>()
        .take(3)
        .map((item) {
          final song = item.map((key, value) => MapEntry('$key', value));
          final songName = _readString(song, const <String>['name', 'title']);
          final artist = SongInfo.fromMap(
            song,
            fallbackPlatform: fallbackPlatform,
          ).artist;
          return RankingPreviewSong(
            name: songName.isEmpty ? '-' : songName,
            artist: artist.isEmpty ? '-' : artist,
          );
        })
        .toList(growable: false);
    return RankingInfo(
      id: id.isEmpty ? (fallbackId ?? '-') : id,
      platform: platform.isEmpty ? fallbackPlatform : platform,
      name: name.isEmpty ? '-' : name,
      coverUrl: coverUrl,
      previewSongs: previewSongs,
    );
  }

  static String _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}
