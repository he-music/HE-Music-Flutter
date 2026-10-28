import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

import 'rust/frb_generated.dart';

import 'rust/api/api.dart' as api;
import 'rust/api/tag.dart';
import 'rust/api/picture.dart';
import 'rust/api/error.dart';

export 'rust/api/picture.dart';
export 'rust/api/tag.dart';
export 'rust/api/error.dart';

/// Select work at the parser and FFI boundary. Text fields share a tag container,
/// while properties and pictures can be skipped by the underlying parser.
class AudioTagReadOptions {
  const AudioTagReadOptions({
    this.tags = true,
    this.properties = true,
    this.lyrics = true,
    this.pictures = true,
  });

  /// Opt in to just the groups requested by a caller.
  const AudioTagReadOptions.only({
    this.tags = false,
    this.properties = false,
    this.lyrics = false,
    this.pictures = false,
  });

  static const all = AudioTagReadOptions();
  static const scan = AudioTagReadOptions(lyrics: false, pictures: false);

  final bool tags;
  final bool properties;
  final bool lyrics;
  final bool pictures;
}

class AudioTags {
  static Future<void>? _initialization;

  static Future<void> _ensureInitialized() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    try {
      if (Platform.isMacOS || Platform.isIOS) {
        await RustLib.init(
          externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
        );
      } else {
        await RustLib.init();
      }
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  /// Read the metadata at the given path. Returns
  /// a [Tag] or null if there is no metadata.
  static Future<Tag?> read(
    String path, {
    AudioTagReadOptions options = AudioTagReadOptions.all,
  }) async {
    await _ensureInitialized();

    try {
      return await api.readWithOptions(
        path: path,
        tags: options.tags,
        properties: options.properties,
        lyrics: options.lyrics,
        pictures: options.pictures,
      );
    } on AudioTagsError catch (e) {
      switch (e) {
        case AudioTagsError_NoTags():
          return null;
        default:
          rethrow;
      }
    }
  }

  /// Return a front cover (or the first non-empty picture), with audio
  /// property calculation disabled and without returning text metadata.
  /// Null means a successful read found no artwork; I/O errors are thrown.
  static Future<Picture?> readArtwork(String path) async {
    await _ensureInitialized();
    return api.readArtwork(path: path);
  }

  /// Write the metadata at the given path. Previous metadata will
  /// be cleared and the metadata in [tag] will be written.
  ///
  /// Can throw a [AudioTagsError].
  static Future<void> write(String path, Tag tag) async {
    await _ensureInitialized();

    return await api.write(path: path, data: tag);
  }
}
