enum LocalArtworkState { unknown, present, absent, failed }

class LocalArtworkJob {
  const LocalArtworkJob({
    required this.songId,
    required this.filePath,
    required this.fileSize,
    required this.modifiedAt,
  });

  final String songId;
  final String filePath;
  final int fileSize;
  final int? modifiedAt;
}

class LocalArtworkResult {
  const LocalArtworkResult(this.job, this.state);

  final LocalArtworkJob job;
  final LocalArtworkState state;
}
