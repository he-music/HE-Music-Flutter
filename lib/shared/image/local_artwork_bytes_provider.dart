import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Visible rows share one read per path; unused artwork is released automatically.
final localArtworkBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, path) async {
      final normalized = path.trim();
      if (normalized.isEmpty) return null;
      try {
        final bytes = await File(normalized).readAsBytes();
        return bytes.isEmpty ? null : bytes;
      } on FileSystemException {
        return null;
      }
    });
