import '../../../lyrics/data/datasources/online_lyric_data_source.dart';
import '../../../lyrics/domain/entities/raw_lyric_bundle.dart';
import '../../../lyrics/domain/usecases/parse_lrc.dart';
import '../../domain/entities/download_task.dart';

typedef FetchRawDownloadLyric =
    Future<RawLyricBundle?> Function({
      required String trackId,
      required String platform,
    });

class ResolvedDownloadLyric {
  const ResolvedDownloadLyric({required this.content, required this.format});

  const ResolvedDownloadLyric.none()
    : content = null,
      format = DownloadLyricFormat.none;

  final String? content;
  final DownloadLyricFormat format;
}

class DownloadLyricResolver {
  DownloadLyricResolver(this._fetchRawLyric);

  factory DownloadLyricResolver.fromDataSource(
    OnlineLyricDataSource dataSource,
  ) {
    return DownloadLyricResolver(dataSource.fetchRawLyric);
  }

  final FetchRawDownloadLyric _fetchRawLyric;

  Future<ResolvedDownloadLyric> resolve({
    required String songId,
    required String platform,
  }) async {
    final bundle = await _fetchRawLyric(trackId: songId, platform: platform);
    return resolveBundle(bundle);
  }

  ResolvedDownloadLyric resolveBundle(RawLyricBundle? bundle) {
    final lyric = bundle?.lyric.trim() ?? '';
    if (lyric.isEmpty) {
      return const ResolvedDownloadLyric.none();
    }
    if (hasTimedLyricEntries(lyric)) {
      return ResolvedDownloadLyric(
        content: isWordLyric(lyric) ? normalizeWordLyricText(lyric) : lyric,
        format: DownloadLyricFormat.timed,
      );
    }
    return ResolvedDownloadLyric(
      content: lyric,
      format: DownloadLyricFormat.plain,
    );
  }
}
