import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_link.dart';
import '../entities/video_playback_state.dart';
import '../entities/video_playback_surface.dart';
import '../entities/video_slot_key.dart';
import '../entities/video_slot_state.dart';
import '../providers/video_playback_surface_provider.dart';

typedef VideoPlaybackUriBuilder =
    Uri Function(VideoDetailContent content, VideoDetailLink link);

class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController({
    required VideoPlaybackSurfaceFactory surfaceFactory,
    required VideoPlaybackUriBuilder uriBuilder,
  }) : _surfaceFactory = surfaceFactory,
       _uriBuilder = uriBuilder;

  final VideoPlaybackSurfaceFactory _surfaceFactory;
  final VideoPlaybackUriBuilder _uriBuilder;
  final Map<int, _VideoPlaybackSlot> _slots = <int, _VideoPlaybackSlot>{};
  final Map<VideoPlaybackSurface, VoidCallback> _surfaceListeners =
      <VideoPlaybackSurface, VoidCallback>{};

  final Map<int, VideoDetailContent> _contents = <int, VideoDetailContent>{};
  VideoPlaybackState _state = VideoPlaybackState.initial;

  VideoPlaybackState get state => _state;

  VideoPlaybackSurface? get currentSurface =>
      surfaceForPage(_state.currentIndex);

  Future<void> initialize({
    required List<VideoDetailContent> contents,
    required int initialIndex,
  }) async {
    await disposeSessions();
    _contents
      ..clear()
      ..addEntries(
        contents.indexed.map(
          (entry) => MapEntry<int, VideoDetailContent>(entry.$1, entry.$2),
        ),
      );
    _state = VideoPlaybackState.initial.copyWith(currentIndex: initialIndex);
    await _ensurePageSession(initialIndex, autoplay: true);
    await _ensurePageSession(initialIndex - 1, autoplay: false);
    await _ensurePageSession(initialIndex + 1, autoplay: false);
    _syncState();
  }

  Future<void> updateContent({
    required int pageIndex,
    required VideoDetailContent content,
    bool autoplay = false,
  }) async {
    if (pageIndex < 0) return;
    _contents[pageIndex] = content;
    await _ensurePageSession(
      pageIndex,
      autoplay: autoplay && pageIndex == _state.currentIndex,
    );
    _syncState();
  }

  Future<void> onPageChanged(int index) async {
    final oldSurface = currentSurface;
    if (oldSurface?.state.isInitialized ?? false) {
      await oldSurface!.pause();
    }

    _state = _state.copyWith(currentIndex: index);
    await _ensurePageSession(index, autoplay: false);
    await _ensurePageSession(index - 1, autoplay: false);
    await _ensurePageSession(index + 1, autoplay: false);
    await _disposeDistantSessions(index);

    final nextSurface = currentSurface;
    if (nextSurface?.state.isInitialized ?? false) {
      await nextSurface!.play();
    }
    _syncState();
  }

  Future<void> playCurrent() async {
    final surface = currentSurface;
    if (surface?.state.isInitialized ?? false) {
      await surface!.play();
    }
  }

  Future<void> pauseCurrent() async {
    final surface = currentSurface;
    if (surface?.state.isInitialized ?? false) {
      await surface!.pause();
    }
  }

  Future<void> togglePlayPause() async {
    final surface = currentSurface;
    if (surface == null || !surface.state.isInitialized) return;
    if (surface.state.isPlaying) {
      await surface.pause();
    } else {
      await surface.play();
    }
  }

  Future<void> seekCurrent(Duration position) async {
    final surface = currentSurface;
    if (surface?.state.isInitialized ?? false) {
      await surface!.seekTo(position);
    }
  }

  Future<void> switchQuality(VideoDetailLink link) async {
    final pageIndex = _state.currentIndex;
    final slot = _slots[pageIndex];
    if (slot == null) return;

    final oldSurface = slot.surface;
    final position = oldSurface.state.position;
    final wasPlaying = oldSurface.state.isPlaying;
    _state = _state.copyWith(isSwitchingQuality: true);
    notifyListeners();

    try {
      final surface = await _surfaceFactory.create(
        uri: _uriBuilder(slot.content, link),
        autoplay: wasPlaying,
        initialPosition: position,
      );
      if (surface.state.hasError) {
        await surface.disposeSurface();
        throw StateError('video quality switch failed');
      }
      _removeSurfaceListener(oldSurface);
      await oldSurface.disposeSurface();
      _slots[pageIndex] = _VideoPlaybackSlot(
        pageIndex: pageIndex,
        content: slot.content,
        selectedLink: link,
        surface: surface,
      );
      _addSurfaceListener(surface);
      _state = _state.copyWith(isSwitchingQuality: false);
      _syncState();
    } catch (error) {
      _state = _state.copyWith(isSwitchingQuality: false, activeError: error);
      notifyListeners();
    }
  }

  VideoPlaybackSurface? surfaceForPage(int pageIndex) {
    return _slots[pageIndex]?.surface;
  }

  Future<void> disposeSessions() async {
    final surfaces = _slots.values
        .map((slot) => slot.surface)
        .toList(growable: false);
    _slots.clear();
    for (final surface in surfaces) {
      _removeSurfaceListener(surface);
      await surface.disposeSurface();
    }
    _syncState();
  }

  @override
  void dispose() {
    final surfaces = _slots.values
        .map((slot) => slot.surface)
        .toList(growable: false);
    _slots.clear();
    for (final surface in surfaces) {
      _removeSurfaceListener(surface);
      unawaited(surface.disposeSurface());
    }
    super.dispose();
  }

  Future<void> _ensurePageSession(
    int pageIndex, {
    required bool autoplay,
  }) async {
    if (pageIndex < 0) return;
    if (_slots.containsKey(pageIndex)) return;

    final content = _contents[pageIndex];
    if (content == null) return;
    final link = _selectedLink(content);
    if (link == null) return;

    final surface = await _surfaceFactory.create(
      uri: _uriBuilder(content, link),
      autoplay: autoplay,
    );
    if (surface.state.hasError) {
      await surface.disposeSurface();
      throw StateError('video session failed');
    }
    _slots[pageIndex] = _VideoPlaybackSlot(
      pageIndex: pageIndex,
      content: content,
      selectedLink: link,
      surface: surface,
    );
    _addSurfaceListener(surface);
  }

  Future<void> _disposeDistantSessions(int currentIndex) async {
    final pageIndexes = _slots.keys.toList(growable: false);
    for (final pageIndex in pageIndexes) {
      if ((pageIndex - currentIndex).abs() <= 1) continue;
      final slot = _slots.remove(pageIndex);
      if (slot == null) continue;
      _removeSurfaceListener(slot.surface);
      await slot.surface.disposeSurface();
    }
  }

  void _addSurfaceListener(VideoPlaybackSurface surface) {
    final listener = _syncState;
    _surfaceListeners[surface] = listener;
    surface.addListener(listener);
  }

  void _removeSurfaceListener(VideoPlaybackSurface surface) {
    final listener = _surfaceListeners.remove(surface);
    if (listener == null) return;
    surface.removeListener(listener);
  }

  VideoDetailLink? _selectedLink(VideoDetailContent content) {
    if (content.links.isEmpty) return null;
    final links = <VideoDetailLink>[...content.links]
      ..sort((a, b) => b.quality.compareTo(a.quality));
    return links.first;
  }

  void _syncState() {
    final slotStates = <VideoSlotKey, VideoSlotState>{};
    for (final slot in _slots.values) {
      final slotKey = _slotKeyForPage(slot.pageIndex);
      if (slotKey == null) continue;
      final surfaceState = slot.surface.state;
      slotStates[slotKey] = VideoSlotState(
        slotKey: slotKey,
        pageIndex: slot.pageIndex,
        contentId: slot.content.id,
        isAttached: true,
        isInitialized: surfaceState.isInitialized,
        isBuffering: surfaceState.isBuffering,
        isPlaying: surfaceState.isPlaying,
        position: surfaceState.position,
        duration: surfaceState.duration,
        aspectRatio: surfaceState.aspectRatio,
        selectedQualityKey: slot.selectedLink.cacheKey,
        error: surfaceState.hasError ? slot.content.id : null,
      );
    }
    _state = _state.copyWith(
      currentSlotKey: VideoSlotKey.current,
      slotStates: slotStates,
    );
    notifyListeners();
  }

  VideoSlotKey? _slotKeyForPage(int pageIndex) {
    final distance = pageIndex - _state.currentIndex;
    return switch (distance) {
      -1 => VideoSlotKey.previous,
      0 => VideoSlotKey.current,
      1 => VideoSlotKey.next,
      _ => null,
    };
  }
}

class _VideoPlaybackSlot {
  const _VideoPlaybackSlot({
    required this.pageIndex,
    required this.content,
    required this.selectedLink,
    required this.surface,
  });

  final int pageIndex;
  final VideoDetailContent content;
  final VideoDetailLink selectedLink;
  final VideoPlaybackSurface surface;
}
