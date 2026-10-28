import 'dart:io';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;

class LocalAudioMetadata {
  const LocalAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkBytes,
    this.embeddedLyrics,
    this.bitrate,
    this.sampleRate,
    this.genre,
    this.year,
    this.discNumber,
    this.trackNumber,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final Uint8List? artworkBytes;
  final String? embeddedLyrics;
  final int? bitrate;
  final int? sampleRate;
  final String? genre;
  final int? year;
  final int? discNumber;
  final int? trackNumber;
}

typedef ReadAudioTagCallback = Future<at.Tag?> Function(String path);
typedef ReadAudioTagWithOptionsCallback =
    Future<at.Tag?> Function(
      String path, {
      required at.AudioTagReadOptions options,
    });
typedef ReadAudioArtworkCallback = Future<at.Picture?> Function(String path);
typedef FileExistsCallback = Future<bool> Function(String path);

class LocalAudioMetadataReader {
  const LocalAudioMetadataReader({
    ReadAudioTagCallback? readTag,
    ReadAudioTagWithOptionsCallback? readTagWithOptions,
    ReadAudioArtworkCallback? readArtwork,
    FileExistsCallback? fileExists,
  }) : _readTag = readTag,
       _readTagWithOptions = readTagWithOptions,
       _readArtwork = readArtwork,
       _fileExists = fileExists;

  final ReadAudioTagCallback? _readTag;
  final ReadAudioTagWithOptionsCallback? _readTagWithOptions;
  final ReadAudioArtworkCallback? _readArtwork;
  final FileExistsCallback? _fileExists;

  Future<LocalAudioMetadata?> read(
    String filePath, {
    bool fetchArtwork = false,
    bool fetchLyrics = true,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final exists = await (_fileExists ?? _defaultFileExists)(normalizedPath);
    if (!exists) {
      return null;
    }

    try {
      final tag = _readTag != null
          ? await _readTag(normalizedPath)
          : await (_readTagWithOptions ?? at.AudioTags.read)(
              normalizedPath,
              options: at.AudioTagReadOptions(
                lyrics: fetchLyrics,
                pictures: fetchArtwork,
              ),
            );
      if (tag == null) {
        return null;
      }
      final metadata = LocalAudioMetadata(
        title: _normalizeText(tag.title),
        artist: _normalizeArtists(tag.artists, tag.albumArtists),
        album: _normalizeText(tag.album),
        duration: _toDuration(tag.duration),
        artworkBytes: fetchArtwork ? _pickArtwork(tag.pictures) : null,
        embeddedLyrics: fetchLyrics ? _normalizeText(tag.lyrics) : null,
        bitrate: tag.bitrate,
        sampleRate: tag.sampleRate,
        genre: _normalizeText(tag.genre),
        year: tag.year,
        discNumber: tag.discNumber,
        trackNumber: tag.trackNumber,
      );
      if (_isEmpty(metadata)) {
        return null;
      }
      return metadata;
    } catch (_) {
      return null;
    }
  }

  /// Null means the file was read successfully but contains no artwork.
  /// Errors propagate so callers can retry instead of caching a false absence.
  Future<Uint8List?> readArtwork(String filePath) async {
    final picture = await (_readArtwork ?? at.AudioTags.readArtwork)(filePath);
    return picture?.bytes;
  }

  Future<bool> _defaultFileExists(String path) async {
    return File(path).exists();
  }

  bool _isEmpty(LocalAudioMetadata metadata) {
    return metadata.title == null &&
        metadata.artist == null &&
        metadata.album == null &&
        metadata.duration == null &&
        metadata.artworkBytes == null &&
        metadata.embeddedLyrics == null &&
        metadata.bitrate == null &&
        metadata.sampleRate == null &&
        metadata.genre == null &&
        metadata.year == null &&
        metadata.discNumber == null &&
        metadata.trackNumber == null;
  }

  String? _normalizeArtists(List<String> artists, List<String> albumArtists) {
    final normalized = <String>{
      ...artists.map(_normalizeText).whereType<String>(),
      ...albumArtists.map(_normalizeText).whereType<String>(),
    }.toList(growable: false);
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.join(' / ');
  }

  String? _normalizeText(String? value) {
    final normalized = value
        ?.replaceAll('\u0000', ' / ')
        .replaceAll(RegExp(r'\s+/\s+'), ' / ')
        .trim();
    if (normalized == null || normalized.isEmpty || normalized == '<unknown>') {
      return null;
    }
    return normalized;
  }

  Duration? _toDuration(int? duration) {
    if (duration == null || duration <= 0) {
      return null;
    }
    return Duration(seconds: duration);
  }

  Uint8List? _pickArtwork(List<at.Picture> pictures) {
    if (pictures.isEmpty) {
      return null;
    }
    for (final picture in pictures) {
      if (picture.pictureType == at.PictureType.coverFront &&
          picture.bytes.isNotEmpty) {
        return picture.bytes;
      }
    }
    for (final picture in pictures) {
      if (picture.bytes.isNotEmpty) {
        return picture.bytes;
      }
    }
    return null;
  }
}
