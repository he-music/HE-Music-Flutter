import 'dart:io';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/repositories/lyric_repository.dart';
import '../../domain/usecases/parse_lrc.dart';
import '../datasources/demo_lyric_data_source.dart';
import '../datasources/online_lyric_data_source.dart';

class LyricRepositoryImpl implements LyricRepository {
  LyricRepositoryImpl(
    this._onlineDataSource,
    this._demoDataSource,
    this._metadataReader,
  );

  final OnlineLyricDataSource _onlineDataSource;
  final DemoLyricDataSource _demoDataSource;
  final LocalAudioMetadataReader _metadataReader;

  @override
  Future<LyricDocument> fetchLyrics({
    required String trackId,
    String? platform,
    String? localPath,
  }) async {
    final normalizedPlatform = platform?.trim() ?? '';
    final normalizedPath = localPath?.trim() ?? '';
    if (normalizedPlatform == 'local' && normalizedPath.isNotEmpty) {
      final localDocument = await _readLocalLyrics(normalizedPath);
      if (!localDocument.isEmpty) {
        return localDocument;
      }
      return const LyricDocument.empty();
    }
    if (normalizedPlatform.isNotEmpty) {
      try {
        final onlineRaw = await _onlineDataSource.fetchRawLyric(
          trackId: trackId,
          platform: normalizedPlatform,
        );
        if (onlineRaw != null && onlineRaw.lyric.trim().isNotEmpty) {
          return parseLyricDocument(
            lyric: onlineRaw.lyric,
            translation: onlineRaw.translation,
            romanization: onlineRaw.romanization,
          );
        }
      } catch (_) {
        return const LyricDocument.empty();
      }
      return const LyricDocument.empty();
    }
    final demoRaw = await _demoDataSource.fetchRawLyric(trackId);
    if (demoRaw == null || demoRaw.trim().isEmpty) {
      return const LyricDocument.empty();
    }
    final split = splitLocalLyrics(demoRaw);
    return parseLyricDocument(
      lyric: split.lyric,
      translation: split.translation,
      romanization: split.romanization,
    );
  }

  Future<LyricDocument> _readLocalLyrics(String filePath) async {
    try {
      final metadata = await _metadataReader.read(filePath);
      final raw = metadata?.embeddedLyrics?.trim() ?? '';
      if (raw.isNotEmpty) {
        final split = splitLocalLyrics(raw);
        return parseLyricDocument(
          lyric: split.lyric,
          translation: split.translation,
          romanization: split.romanization,
        );
      }
    } catch (_) {
      // 内嵌歌词读取失败时继续尝试同目录 lrc。
    }
    final lrcRaw = await _readSidecarLrc(filePath);
    if (lrcRaw.isEmpty) {
      return const LyricDocument.empty();
    }
    final split = splitLocalLyrics(lrcRaw);
    return parseLyricDocument(
      lyric: split.lyric,
      translation: split.translation,
      romanization: split.romanization,
    );
  }

  Future<String> _readSidecarLrc(String filePath) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      return '';
    }
    final extensionIndex = normalizedPath.lastIndexOf('.');
    if (extensionIndex <= 0) {
      return '';
    }
    final basePath = normalizedPath.substring(0, extensionIndex);
    final candidates = <String>['$basePath.lrc', '$basePath.LRC'];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          return content;
        }
      } catch (_) {
        continue;
      }
    }
    return '';
  }
}
