enum DownloadTaskStatus {
  queued,
  preparing,
  downloading,
  tagging,
  completed,
  paused,
  failed,
}

enum DownloadTagWriteStatus { pending, success, failed }

enum DownloadLyricFormat { none, plain, timed }

class DownloadTaskQuality {
  DownloadTaskQuality({
    required this.label,
    required this.bitrate,
    required this.fileExtension,
  }) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (bitrate < 0) {
      throw ArgumentError.value(bitrate, 'bitrate', 'must be >= 0');
    }
    if (fileExtension.trim().isEmpty) {
      throw ArgumentError.value(
        fileExtension,
        'fileExtension',
        'must not be empty',
      );
    }
  }

  final String label;
  final double bitrate;
  final String fileExtension;

  DownloadTaskQuality copyWith({
    String? label,
    double? bitrate,
    String? fileExtension,
  }) {
    return DownloadTaskQuality(
      label: label ?? this.label,
      bitrate: bitrate ?? this.bitrate,
      fileExtension: fileExtension ?? this.fileExtension,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': label,
      'bitrate': bitrate,
      'file_extension': fileExtension,
    };
  }

  factory DownloadTaskQuality.fromJson(Map<String, dynamic> json) {
    return DownloadTaskQuality(
      label: '${json['label'] ?? ''}',
      bitrate: _toDouble(json['bitrate']),
      fileExtension: '${json['file_extension'] ?? ''}',
    );
  }
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.status,
    required this.progress,
    required this.quality,
    required this.tagWriteStatus,
    required this.lyricFormat,
    required this.createdAt,
    this.downloadedBytes,
    this.totalBytes,
    this.songId,
    this.platform,
    this.artist,
    this.album,
    this.artworkUrl,
    this.startedAt,
    this.finishedAt,
    this.metadataPath,
    this.filePath,
    this.resolvedFileExtension,
    this.lyricPath,
    this.errorMessage,
    this.attempts = 0,
  });

  final String id;
  final String title;
  final String url;
  final String? songId;
  final String? platform;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final DownloadTaskStatus status;
  final double progress;
  final DownloadTaskQuality quality;
  final DownloadTagWriteStatus tagWriteStatus;
  final DownloadLyricFormat lyricFormat;
  final DateTime createdAt;
  final int? downloadedBytes;
  final int? totalBytes;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? metadataPath;
  final String? filePath;
  final String? resolvedFileExtension;
  final String? lyricPath;
  final String? errorMessage;
  final int attempts;

  String get effectiveFileExtension {
    final resolved = (resolvedFileExtension ?? '').trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return quality.fileExtension;
  }

  DownloadTask copyWith({
    String? url,
    DownloadTaskStatus? status,
    double? progress,
    String? songId,
    String? platform,
    String? artist,
    String? album,
    String? artworkUrl,
    DownloadTaskQuality? quality,
    DownloadTagWriteStatus? tagWriteStatus,
    DownloadLyricFormat? lyricFormat,
    int? downloadedBytes,
    int? totalBytes,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? metadataPath,
    String? filePath,
    String? resolvedFileExtension,
    String? lyricPath,
    String? errorMessage,
    int? attempts,
    bool clearStartedAt = false,
    bool clearFinishedAt = false,
    bool clearMetadataPath = false,
    bool clearFilePath = false,
    bool clearLyricPath = false,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url ?? this.url,
      songId: songId ?? this.songId,
      platform: platform ?? this.platform,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      quality: quality ?? this.quality,
      tagWriteStatus: tagWriteStatus ?? this.tagWriteStatus,
      lyricFormat: lyricFormat ?? this.lyricFormat,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      metadataPath: clearMetadataPath
          ? null
          : metadataPath ?? this.metadataPath,
      filePath: clearFilePath ? null : filePath ?? this.filePath,
      resolvedFileExtension:
          resolvedFileExtension ?? this.resolvedFileExtension,
      lyricPath: clearLyricPath ? null : lyricPath ?? this.lyricPath,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'url': url,
      'song_id': songId,
      'platform': platform,
      'artist': artist,
      'album': album,
      'artwork_url': artworkUrl,
      'status': status.name,
      'progress': progress,
      'quality': quality.toJson(),
      'tag_write_status': tagWriteStatus.name,
      'lyric_format': lyricFormat.name,
      'downloaded_bytes': downloadedBytes,
      'total_bytes': totalBytes,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'metadata_path': metadataPath,
      'file_path': filePath,
      'resolved_file_extension': resolvedFileExtension,
      'lyric_path': lyricPath,
      'error_message': errorMessage,
      'attempts': attempts,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      url: '${json['url'] ?? ''}',
      songId: _nullableString(json['song_id']),
      platform: _nullableString(json['platform']),
      artist: _nullableString(json['artist']),
      album: _nullableString(json['album']),
      artworkUrl: _nullableString(json['artwork_url']),
      status: DownloadTaskStatus.values.byName('${json['status'] ?? 'queued'}'),
      progress: _toDouble(json['progress']),
      quality: DownloadTaskQuality.fromJson(
        (json['quality'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      tagWriteStatus: DownloadTagWriteStatus.values.byName(
        '${json['tag_write_status'] ?? 'pending'}',
      ),
      lyricFormat: DownloadLyricFormat.values.byName(
        '${json['lyric_format'] ?? 'none'}',
      ),
      downloadedBytes: _nullableInt(json['downloaded_bytes']),
      totalBytes: _nullableInt(json['total_bytes']),
      createdAt: DateTime.parse('${json['created_at']}'),
      startedAt: _nullableDateTime(json['started_at']),
      finishedAt: _nullableDateTime(json['finished_at']),
      metadataPath: _nullableString(json['metadata_path']),
      filePath: _nullableString(json['file_path']),
      resolvedFileExtension:
          _nullableString(json['resolved_file_extension']) ??
          _nullableString(
            (json['quality'] as Map?)
                ?.cast<String, dynamic>()['file_extension'],
          ),
      lyricPath: _nullableString(json['lyric_path']),
      errorMessage: _nullableString(json['error_message']),
      attempts: _toInt(json['attempts']),
    );
  }

  static DownloadTask queued({
    required String id,
    required String title,
    required String url,
    String? songId,
    String? platform,
    String? artist,
    String? album,
    String? artworkUrl,
    DownloadTaskQuality? quality,
    String qualityLabel = 'standard',
    double qualityBitrate = 320.0,
    String fileExtension = 'mp3',
    DownloadLyricFormat lyricFormat = DownloadLyricFormat.none,
    DateTime? createdAt,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      songId: songId,
      platform: platform,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
      status: DownloadTaskStatus.queued,
      progress: 0,
      quality:
          quality ??
          DownloadTaskQuality(
            label: qualityLabel,
            bitrate: qualityBitrate,
            fileExtension: fileExtension,
          ),
      resolvedFileExtension: fileExtension,
      tagWriteStatus: DownloadTagWriteStatus.pending,
      lyricFormat: lyricFormat,
      downloadedBytes: null,
      totalBytes: null,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}

String? _nullableString(Object? value) {
  final normalized = '$value'.trim();
  if (normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

DateTime? _nullableDateTime(Object? value) {
  final raw = _nullableString(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}
