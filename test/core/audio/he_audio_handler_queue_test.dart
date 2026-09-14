import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_audio_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeAudioTestPlatform native;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final original = JustAudioPlatform.instance;
    native = NativeAudioTestPlatform();
    JustAudioPlatform.instance = native;
    const channel = MethodChannel('com.ryanheise.audio_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() {
      JustAudioPlatform.instance = original;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  for (final removedIndex in <int>[0, 1, 3, 4]) {
    for (final playing in <bool>[true, false]) {
      test('播放第三首时删除第${removedIndex + 1}首保留音源和进度（playing=$playing）', () async {
        var loadCount = 0;
        native.beforeLoad = (_) async => loadCount++;
        final player = AudioPlayer(handleAudioSessionActivation: false);
        final handler = HeAudioHandler(player: player);
        addTearDown(handler.disposeHandler);
        final tracks = List<AudioTrack>.generate(
          5,
          (index) => AudioTrack(
            id: 'song-$index',
            title: 'Song $index',
            url: '',
            path: '/tmp/song-$index.mp3',
            platform: 'local',
          ),
        );
        await handler.setQueueData(tracks, initialIndex: 2);
        await handler.seek(const Duration(seconds: 42));
        if (playing) {
          await handler.play();
        }
        final source = player.audioSource;
        final position = player.position;
        expect(position, greaterThanOrEqualTo(const Duration(seconds: 42)));
        expect(player.playing, playing);
        expect(loadCount, 1);

        final nextQueue = [...tracks]..removeAt(removedIndex);
        final nextIndex = removedIndex < 2 ? 1 : 2;
        await handler.setQueueData(nextQueue, initialIndex: nextIndex);

        expect(loadCount, 1, reason: '删除非当前曲目不应重新装载音源');
        expect(player.audioSource, same(source));
        expect(player.position, greaterThanOrEqualTo(position));
        expect(player.playing, playing);
        expect(handler.mediaItem.value?.id, 'song-2');
        expect(handler.playbackState.value.queueIndex, nextIndex);
        expect(
          handler.queue.value.map((item) => item.id),
          nextQueue.map((track) => track.id),
        );

        // 完成事件应根据更新后的队列继续播放下一首。
        await handler.handlePlaybackCompletedForTesting();
        expect(handler.mediaItem.value?.id, nextQueue[nextIndex + 1].id);
        expect(handler.playbackState.value.queueIndex, nextIndex + 1);
        expect(loadCount, 2);

        // 显式要求重新加载时仍然装载音源。
        await handler.setQueueData(
          nextQueue,
          initialIndex: nextIndex + 1,
          forceReloadCurrent: true,
        );
        expect(loadCount, 3);
      });
    }
  }
}
