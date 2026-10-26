import 'player_play_mode.dart';

import '../../../../shared/models/he_music_models.dart';

class PlayerHistoryItem {
  const PlayerHistoryItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.url,
    required this.playedAt,
    this.duration,
    this.platform,
    this.albumId,
    this.artists = const <SongInfoArtistInfo>[],
    this.isRadioMode = false,
    this.currentRadioId,
    this.currentRadioPlatform,
    this.currentRadioPageIndex,
    this.previousPlayModeBeforeRadio,
    this.artworkPath,
    this.path,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String url;
  final int playedAt;

  /// 总时长，单位为秒；旧记录或未知时长为 null。
  final int? duration;

  final String? platform;
  final String? albumId;
  final List<SongInfoArtistInfo> artists;
  final bool isRadioMode;
  final String? currentRadioId;
  final String? currentRadioPlatform;
  final int? currentRadioPageIndex;
  final PlayerPlayMode? previousPlayModeBeforeRadio;
  final String? artworkPath;
  final String? path;

  /// 旧本地历史仅保存文件 URL；在线历史仍交由平台或下载记录解析。
  String? get playbackPath {
    final storedPath = path?.trim();
    if (storedPath != null && storedPath.isNotEmpty) return storedPath;
    if (platform?.trim() != 'local') return null;
    final localUrl = url.trim();
    final uri = Uri.tryParse(localUrl);
    if (uri == null) return null;
    if (uri.scheme == 'file' || (!uri.hasScheme && localUrl.startsWith('/'))) {
      return localUrl;
    }
    return null;
  }
}
