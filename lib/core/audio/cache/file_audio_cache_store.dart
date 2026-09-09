import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'audio_cache_disk_capacity_port.dart';
import 'audio_cache_entry.dart';
import 'audio_cache_key.dart';
import 'audio_cache_policy.dart';
import 'audio_cache_store.dart';

/// One instance per process, shared by playback and settings. Transport may
/// write outside this queue; all ownership and index mutations remain inside it.
final class FileAudioCacheStore implements AudioCacheStore {
  FileAudioCacheStore({
    required AudioCacheDiskCapacityPort capacity,
    Future<Directory> Function()? applicationCacheDirectory,
    DateTime Function()? clock,
    this.schema = AudioCacheKey.currentSchema,
    Duration capacityTimeout = const Duration(seconds: 1),
    Future<void> Function(Directory)? deleteOldSchema,
    Future<void> Function(String)? deleteFile,
    void Function(String operation)? diagnostic,
  }) : _capacity = capacity,
       _applicationCacheDirectory =
           applicationCacheDirectory ?? getApplicationCacheDirectory,
       _clock = clock ?? DateTime.now,
       _capacityTimeout = capacityTimeout > const Duration(seconds: 1)
           ? const Duration(seconds: 1)
           : capacityTimeout,
       _deleteOldSchema = deleteOldSchema ?? _deleteDirectory,
       _deleteFile = deleteFile ?? _deleteFileFromDisk,
       _diagnostic = diagnostic;

  final AudioCacheDiskCapacityPort _capacity;
  final Future<Directory> Function() _applicationCacheDirectory;
  final DateTime Function() _clock;
  final Duration _capacityTimeout;
  final Future<void> Function(Directory) _deleteOldSchema;
  final Future<void> Function(String) _deleteFile;
  final void Function(String operation)? _diagnostic;
  final int schema;
  final _entries = <String, _Entry>{};
  final _trackIndex = <(String, String), Set<String>>{};
  final _leases = <_FileLease>{};
  final _writers = <String, _FileLease>{};
  final _garbage = <String, int>{};
  final _snapshots = StreamController<AudioCacheSnapshot>.broadcast();
  Future<void> _tail = Future<void>.value();
  Future<void>? _initialization;
  Future<void> _schemaCleanup = Future<void>.value();
  Directory? _root;
  int _clearEpoch = 0;
  int _limitBytes = AudioCachePolicy.defaultLimitBytes;
  int? _configuredLimitBytes;
  bool _closed = false;
  bool _readFused = false;
  bool _writeFused = false;
  bool _initialized = false;
  AudioCacheSnapshot _snapshot = const AudioCacheSnapshot();

  @override
  AudioCacheReadHealth get readHealth => _readFused || _closed
      ? AudioCacheReadHealth.unavailable
      : _initialized
      ? AudioCacheReadHealth.ready
      : AudioCacheReadHealth.initializing;
  @override
  AudioCacheWriteHealth get writeHealth => _writeFused || _readFused || _closed
      ? AudioCacheWriteHealth.unavailable
      : _initialized
      ? AudioCacheWriteHealth.ready
      : AudioCacheWriteHealth.initializing;
  @override
  AudioCacheSnapshot get snapshot => _snapshot;
  @override
  Stream<AudioCacheSnapshot> get snapshots => _snapshots.stream;

  /// Observability for shutdown/tests; lookup never awaits old-schema deletion.
  Future<void> get oldSchemaCleanup => _schemaCleanup;

