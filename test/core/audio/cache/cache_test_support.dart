import 'dart:async';
import 'dart:io';

import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_key.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';

/// Faults only the filesystem delete boundary; store ownership/clear stay real.
final class CacheFileDeletionFault {
  String? blockedPath;

  Future<void> delete(String path) async {
    if (path == blockedPath) {
      throw FileSystemException('injected deletion failure', path);
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      throw StateError('Unexpected cache file type');
    }
  }
}

AudioCacheKey cacheKey({
  String platform = 'qq',
  String track = 'song',
  int quality = 320,
  String format = 'mp3',
  int schema = 1,
}) => AudioCacheKey.tryCreate(
  schema: schema,
  platform: platform,
  trackId: track,
  quality: quality,
  requestedFormat: format,
)!;

final class FakeCapacity implements AudioCacheDiskCapacityPort {
  int calls = 0;
  final paths = <String>[];
  FutureOr<int?> Function()? query;
  int? value = AudioCachePolicy.physicalFloorBytes + 100000;

  @override
  Future<int?> availableBytes(String cachePath) async {
    calls++;
    paths.add(cachePath);
    return query == null ? value : await query!();
  }
}

Future<AudioCacheSourceLease?> admit(
  FileAudioCacheStore store, {
  AudioCacheKey? key,
  int? expected = 10,
  int limit = 100,
  String format = 'mp3',
}) => store.admitAndBeginWrite(
  key: key ?? cacheKey(),
  resolvedFormat: format,
  expectedBytes: expected,
  limitBytes: limit,
);

Future<AudioCacheSourceLease> publish(
  FileAudioCacheStore store, {
  AudioCacheKey? key,
  int bytes = 10,
  int limit = 100,
  String format = 'mp3',
}) async {
  final lease = (await admit(
    store,
    key: key,
    expected: bytes,
    limit: limit,
    format: format,
  ))!;
  await File(lease.path).writeAsBytes(List.filled(bytes, 1));
  await store.completeWrite(lease, mimeType: 'application/octet-stream');
  return lease;
}
