import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_player_port.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';

void main() {
  test('currentLyricStoreProvider 应先读取后台歌词快照', () async {
    final audioPlayer = _FakeAudioPlayerPort();
    audioPlayer.currentLyricState = const CurrentLyricStateSnapshot(
      request: LyricRequest(trackId: 'song-1', platform: 'qq'),
      document: LyricDocument(
        lines: <LyricLine>[
          LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: '第一首歌词',
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [audioPlayerPortProvider.overrideWithValue(audioPlayer)],
    );
    addTearDown(container.dispose);

    final state = await container.read(currentLyricStoreProvider.future);
    expect(state.request?.trackId, 'song-1');
    expect(state.document.requireValue.lines.single.text, '第一首歌词');
    expect(audioPlayer.getCurrentLyricStateCallCount, 1);
  });

  test('currentLyricStoreProvider 收到通知后应重新拉取后台最新歌词快照', () async {
    final audioPlayer = _FakeAudioPlayerPort();
    final container = ProviderContainer(
      overrides: [audioPlayerPortProvider.overrideWithValue(audioPlayer)],
    );
    addTearDown(container.dispose);

    final completer = Completer<CurrentLyricStoreState>();
    final subscription = container.listen<AsyncValue<CurrentLyricStoreState>>(
      currentLyricStoreProvider,
      (_, next) {
        final state = next.value;
        if (state?.request?.trackId == 'song-2' && !completer.isCompleted) {
          completer.complete(state);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(currentLyricStoreProvider.future);

    audioPlayer.currentLyricState = const CurrentLyricStateSnapshot(
      request: LyricRequest(trackId: 'song-2', platform: 'qq'),
      document: LyricDocument(
        lines: <LyricLine>[
          LyricLine(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: '后台切歌后的歌词',
          ),
        ],
      ),
    );
    audioPlayer.emitCustomEvent(<String, dynamic>{'type': 'lyricState'});

    final state = await completer.future;
    expect(state.request?.trackId, 'song-2');
    expect(state.document.requireValue.lines.single.text, '后台切歌后的歌词');
    expect(audioPlayer.getCurrentLyricStateCallCount, 2);
  });
  test(
    'currentLyricStoreProvider ignores an older snapshot after a newer track',
    () async {
      final audioPlayer = _FakeAudioPlayerPort();
      audioPlayer.currentLyricState = const CurrentLyricStateSnapshot(
        request: LyricRequest(trackId: 'track-a', platform: 'qq'),
        document: LyricDocument(
          lines: <LyricLine>[LyricLine(start: Duration.zero, text: '旧曲歌词')],
        ),
      );
      final container = ProviderContainer(
        overrides: [audioPlayerPortProvider.overrideWithValue(audioPlayer)],
      );
      addTearDown(container.dispose);
      await container.read(currentLyricStoreProvider.future);

      final older = Completer<CurrentLyricStateSnapshot>();
      final newer = Completer<CurrentLyricStateSnapshot>();
      audioPlayer.pendingSnapshots.addAll(
        <Completer<CurrentLyricStateSnapshot>>[older, newer],
      );

      audioPlayer.emitCustomEvent(<String, dynamic>{'type': 'lyricState'});
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(currentLyricDocumentProvider),
        isA<AsyncLoading<LyricDocument>>(),
      );
      audioPlayer.emitCustomEvent(<String, dynamic>{'type': 'lyricState'});
      await Future<void>.delayed(Duration.zero);
      expect(audioPlayer.getCurrentLyricStateCallCount, 3);

      newer.complete(
        const CurrentLyricStateSnapshot(
          request: LyricRequest(trackId: 'track-c', platform: 'qq'),
          document: LyricDocument(
            lines: <LyricLine>[LyricLine(start: Duration.zero, text: '新曲歌词')],
          ),
        ),
      );
      final latestState = await container.read(
        currentLyricStoreProvider.future,
      );
      expect(latestState.request?.trackId, 'track-c');
      expect(latestState.document.requireValue.lines.single.text, '新曲歌词');

      older.complete(
        const CurrentLyricStateSnapshot(
          request: LyricRequest(trackId: 'track-b', platform: 'qq'),
          document: LyricDocument(
            lines: <LyricLine>[LyricLine(start: Duration.zero, text: '过期歌词')],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final finalState = container.read(currentLyricStoreProvider).requireValue;
      expect(finalState.request?.trackId, 'track-c');
      expect(finalState.document.requireValue.lines.single.text, '新曲歌词');
    },
  );
}

class _FakeAudioPlayerPort implements AudioPlayerPort {
  final StreamController<dynamic> _customEventController =
      StreamController<dynamic>.broadcast();
  CurrentLyricStateSnapshot currentLyricState =
      const CurrentLyricStateSnapshot();
  int getCurrentLyricStateCallCount = 0;

  final List<Completer<CurrentLyricStateSnapshot>> pendingSnapshots =
      <Completer<CurrentLyricStateSnapshot>>[];
  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get loadingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<int?> get currentIndexStream => const Stream<int?>.empty();

  @override
  Stream<dynamic> get customEventStream => _customEventController.stream;

  @override
  Future<CurrentLyricStateSnapshot> getCurrentLyricState() {
    getCurrentLyricStateCallCount += 1;
    if (pendingSnapshots.isNotEmpty) {
      return pendingSnapshots.removeAt(0).future;
    }
    return Future<CurrentLyricStateSnapshot>.value(currentLyricState);
  }

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {}

  @override
  Future<void> setSource(AudioTrack track, {String? forcedQualityName}) async {}

  @override
  Future<void> playAt(int index) async {}

  @override
  Future<void> seekToNext() async {}

  @override
  Future<void> seekToPrevious() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setSingleLoop(bool enabled) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> dispose() async {
    await _customEventController.close();
  }

  void emitCustomEvent(Map<String, dynamic> event) {
    _customEventController.add(event);
  }
}
