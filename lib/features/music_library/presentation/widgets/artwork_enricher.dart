import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

/// 为歌曲列表异步加载封面字节的包装器
///
/// 详情页从 DB 流获取的歌曲不含 [LocalSong.artworkBytes]，
/// 此组件从磁盘缓存中读取封面并回填，完成后调用 [builder] 重建 UI。
class ArtworkEnricher extends ConsumerStatefulWidget {
  const ArtworkEnricher({
    required this.songs,
    required this.builder,
    super.key,
  });

  final List<LocalSong> songs;
  final Widget Function(BuildContext context, List<LocalSong> songs) builder;

  @override
  ConsumerState<ArtworkEnricher> createState() => _ArtworkEnricherState();
}

class _ArtworkEnricherState extends ConsumerState<ArtworkEnricher> {
  List<LocalSong>? _enriched;
  int _loadGeneration = 0;

  @override
  void didUpdateWidget(covariant ArtworkEnricher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.songs, widget.songs)) {
      return;
    }
    final generation = ++_loadGeneration;
    if (_enriched != null &&
        _sameArtworkInputs(oldWidget.songs, widget.songs)) {
      _enriched = _mergeLoadedArtwork(widget.songs);
      return;
    }
    _enriched = null;
    unawaited(_loadArtwork(generation));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadArtwork(++_loadGeneration));
  }

  Future<void> _loadArtwork(int generation) async {
    final songs = widget.songs;
    if (songs.isEmpty) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _enriched = songs);
      }
      return;
    }

    final toLoad = songs
        .where((s) => s.hasArtwork && s.artworkBytes == null)
        .toList();
    if (toLoad.isEmpty) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _enriched = songs);
      }
      return;
    }

    final extractor = ref.read(localArtworkExtractorProvider);
    final enriched = List<LocalSong>.from(songs);
    final indexById = <String, int>{};
    for (var index = 0; index < enriched.length; index++) {
      indexById.putIfAbsent(enriched[index].id, () => index);
    }
    var nextIndex = 0;
    var changed = false;

    // 磁盘读取受限于 I/O，使用小并发池缩短首屏等待，避免一次性创建过多任务。
    Future<void> worker() async {
      while (true) {
        if (!mounted || generation != _loadGeneration) return;
        final index = nextIndex++;
        if (index >= toLoad.length) return;
        final song = toLoad[index];
        try {
          final bytes = await extractor.getArtworkBytes(song.filePath);
          if (!mounted || generation != _loadGeneration) return;
          if (bytes == null || bytes.isEmpty) continue;
          final enrichedIndex = indexById[song.id];
          if (enrichedIndex == null) continue;
          enriched[enrichedIndex] = song.copyWith(
            artworkBytes: Uint8List.fromList(bytes),
          );
          changed = true;
        } catch (_) {
          // 单个封面读取失败不影响其余歌曲。
        }
      }
    }

    final workerCount = toLoad.length < 3 ? toLoad.length : 3;
    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    if (!mounted || generation != _loadGeneration) return;
    if (changed || _enriched == null) {
      setState(() => _enriched = enriched);
    }
  }

  bool _sameArtworkInputs(List<LocalSong> previous, List<LocalSong> next) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final oldSong = previous[index];
      final newSong = next[index];
      if (oldSong.id != newSong.id ||
          oldSong.filePath != newSong.filePath ||
          oldSong.hasArtwork != newSong.hasArtwork ||
          (oldSong.artworkBytes == null) != (newSong.artworkBytes == null)) {
        return false;
      }
    }
    return true;
  }

  List<LocalSong> _mergeLoadedArtwork(List<LocalSong> songs) {
    final previous = <String, Uint8List>{
      for (final song in _enriched ?? const <LocalSong>[])
        if (song.artworkBytes != null) song.id: song.artworkBytes!,
    };
    return songs
        .map(
          (song) =>
              song.artworkBytes == null &&
                  song.hasArtwork &&
                  previous[song.id] != null
              ? song.copyWith(artworkBytes: previous[song.id])
              : song,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final songs = _enriched ?? widget.songs;
    return widget.builder(context, songs);
  }
}
