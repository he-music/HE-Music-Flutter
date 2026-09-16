import 'dart:io';
import '../../domain/entities/lyric_request.dart';
import '../../domain/entities/raw_lyric_bundle.dart';
import '../storage/lyric_store.dart';

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
    this._metadataReader, {
    LyricStore? store,
    this.onWarning,
  }) : _store = store ?? LyricStore.shared;

  final LyricStore _store;
  final void Function(String)? onWarning;

  final OnlineLyricDataSource _onlineDataSource;
  final DemoLyricDataSource _demoDataSource;
  final LocalAudioMetadataReader _metadataReader;

  @override
  Future<LyricDocument> fetchLyrics({
    required String trackId,
    String? platform,
    String? localPath,
  }) async {
    final target = LyricRequest(
      trackId: trackId,
      platform: platform,
      localPath: localPath,
    );
    final epoch = _store.automaticEpoch;
    try {
      final manual = await _store.read(target, manual: true);
      if (manual != null) return _parse(manual).withSource(LyricSource.manual);
    } catch (_) {
      onWarning?.call('手动歌词读取失败，已临时使用默认歌词；原选择仍保留');
    }
    final normalizedPlatform = platform?.trim() ?? '';
    final normalizedPath = localPath?.trim() ?? '';
    if (normalizedPlatform == 'local' && normalizedPath.isNotEmpty) {
      final localDocument = await _readLocalLyrics(normalizedPath);
      if (!localDocument.isEmpty) {
        return localDocument.withSource(LyricSource.local);
      }
      return const LyricDocument.empty();
    }
    if (normalizedPlatform.isNotEmpty) {
      try {
        final cached = await _store.read(target, manual: false);
        if (cached != null && epoch == _store.automaticEpoch) {
          return _parse(cached).withSource(LyricSource.cache);
        }
      } catch (_) {
        /* Cache failure must not block default retrieval. */
      }
      try {
        final onlineRaw = await _onlineDataSource.fetchRawLyric(
          trackId: trackId,
          platform: normalizedPlatform,
        );
        if (onlineRaw != null && LyricStore.usable(onlineRaw)) {
          try {
            await _store.saveAutomatic(target, onlineRaw, epoch);
          } catch (_) {
            /* Display remains available when disk is full. */
          }
          return _parse(onlineRaw).withSource(LyricSource.online);
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

  LyricDocument _parse(RawLyricBundle bundle) => parseLyricDocument(
    lyric: bundle.lyric,
    translation: bundle.translation,
    romanization: bundle.romanization,
  );

  LyricDocument _parseLocal(String raw) {
    final split = splitLocalLyrics(raw);
    return parseLyricDocument(
      lyric: split.lyric,
      translation: split.translation,
      romanization: split.romanization,
    );
  }

  Future<LyricDocument> _readLocalLyrics(String filePath) async {
    if (filePath.startsWith('file:')) {
      filePath = Uri.parse(filePath).toFilePath();
    }
    final sidecar = await _readSidecarLrc(filePath);
    if (sidecar.isNotEmpty) {
      final document = _parseLocal(sidecar);
      if (!document.isEmpty) return document;
    }
    try {
      final metadata = await _metadataReader.read(filePath);
      final raw = metadata?.embeddedLyrics?.trim() ?? '';
      if (raw.isNotEmpty) return _parseLocal(raw);
    } catch (_) {
      /* An unavailable local source falls through to empty. */
    }
    return const LyricDocument.empty();
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