  void _report(String operation) {
    try {
      _diagnostic?.call(operation);
    } catch (_) {
      /* Diagnostics are optional. */
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<T> _ready<T>(Future<T> Function() operation) async {
    await initialize();
    return _serialize(operation);
  }

  @override
  Future<void> initialize() => _initialization ??= _serialize(() async {
    if (_closed || _readFused) return;
    try {
      if (schema <= 0) throw StateError('Invalid cache schema');
      final cache = await _applicationCacheDirectory();
      _root = Directory(p.join(cache.path, 'he_music', 'audio', 'v$schema'));
      await _ensureDirectories();
      await _reconcile();
      // A health fence raised during initialization must not be overwritten.
      if (_closed || _readFused) return;
      _initialized = true;
      _emit();
      _schemaCleanup = Future<void>(_cleanupOldSchemas);
    } catch (_) {
      _entries.clear();
      _trackIndex.clear();
      markReadUnavailable();
      _report('store_initialize_failed');
    }
  });

  Directory get _data => Directory(p.join(_root!.path, 'data'));
  Directory get _metadata => Directory(p.join(_root!.path, 'entries'));
  Directory get _temp => Directory(p.join(_root!.path, 'temp'));
  File _metadataFile(String digest) =>
      File(p.join(_metadata.path, '$digest.json'));

  Future<void> _ensureDirectories() async {
    for (final directory in [
      _root!.parent.parent,
      _root!.parent,
      _root!,
      _data,
      _metadata,
      _temp,
    ]) {
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw StateError('Cache directory is not a directory');
      }
      await directory.create(recursive: true);
    }
  }

  Future<_Entry?> _readEntry(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    AudioCacheMetadata? metadata;
    try {
      metadata = AudioCacheMetadata.tryParse(
        jsonDecode(await file.readAsString()),
      );
    } on FormatException {
      return null;
    }
    if (metadata == null ||
        metadata.key.schema != schema ||
        p.basename(file.path) != '${metadata.key.digest}.json') {
      return null;
    }
    final data = File(p.join(_data.path, metadata.fileName));
    if (await FileSystemEntity.type(data.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    final stat = await data.stat();
    if (stat.size != metadata.actualBytes || stat.size <= 0) return null;
    return _Entry(metadata, data.path, stat.modified);
  }

  Future<void> _reconcile() async {
    final referenced = <String>{};
    await for (final item in _metadata.list(followLinks: false)) {
      final entry = item is File ? await _readEntry(item) : null;
      if (entry == null) {
        await item.delete(recursive: item is Directory);
      } else {
        _index(entry);
        referenced.add(entry.path);
        referenced.add('${entry.path}.mime');
      }
    }
    await for (final item in _data.list(followLinks: false)) {
      if (!referenced.contains(item.path) || item is! File) {
        await item.delete(recursive: item is Directory);
      }
    }
    await for (final item in _temp.list(followLinks: false)) {
      await item.delete(recursive: item is Directory);
    }
  }

  Future<void> _cleanupOldSchemas() async {
    try {
      await for (final item in _root!.parent.list(followLinks: false)) {
        if (item is! Directory) continue;
        final match = RegExp(
          r'^v([1-9][0-9]*|0)$',
        ).firstMatch(p.basename(item.path));
        final version = match == null ? null : int.tryParse(match[1]!);
        if (version == null || version >= schema) continue;
        try {
          await _deleteOldSchema(item);
        } catch (_) {
          _report('old_schema_delete_failed');
        }
      }
    } catch (_) {
      _report('old_schema_enumerate_failed');
    }
  }

  void _index(_Entry entry) {
    final key = entry.metadata.key;
    _entries[key.digest] = entry;
    (_trackIndex[key.trackIdentity] ??= {}).add(key.digest);
  }

  @override
  Future<AudioCacheSourceLease?> lookupAndPin(
    AudioCacheKey key, {
    bool offline = false,
  }) => readHealth == AudioCacheReadHealth.unavailable
      ? Future.value()
      : _ready(() async {
          if (readHealth != AudioCacheReadHealth.ready ||
              key.schema != schema) {
            return null;
          }
          final candidates = <String>[key.digest];
          if (offline) {
            final alternatives = (_trackIndex[key.trackIdentity] ?? <String>{})
                .where((digest) => digest != key.digest)
                .map((digest) => _entries[digest]!)
                .toList();
            // Refresh mtime from data so external deletion and a prior process agree.
            for (final entry in alternatives) {
              try {
                entry.modified = (await File(entry.path).stat()).modified;
              } catch (_) {
                /* Validation below removes unusable candidates. */
              }
            }
            alternatives.sort((a, b) => b.modified.compareTo(a.modified));
            candidates.addAll(
              alternatives.map((entry) => entry.metadata.key.digest),
            );
          }
          for (final digest in candidates) {
            if (!_entries.containsKey(digest)) continue;
            _Entry? entry;
            try {
              entry = await _readEntry(_metadataFile(digest));
            } catch (_) {
              _report('lookup_validation_failed');
            }
            if (entry == null) {
              await _removeEntry(digest);
              continue;
            }
            if (readHealth != AudioCacheReadHealth.ready) return null;
            final lease = _FileLease(
              this,
              key: entry.metadata.key,
              path: entry.path,
              resolvedFormat: entry.metadata.resolvedFormat,
              acquisitionEpoch: _clearEpoch,
              state: AudioCacheLeaseState.pinnedData,
              expectedBytes: 0,
              materializedBytes: entry.metadata.actualBytes,
              publication: AudioCachePublication.published,
            );
            _leases.add(lease);
            _emit();
            return lease;
          }
          _emit();
          return null;
        });

  @override
  Future<AudioCacheSourceLease?> admitAndBeginWrite({
    required AudioCacheKey key,
    required String resolvedFormat,
    required int? expectedBytes,
    required int limitBytes,
  }) => writeHealth == AudioCacheWriteHealth.unavailable
      ? Future.value()
      : _ready(() async {
          final format = resolvedFormat.trim().toLowerCase();
          final admissionLimit = math.min(
            limitBytes,
            _configuredLimitBytes ?? limitBytes,
          );
          if (writeHealth != AudioCacheWriteHealth.ready ||
              key.schema != schema ||
              expectedBytes == null ||
              expectedBytes <= 0 ||
              expectedBytes > admissionLimit ||
              !audioCacheFormats.contains(format) ||
              _writers.containsKey(key.digest) ||
              _entries.containsKey(key.digest)) {
            return null;
          }
          // A delayed source may carry an older frozen policy. It must never
          // undo a newer explicit management-target change from settings.
          _limitBytes = _configuredLimitBytes ?? limitBytes;
          try {
            await _ensureDirectories();
          } catch (_) {
            markWriteUnavailable();
            _report('writer_initialize_failed');
            return null;
          }
          await _refreshMaterialized();
          await _evictTo(admissionLimit - expectedBytes);
          if (_managedBytes + expectedBytes > admissionLimit) {
            _emit();
            return null;
          }
          // Keep this basis and the mutation queue through query and reservation.
          // Transport can advance, but completion/abort/clear cannot cross the fence.
          final capturedRemaining = _writers.values.fold<int>(
            0,
            (total, lease) =>
                total +
                math.max(lease.expectedBytes - lease.materializedBytes, 0),
          );
          int? available;
          try {
            available = await _capacity
                .availableBytes(_root!.path)
                .timeout(_capacityTimeout);
          } catch (_) {
            _report('capacity_query_unavailable');
          }
          if (available == null ||
              available <
                  AudioCachePolicy.physicalFloorBytes +
                      expectedBytes +
                      capturedRemaining ||
              writeHealth != AudioCacheWriteHealth.ready) {
            _emit();
            return null;
          }
          final session = const Uuid().v4();
          final lease = _FileLease(
            this,
            key: key,
            path: p.join(_data.path, '${key.digest}.$session.$format'),
            resolvedFormat: format,
            acquisitionEpoch: _clearEpoch,
            state: AudioCacheLeaseState.activeWrite,
            expectedBytes: expectedBytes,
          );
          _writers[key.digest] = lease;
          _leases.add(lease);
          _emit();
          return lease;
        });

  _FileLease? _owned(AudioCacheSourceLease lease) =>
      lease is _FileLease && identical(lease.store, this) ? lease : null;

  @override
  Future<AudioCachePublication> completeWrite(
    AudioCacheSourceLease lease, {
    String? mimeType,
  }) => _ready(() async {
    final owned = _owned(lease);
    if (owned == null) return AudioCachePublication.rejected;
    if (!_leases.contains(owned) ||
        owned.state != AudioCacheLeaseState.activeWrite ||
        !identical(_writers[owned.key.digest], owned)) {
      // A late terminal can clean only its unique session, never a newer writer.
      if ((!_leases.contains(owned) ||
              owned.state == AudioCacheLeaseState.cancelled ||
              owned.state == AudioCacheLeaseState.failed) &&
          !_pathIsIndexed(owned.path) &&
          !_pathIsLeasedByAnother(owned)) {
        await _deleteSession(owned.path);
      }
      return owned.publication;
    }
    _writers.remove(owned.key.digest);
    final file = File(owned.path);
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      final stat = await file.stat();
      if (type != FileSystemEntityType.file || stat.size <= 0) {
        owned.state = AudioCacheLeaseState.failed;
        owned.publication = AudioCachePublication.rejected;
        owned.materializedBytes = 0;
        await _deleteSession(owned.path);
      } else {
        owned.state = AudioCacheLeaseState.retainedData;
        owned.materializedBytes = stat.size;
        var mime = mimeType;
        final mimeFile = File('${owned.path}.mime');
        if (mime == null && await mimeFile.exists()) {
          mime = await mimeFile.readAsString();
        }
        final mimeValidation = validateAudioCacheMime(
          owned.resolvedFormat,
          mime,
        );
        if (mimeValidation == AudioCacheMimeValidation.unverified) {
          _report('mime_unverified');
        }
        final suppressed =
            owned.publishSuppressed ||
            owned.acquisitionEpoch != _clearEpoch ||
            readHealth != AudioCacheReadHealth.ready;
        owned.publication = suppressed
            ? AudioCachePublication.suppressed
            : AudioCachePublication.rejected;
        if (!suppressed &&
            owned.resolvedFormat == owned.key.requestedFormat &&
            audioCacheFormats.contains(owned.resolvedFormat) &&
            mimeValidation != AudioCacheMimeValidation.conflict &&
            stat.size <= _limitBytes) {
          final now = _clock();
          final metadata = AudioCacheMetadata(
            key: owned.key,
            fileName: p.basename(owned.path),
            resolvedFormat: owned.resolvedFormat,
            actualBytes: stat.size,
            completedAtMs: now.millisecondsSinceEpoch,
          );
          final temporary = File(
            p.join(_temp.path, '${p.basename(owned.path)}.metadata.tmp'),
          );
          await file.setLastModified(now);
          await temporary.writeAsString(
            jsonEncode(metadata.toJson()),
            flush: true,
          );
          // An out-of-queue health fence may arrive during filesystem I/O.
          if (readHealth != AudioCacheReadHealth.ready) {
            owned.publication = AudioCachePublication.suppressed;
            await _deleteFile(temporary.path);
          } else {
            await temporary.rename(_metadataFile(owned.key.digest).path);
            if (readHealth == AudioCacheReadHealth.ready) {
              _index(_Entry(metadata, owned.path, now));
              owned.publication = AudioCachePublication.published;
            } else {
              owned.publication = AudioCachePublication.suppressed;
              await _deleteFile(_metadataFile(owned.key.digest).path);
            }
          }
        } else if (!suppressed) {
          _report('publication_rejected');
        }
      }
    } catch (_) {
      if (owned.state == AudioCacheLeaseState.activeWrite) {
        owned.state = AudioCacheLeaseState.failed;
      }
      if (owned.publication == AudioCachePublication.none) {
        owned.publication = AudioCachePublication.rejected;
      }
      _report('publication_failed');
    }
    await _refreshMaterialized();
    await _evictTo(_limitBytes);
    _emit();
    return owned.publication;
  });

  @override
  Future<void> abort(AudioCacheSourceLease lease, {bool failed = false}) =>
      _ready(() async {
        final owned = _owned(lease);
        if (owned == null ||
            !_leases.contains(owned) ||
            owned.state != AudioCacheLeaseState.activeWrite) {
          return;
        }
        _writers.remove(owned.key.digest);
        owned.state = failed
            ? AudioCacheLeaseState.failed
            : AudioCacheLeaseState.cancelled;
        owned.commitRevoked = true;
        owned.publication = AudioCachePublication.rejected;
        owned.materializedBytes = 0;
        await _deleteSession(owned.path);
        await _evictTo(_limitBytes);
        _emit();
      });

  Future<bool> _commit(_FileLease lease, int generation) => _ready(() async {
    if (!_leases.contains(lease) ||
        lease.committedForPlayback ||
        lease.commitRevoked ||
        lease.acquisitionEpoch != _clearEpoch ||
        readHealth != AudioCacheReadHealth.ready ||
        !{
          AudioCacheLeaseState.pinnedData,
          AudioCacheLeaseState.activeWrite,
          AudioCacheLeaseState.retainedData,
        }.contains(lease.state)) {
      return false;
    }
    lease.committedForPlayback = true;
    lease.playbackGeneration = generation;
    return true;
  });

  Future<void> _touch(_FileLease lease) => _ready(() async {
    if (!lease.committedForPlayback ||
        lease.commitRevoked ||
        lease.clearedDeferred ||
        !_leases.contains(lease)) {
      return;
    }
    final entry = _entries[lease.key.digest];
    if (entry == null || entry.path != lease.path) return;
    try {
      final now = _clock();
      await File(entry.path).setLastModified(now);
      entry.modified = now;
    } catch (_) {
      _report('touch_failed');
    }
  });

  Future<void> _release(_FileLease lease) => _ready(() async {
    if (!_leases.remove(lease)) return;
    if (identical(_writers[lease.key.digest], lease)) {
      _writers.remove(lease.key.digest);
    }
    lease.state = AudioCacheLeaseState.disposed;
    if (!_pathIsIndexed(lease.path) && !_pathIsLeased(lease.path)) {
      await _deleteSession(lease.path);
    }
    await _refreshMaterialized();
    await _evictTo(_limitBytes);
    _emit();
  });

  bool _pathIsIndexed(String path) =>
      _entries.values.any((entry) => entry.path == path);
  bool _pathIsLeasedByAnother(_FileLease owner) => _leases.any(
    (lease) => !identical(lease, owner) && lease.path == owner.path,
  );
  bool _pathIsLeased(String path) => _leases.any((lease) => lease.path == path);

  @override
  Future<void> invalidate(AudioCacheKey key) => _ready(() async {
    await _removeEntry(key.digest);
    _emit();
  });

  Future<bool> _removeEntry(String digest) async {
    final entry = _entries.remove(digest);
    if (entry == null) return true;
    var deleted = true;
    final identity = entry.metadata.key.trackIdentity;
    _trackIndex[identity]?.remove(digest);
    if (_trackIndex[identity]?.isEmpty ?? false) _trackIndex.remove(identity);
    try {
      await _deleteFile(_metadataFile(digest).path);
    } catch (_) {
      deleted = false;
      markReadUnavailable();
      _report('metadata_remove_failed');
    }
    for (final lease in _leases.where((lease) => lease.path == entry.path)) {
      lease.publication = AudioCachePublication.suppressed;
    }
    if (!_pathIsLeased(entry.path)) {
      deleted = await _deleteSession(entry.path) && deleted;
    }
    return deleted;
  }

  @override
  Future<AudioCacheClearResult> clear() => _ready(() async {
    var deleted = readHealth == AudioCacheReadHealth.ready;
    final previousGarbage = _garbage.keys.toList();
    _clearEpoch++;
    for (final lease in _leases) {
      if (lease.acquisitionEpoch >= _clearEpoch) continue;
      lease.publishSuppressed = true;
      lease.publication = AudioCachePublication.suppressed;
      if (lease.committedForPlayback) {
        lease.clearedDeferred = true;
      } else {
        lease.commitRevoked = true;
      }
    }
    for (final digest in _entries.keys.toList()) {
      deleted = await _removeEntry(digest) && deleted;
    }
    for (final path in previousGarbage) {
      if (!_pathIsLeased(path)) {
        deleted = await _deleteSession(path) && deleted;
      }
    }
    await _refreshMaterialized();
    _emit();
    // Garbage is an unsuccessful deletion, never a current-playback deferral.
    if (!deleted || _garbage.isNotEmpty) {
      throw const AudioCacheClearException();
    }
    return AudioCacheClearResult(
      hasDeferredData: _leases.any(
        (lease) => switch (lease.state) {
          AudioCacheLeaseState.pinnedData ||
          AudioCacheLeaseState.activeWrite ||
          AudioCacheLeaseState.retainedData => true,
          _ => false,
        },
      ),
    );
  });

  @override
  Future<void> setLimitBytes(int limitBytes) => _ready(() async {
    if (limitBytes <= 0) throw ArgumentError('Cache limit must be positive');
    _limitBytes = limitBytes;
    _configuredLimitBytes = limitBytes;
    await _refreshMaterialized();
    await _evictTo(limitBytes);
    _emit();
  });

  Future<void> _refreshMaterialized() async {
    for (final lease in _writers.values) {
      final finalStat = await File(lease.path).stat();
      final partStat = await File('${lease.path}.part').stat();
      lease.materializedBytes = math.max(
        finalStat.type == FileSystemEntityType.file ? finalStat.size : 0,
        partStat.type == FileSystemEntityType.file ? partStat.size : 0,
      );
    }
  }

  int get _managedBytes {
    final paths = <String, int>{..._garbage};
    for (final entry in _entries.values) {
      paths[entry.path] = entry.metadata.actualBytes;
    }
    for (final lease in _leases) {
      final bytes = lease.state == AudioCacheLeaseState.activeWrite
          ? math.max(lease.expectedBytes, lease.materializedBytes)
          : lease.materializedBytes;
      paths[lease.path] = math.max(paths[lease.path] ?? 0, bytes);
    }
    return paths.values.fold(0, (total, bytes) => total + bytes);
  }

  Future<void> _evictTo(int target) async {
    for (final path in _garbage.keys.toList()) {
      if (!_pathIsLeased(path) && !_pathIsIndexed(path)) {
        await _deleteSession(path);
      }
    }
    final candidates =
        _entries.values.where((entry) => !_pathIsLeased(entry.path)).toList()
          ..sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in candidates) {
      if (_managedBytes <= target) break;
      await _removeEntry(entry.metadata.key.digest);
    }
  }

  Future<bool> _deleteSession(String path) async {
    var remaining = 0;
    var deleted = true;
    final paths = [
      for (final suffix in ['', '.part', '.mime']) '$path$suffix',
      if (_root != null) p.join(_temp.path, '${p.basename(path)}.metadata.tmp'),
    ];
    for (final artifact in paths) {
      try {
        await _deleteFile(artifact);
      } catch (_) {
        deleted = false;
        try {
          final stat = await File(artifact).stat();
          if (stat.type == FileSystemEntityType.file) remaining += stat.size;
        } catch (_) {
          // Keep failed artifacts retryable even when their size is unknown.
        }
        _report('session_delete_failed');
      }
    }
    if (!deleted) {
      _garbage[path] = remaining;
    } else {
      _garbage.remove(path);
    }
    return deleted;
  }

  static Future<void> _deleteFileFromDisk(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else {
      throw StateError('Unexpected cache file type');
    }
  }

  static Future<void> _deleteDirectory(Directory directory) async {
    await directory.delete(recursive: true);
  }

  @override
  void markWriteUnavailable() {
    _writeFused = true;
    _emit();
  }

  @override
  void markReadUnavailable() {
    _readFused = true;
    _writeFused = true;
    _emit();
  }

  void _emit() {
    final next = AudioCacheSnapshot(
      publishedBytes: _entries.values.fold(
        0,
        (total, entry) => total + entry.metadata.actualBytes,
      ),
      managedFootprintBytes: _managedBytes,
      entryCount: _entries.length,
      activeLeaseCount: _leases.length,
      clearEpoch: _clearEpoch,
      readHealth: readHealth,
      writeHealth: writeHealth,
    );
    final old = _snapshot;
    _snapshot = next;
    if (!_snapshots.isClosed &&
        (old.publishedBytes != next.publishedBytes ||
            old.managedFootprintBytes != next.managedFootprintBytes ||
            old.entryCount != next.entryCount ||
            old.activeLeaseCount != next.activeLeaseCount ||
            old.clearEpoch != next.clearEpoch ||
            old.readHealth != next.readHealth ||
            old.writeHealth != next.writeHealth)) {
      _snapshots.add(next);
    }
  }

  /// Playback owners must release native sources separately. Closing the store
  /// fences new work but never deletes a file underneath an outstanding owner.
  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await initialize();
    await _serialize(() async {
      _emit();
    });
    await _schemaCleanup;
    await _snapshots.close();
  }
}

