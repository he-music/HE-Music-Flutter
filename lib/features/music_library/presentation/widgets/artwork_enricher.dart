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
  bool _loading = false;

  @override
  void didUpdateWidget(covariant ArtworkEnricher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.songs, widget.songs)) {
      _enriched = null;
      _loadArtwork();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    final songs = widget.songs;
    if (songs.isEmpty) return;

    final toLoad = songs
        .where((s) => s.hasArtwork && s.artworkBytes == null)
        .toList();
    if (toLoad.isEmpty) {
      if (mounted) setState(() => _enriched = songs);
      return;
    }

    if (_loading) return;
    _loading = true;

    try {
      final extractor = ref.read(localArtworkExtractorProvider);
      final enriched = List<LocalSong>.from(songs);
      var changed = false;

      for (var i = 0; i < toLoad.length; i++) {
        if (!mounted) return;
        final song = toLoad[i];
        final bytes = await extractor.getArtworkBytes(song.filePath);
        if (bytes != null && bytes.isNotEmpty) {
          final idx = enriched.indexWhere((s) => s.id == song.id);
          if (idx != -1) {
            enriched[idx] = song.copyWith(
              artworkBytes: Uint8List.fromList(bytes),
            );
            changed = true;
          }
        }
      }

      if (mounted && changed) {
        setState(() => _enriched = enriched);
      } else if (mounted && _enriched == null) {
        setState(() => _enriched = songs);
      }
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _enriched ?? widget.songs;
    return widget.builder(context, songs);
  }
}
