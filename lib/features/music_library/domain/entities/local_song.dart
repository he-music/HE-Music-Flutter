import 'dart:typed_data';

class LocalSong {
  const LocalSong({
    required this.id,
    required this.title,
    required this.filePath,
    required this.artist,
    required this.album,
    required this.duration,
    required this.mimeType,
    required this.size,
    this.genre = '',
    this.year,
    this.discNumber,
    this.trackNumber,
    this.folderPath,
    this.bitrate,
    this.sampleRate,
    this.hasArtwork = false,
    this.metadataEdited = false,
    this.status = 'active',
    this.artworkBytes,
    this.embeddedLyrics,
  });

  final String id;
  final String title;
  final String filePath;
  final String artist;
  final String album;
  final Duration duration;
  final String mimeType;
  final int size;
  final String genre;
  final int? year;
  final int? discNumber;
  final int? trackNumber;

  /// 文件夹路径，仅 Android/macOS 有值，iOS 为 null
  final String? folderPath;
  final int? bitrate;
  final int? sampleRate;

  /// 是否已提取封面到磁盘缓存
  final bool hasArtwork;

  /// 用户是否手动编辑过元数据
  final bool metadataEdited;

  /// 文件状态：'active' / 'missing'
  final String status;
  final Uint8List? artworkBytes;
  final String? embeddedLyrics;

  LocalSong copyWith({Uint8List? artworkBytes}) {
    return LocalSong(
      id: id,
      title: title,
      filePath: filePath,
      artist: artist,
      album: album,
      duration: duration,
      mimeType: mimeType,
      size: size,
      genre: genre,
      year: year,
      discNumber: discNumber,
      trackNumber: trackNumber,
      folderPath: folderPath,
      bitrate: bitrate,
      sampleRate: sampleRate,
      hasArtwork: hasArtwork,
      metadataEdited: metadataEdited,
      status: status,
      artworkBytes: artworkBytes ?? this.artworkBytes,
      embeddedLyrics: embeddedLyrics,
    );
  }

  String get formatLabel {
    final path = filePath.trim().toLowerCase();
    if (path.contains('.flac')) {
      return 'FLAC';
    }
    if (path.contains('.wav')) {
      return 'WAV';
    }
    if (path.contains('.ape')) {
      return 'APE';
    }
    if (path.contains('.aac')) {
      return 'AAC';
    }
    if (path.contains('.ogg')) {
      return 'OGG';
    }
    if (path.contains('.m4a')) {
      return 'M4A';
    }
    if (path.contains('.mp3')) {
      return 'MP3';
    }
    final normalizedMime = mimeType.trim().toLowerCase();
    if (normalizedMime.contains('flac')) {
      return 'FLAC';
    }
    if (normalizedMime.contains('wav')) {
      return 'WAV';
    }
    if (normalizedMime.contains('ape')) {
      return 'APE';
    }
    if (normalizedMime.contains('aac')) {
      return 'AAC';
    }
    if (normalizedMime.contains('ogg')) {
      return 'OGG';
    }
    if (normalizedMime.contains('m4a') || normalizedMime.contains('mp4')) {
      return 'M4A';
    }
    if (normalizedMime.contains('mpeg') || normalizedMime.contains('mp3')) {
      return 'MP3';
    }
    return '';
  }
}
