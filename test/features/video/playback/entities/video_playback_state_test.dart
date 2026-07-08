import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_playback_state.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_slot_key.dart';
import 'package:he_music_flutter/features/video/playback/entities/video_slot_state.dart';

void main() {
  test('playback state exposes empty defaults', () {
    const state = VideoPlaybackState.initial;

    expect(state.currentIndex, 0);
    expect(state.currentSlotKey, VideoSlotKey.current);
    expect(state.isSwitchingQuality, isFalse);
    expect(state.activeError, isNull);
    expect(state.currentSlot, isNull);
  });

  test('slot state carries page binding and selected quality', () {
    const state = VideoSlotState(
      slotKey: VideoSlotKey.next,
      pageIndex: 2,
      contentId: 'mv-2',
      isAttached: true,
      isInitialized: true,
      isBuffering: false,
      isPlaying: false,
      position: Duration(seconds: 4),
      duration: Duration(minutes: 1),
      aspectRatio: 4 / 3,
      selectedQualityKey: '720-mp4',
      error: null,
    );

    expect(state.slotKey, VideoSlotKey.next);
    expect(state.pageIndex, 2);
    expect(state.contentId, 'mv-2');
    expect(state.selectedQualityKey, '720-mp4');
    expect(state.aspectRatio, 4 / 3);
  });

  test('currentSlot resolves the current slot state', () {
    const current = VideoSlotState(
      slotKey: VideoSlotKey.current,
      pageIndex: 1,
      contentId: 'mv-1',
      isAttached: true,
      isInitialized: true,
      isBuffering: false,
      isPlaying: true,
      position: Duration(seconds: 5),
      duration: Duration(minutes: 2),
      aspectRatio: 16 / 9,
      selectedQualityKey: '1080-mp4',
      error: null,
    );
    const state = VideoPlaybackState(
      currentIndex: 1,
      currentSlotKey: VideoSlotKey.current,
      isSwitchingQuality: false,
      activeError: null,
      slotStates: <VideoSlotKey, VideoSlotState>{VideoSlotKey.current: current},
    );

    expect(state.currentSlot, current);
  });
}
