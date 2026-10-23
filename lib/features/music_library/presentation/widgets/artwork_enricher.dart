import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

/// Loads cached artwork with bounded concurrency and publishes completed reads
/// together each frame, without waiting for the rest of the song list.
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
  final _loadedArtwork = <(String, String), Uint8List>{};
  List<LocalSong>? _enriched;
  int _loadGeneration = 0;
  int? _publishCallbackId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadArtwork(++_loadGeneration));
  }

  @override
  void didUpdateWidget(covariant ArtworkEnricher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.songs, widget.songs)) return;

    final artworkInputsChanged = !_sameArtworkInputs(
      oldWidget.songs,
      widget.songs,
    );
    if (artworkInputsChanged) {
      final retained = {
        for (final song in widget.songs)
          if (song.hasArtwork && song.artworkBytes == null)
            (song.id, song.filePath),
      };
      _loadedArtwork.removeWhere((key, _) => !retained.contains(key));
    }
    // Always merge onto the latest metadata, including while reads are pending.
    _enriched = _mergeLoadedArtwork();
    if (artworkInputsChanged) {
      unawaited(_loadArtwork(++_loadGeneration));
    }
  }

  Future<void> _loadArtwork(int generation) async {
    final toLoad = widget.songs
        .where(
          (song) =>
              song.hasArtwork &&
              song.artworkBytes == null &&
              !_loadedArtwork.containsKey((song.id, song.filePath)),
        )
        .toList();
    if (toLoad.isEmpty) return;

    final extractor = ref.read(localArtworkExtractorProvider);
    var nextIndex = 0;
    Future<void> worker() async {
      while (mounted && generation == _loadGeneration) {
        final index = nextIndex++;
        if (index >= toLoad.length) return;
        final song = toLoad[index];
        try {
          final bytes = await extractor.getArtworkBytes(song.filePath);
          if (!mounted || generation != _loadGeneration) return;
          if (bytes == null || bytes.isEmpty) continue;
          _loadedArtwork[(song.id, song.filePath)] = Uint8List.fromList(bytes);
          _schedulePublish();
        } catch (_) {
          // One unreadable cover must not block the rest of the list.
        }
      }
    }

    final workerCount = toLoad.length < 3 ? toLoad.length : 3;
    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
  }

  void _schedulePublish() {
    _publishCallbackId ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
      _publishCallbackId = null;
      if (!mounted) return;
      setState(() => _enriched = _mergeLoadedArtwork());
    });
  }

  List<LocalSong> _mergeLoadedArtwork() => widget.songs
      .map((song) {
        final bytes = _loadedArtwork[(song.id, song.filePath)];
        return song.artworkBytes == null && song.hasArtwork && bytes != null
            ? song.copyWith(artworkBytes: bytes)
            : song;
      })
      .toList(growable: false);

  bool _sameArtworkInputs(List<LocalSong> previous, List<LocalSong> next) {
    if (previous.length != next.length) return false;
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

  @override
  void dispose() {
    final callbackId = _publishCallbackId;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _enriched ?? widget.songs);
}