final class _Entry {
  _Entry(this.metadata, this.path, this.modified);
  final AudioCacheMetadata metadata;
  final String path;
  DateTime modified;
}

final class _FileLease implements AudioCacheSourceLease {
  _FileLease(
    this.store, {
    required this.key,
    required this.path,
    required this.resolvedFormat,
    required this.acquisitionEpoch,
    required this.state,
    required this.expectedBytes,
    this.materializedBytes = 0,
    this.publication = AudioCachePublication.none,
  });

  final FileAudioCacheStore store;
  @override
  final AudioCacheKey key;
  @override
  final String path;
  @override
  final String resolvedFormat;
  @override
  final int acquisitionEpoch;
  final int expectedBytes;
  int materializedBytes;
  @override
  AudioCacheLeaseState state;
  @override
  AudioCachePublication publication;
  @override
  bool committedForPlayback = false;
  @override
  int? playbackGeneration;
  @override
  bool commitRevoked = false;
  @override
  bool clearedDeferred = false;
  @override
  bool publishSuppressed = false;
  Future<void>? _disposal;

  @override
  bool get canRetainOnStop =>
      !clearedDeferred &&
      !commitRevoked &&
      publication == AudioCachePublication.published &&
      (state == AudioCacheLeaseState.pinnedData ||
          state == AudioCacheLeaseState.retainedData) &&
      store._entries[key.digest]?.path == path;
  @override
  Future<bool> commitForPlayback(int generation) =>
      store._commit(this, generation);
  @override
  Future<void> touchAfterSourceCommit() => store._touch(this);
  @override
  Future<void> dispose() => _disposal ??= store._release(this);
}
