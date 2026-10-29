import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DownloadPathDataSource {
  DownloadPathDataSource({bool? isIOS}) : _isIOS = isIOS ?? Platform.isIOS;

  final bool _isIOS;
  String get _directoryName => _isIOS ? 'Downloads' : 'HEMusic';

  Future<List<Directory>> _candidateDirectories() async {
    final documents = await getApplicationDocumentsDirectory();
    final downloads = _isIOS ? null : await getDownloadsDirectory();
    return [
      if (downloads != null) Directory('${downloads.path}/$_directoryName'),
      Directory('${documents.path}/$_directoryName'),
    ];
  }

  /// Discover both the preferred and fallback locations without creating folders.
  Future<List<Directory>> existingDownloadDirectories() async {
    final directories = <Directory>[];
    for (final directory in await _candidateDirectories()) {
      if (await directory.exists() &&
          !directories.any((existing) => existing.path == directory.path)) {
        directories.add(directory);
      }
    }
    return directories;
  }

  Future<Directory> ensureDownloadDirectory() async {
    final candidates = await _candidateDirectories();
    for (var index = 0; index < candidates.length; index++) {
      final directory = candidates[index];
      try {
        if (await directory.exists()) return directory;
        return await directory.create(recursive: true);
      } on FileSystemException {
        if (index == candidates.length - 1) rethrow;
      }
    }
    throw StateError('No download directory available');
  }
}
