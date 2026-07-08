import 'dart:io';

import 'package:audiotags/audiotags.dart' as at;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/download_task.dart';
import 'download_lyric_resolver.dart';

class DownloadMetadataRequest {
  const DownloadMetadataRequest({
    required this.filePath,
    required this.songId,
    required this.platform,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
  });

  final String filePath;
  final String songId;
  final String platform;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
}

class DownloadMetadataWriteResult {
  const DownloadMetadataWriteResult({
    required this.lyricFormat,
    required this.artworkEmbedded,
    required this.lyricPath,
  });

  final DownloadLyricFormat lyricFormat;
  final bool artworkEmbedded;
  final String? lyricPath;
}

abstract class DownloadMetadataAdapter {
  Future<void> write({
    required String path,
    required String title,
    required String artist,
    required String album,
    Uint8List? artworkBytes,
    String? lyrics,
  });
}

typedef ReadAudioTagCallback = Future<at.Tag?> Function(String path);
typedef WriteAudioTagCallback = Future<void> Function(String path, at.Tag tag);

class AudioMetadataAdapter implements DownloadMetadataAdapter {
  const AudioMetadataAdapter({
    ReadAudioTagCallback? readTag,
    WriteAudioTagCallback? writeTag,
  }) : _readTag = readTag,
       _writeTag = writeTag;

  final ReadAudioTagCallback? _readTag;
  final WriteAudioTagCallback? _writeTag;

  @override
  Future<void> write({
    required String path,
    required String title,
    required String artist,
    required String album,
    Uint8List? artworkBytes,
    String? lyrics,
  }) async {
    try {
      at.Tag? currentTag;
      try {
        currentTag = await (_readTag ?? at.AudioTags.read)(path);
      } catch (error, stackTrace) {
        debugPrint(
          'AudioMetadataAdapter.write read existing tag failed, fallback to empty tag. '
          'path=$path error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      final normalizedArtists = _normalizeTagArtists(artist);
      final nextTag = at.Tag(
        title: title,
        artists: normalizedArtists,
        album: album,
        albumArtists: normalizedArtists,
        year: currentTag?.year,
        genre: currentTag?.genre,
        trackNumber: currentTag?.trackNumber,
        trackTotal: currentTag?.trackTotal,
        discNumber: currentTag?.discNumber,
        discTotal: currentTag?.discTotal,
        lyrics: lyrics,
        bpm: currentTag?.bpm,
        pictures: _resolvePictures(artworkBytes, currentTag?.pictures),
      );
      debugPrint(
        'DownloadMetadataWriter.write path=$path '
        'artists=${nextTag.artists} '
        'albumArtists=${nextTag.albumArtists} '
        'pictures=${nextTag.pictures.length}',
      );
      await (_writeTag ?? at.AudioTags.write)(path, nextTag);
    } catch (error, stackTrace) {
      debugPrint(
        'DownloadMetadataWriter.write failed path=$path '
        'artist="$artist" album="$album" error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<String> _normalizeTagArtists(String artist) {
    final parts = artist
        .split(RegExp(r'\s*(?:/|,|，|&)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      final fallback = artist.trim();
      return fallback.isEmpty ? const <String>[] : <String>[fallback];
    }
    return parts;
  }

  List<at.Picture> _resolvePictures(
    Uint8List? artworkBytes,
    List<at.Picture>? currentPictures,
  ) {
    if (artworkBytes != null && artworkBytes.isNotEmpty) {
      return <at.Picture>[
        at.Picture(
          pictureType: at.PictureType.coverFront,
          mimeType: inferArtworkMimeType(artworkBytes),
          bytes: artworkBytes,
        ),
      ];
    }
    return currentPictures ?? const <at.Picture>[];
  }
}

class DownloadMetadataWriter {
  const DownloadMetadataWriter({
    required DownloadLyricResolver lyricResolver,
    required DownloadMetadataAdapter metadataAdapter,
    Dio? dio,
  }) : _lyricResolver = lyricResolver,
       _metadataAdapter = metadataAdapter,
       _dio = dio;

  final DownloadLyricResolver _lyricResolver;
  final DownloadMetadataAdapter _metadataAdapter;
  final Dio? _dio;

  Future<DownloadMetadataWriteResult> write(
    DownloadMetadataRequest request,
  ) async {
    final lyric = await _lyricResolver.resolve(
      songId: request.songId,
      platform: request.platform,
    );
    final artworkBytes = await _loadArtworkBytes(request.artworkUrl);
    final lyricPath = await _writeLyricFile(
      filePath: request.filePath,
      lyrics: lyric.content,
    );
    await _metadataAdapter.write(
      path: request.filePath,
      title: request.title,
      artist: request.artist,
      album: request.album,
      artworkBytes: artworkBytes,
      lyrics: lyric.content,
    );
    return DownloadMetadataWriteResult(
      lyricFormat: lyric.format,
      artworkEmbedded: artworkBytes != null && artworkBytes.isNotEmpty,
      lyricPath: lyricPath,
    );
  }

  Future<Uint8List?> _loadArtworkBytes(String? artworkUrl) async {
    final url = artworkUrl?.trim() ?? '';
    final dio = _dio;
    if (url.isEmpty || dio == null) {
      return null;
    }
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      return null;
    }
    return Uint8List.fromList(data);
  }

  Future<String?> _writeLyricFile({
    required String filePath,
    required String? lyrics,
  }) async {
    final content = lyrics?.trim() ?? '';
    if (content.isEmpty) {
      return null;
    }
    final lyricPath = _toLyricFilePath(filePath);
    if (lyricPath.isEmpty) {
      return null;
    }
    final file = File(lyricPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}

String _toLyricFilePath(String filePath) {
  final normalized = filePath.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final lastSeparator = normalized.lastIndexOf(RegExp(r'[\\/]'));
  final lastDot = normalized.lastIndexOf('.');
  if (lastDot <= lastSeparator) {
    return '$normalized.lrc';
  }
  return '${normalized.substring(0, lastDot)}.lrc';
}

at.MimeType? inferArtworkMimeType(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return at.MimeType.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return at.MimeType.jpeg;
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return at.MimeType.gif;
  }
  if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return at.MimeType.bmp;
  }
  if (bytes.length >= 4 &&
      ((bytes[0] == 0x49 &&
              bytes[1] == 0x49 &&
              bytes[2] == 0x2A &&
              bytes[3] == 0x00) ||
          (bytes[0] == 0x4D &&
              bytes[1] == 0x4D &&
              bytes[2] == 0x00 &&
              bytes[3] == 0x2A))) {
    return at.MimeType.tiff;
  }
  return at.MimeType.jpeg;
}
