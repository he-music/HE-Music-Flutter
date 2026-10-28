import 'dart:io';

import 'package:path/path.dart' as p;

class ScannedAudioFile {
  const ScannedAudioFile(this.path, this.size, this.modifiedAt);

  final String path;
  final int size;
  final int modifiedAt;
}

/// Enumerates each real directory once. Only symbolic links need resolution;
/// ordinary audio files share their directory's already canonical path.
/// Failures propagate so an incomplete scan cannot delete existing library rows.
class LocalMusicFileScanner {
  const LocalMusicFileScanner({this.statConcurrency = 8});

  final int statConcurrency;

  Future<List<ScannedAudioFile>> scan(List<String> folders) async {
    if (statConcurrency < 1) throw ArgumentError.value(statConcurrency);
    final roots = <({String actual, String display})>[];
    for (final folder in folders) {
      final actual = await Directory(folder).resolveSymbolicLinks();
      if (roots.any((root) => root.actual == actual)) continue;
      roots.add((actual: actual, display: p.normalize(folder)));
    }
    // Keep configured-root order so an existing alias keeps its song IDs.
    // The shared visited set skips overlapping subtrees without changing paths.
    final seenDirectories = <String>{};
    final seenFiles = <String>{};
    final results = <ScannedAudioFile>[];
    final pending = <({String actual, String display})>[];

    Future<void> flush() async {
      final files = await Future.wait(
        pending.map((entry) async {
          final stat = await File(entry.actual).stat();
          if (stat.type != FileSystemEntityType.file) {
            throw FileSystemException(
              'Audio file became unavailable',
              entry.display,
            );
          }
          return ScannedAudioFile(
            entry.display,
            stat.size,
            stat.modified.millisecondsSinceEpoch,
          );
        }),
      );
      results.addAll(files);
      pending.clear();
    }

    Future<void> visit(String actual, String display) async {
      if (!seenDirectories.add(actual)) return;
      await for (final entity in Directory(actual).list(followLinks: false)) {
        final displayPath = p.join(display, p.basename(entity.path));
        if (entity is Directory) {
          await visit(entity.path, displayPath);
        } else if (entity is Link) {
          final type = await FileSystemEntity.type(entity.path);
          if (type == FileSystemEntityType.notFound) continue;
          final resolved = await entity.resolveSymbolicLinks();
          if (type == FileSystemEntityType.directory) {
            await visit(resolved, displayPath);
          } else if (type == FileSystemEntityType.file &&
              isSupportedAudioFile(displayPath) &&
              seenFiles.add(resolved)) {
            pending.add((actual: resolved, display: displayPath));
          }
        } else if (entity is File &&
            isSupportedAudioFile(entity.path) &&
            seenFiles.add(entity.path)) {
          pending.add((actual: entity.path, display: displayPath));
        }
        if (pending.length >= statConcurrency) await flush();
      }
    }

    for (final root in roots) {
      await visit(root.actual, root.display);
    }
    if (pending.isNotEmpty) await flush();
    return results;
  }

  static bool isSupportedAudioFile(String path) => const {
    '.mp3',
    '.flac',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.ape',
    '.aiff',
    '.aif',
  }.contains(p.extension(path).toLowerCase());
}
