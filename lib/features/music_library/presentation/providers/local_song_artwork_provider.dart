import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_library_providers.dart';

/// Mounted rows share one read per audio path and release bytes when unused.
final localSongArtworkProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, filePath) async {
      if (filePath.trim().isEmpty) return null;
      final extractor = ref.read(localArtworkExtractorProvider);
      try {
        final bytes = await extractor.getArtworkBytes(filePath);
        if (bytes == null || bytes.isEmpty) return null;
        return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      } catch (_) {
        return null;
      }
    });
