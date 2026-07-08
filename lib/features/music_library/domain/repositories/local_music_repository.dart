import '../entities/local_song.dart';

abstract class LocalMusicRepository {
  Future<bool> requestPermission();

  /// 扫描本地歌曲并写入数据库（两阶段：先元数据，后后台封面提取）
  Future<List<LocalSong>> scanSongs();

  /// 监听歌曲列表（支持搜索、排序、分页）
  Stream<List<LocalSong>> watchSongs({
    String? searchQuery,
    String sortBy = 'title',
    bool ascending = true,
  });

  /// 监听指定艺术家的歌曲
  Stream<List<LocalSong>> watchSongsByArtist(String artistName);

  /// 监听指定专辑的歌曲
  Stream<List<LocalSong>> watchSongsByAlbum(String albumName);

  /// 监听按艺术家分组
  Stream<List<ArtistGroup>> watchArtists();

  /// 监听按专辑分组
  Stream<List<AlbumGroup>> watchAlbums();

  /// 监听按流派分组
  Stream<List<GenreGroup>> watchGenres();

  /// 记录播放次数
  Future<void> incrementPlayCount(String songId);

  /// 清除全部本地曲库数据
  Future<void> clearLibrary();

  /// 标记元数据已编辑
  Future<void> markMetadataEdited(String songId);

  /// 标记文件缺失
  Future<void> markFileMissing(String songId);
}

/// 艺术家分组
class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.songCount,
    required this.albumCount,
  });

  final String name;
  final int songCount;
  final int albumCount;
}

/// 专辑分组
class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.artist,
    required this.songCount,
    this.year,
    this.artworkPath,
  });

  final String name;
  final String artist;
  final int songCount;
  final int? year;

  /// 同专辑中有封面歌曲的文件路径，用于加载专辑封面
  final String? artworkPath;
}

/// 流派分组
class GenreGroup {
  const GenreGroup({required this.name, required this.songCount});

  final String name;
  final int songCount;
}
