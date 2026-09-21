import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_control_bar.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_fullscreen_lyrics_bar.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_progress_bar.dart';

class _FakePlayerController extends PlayerController {
  _FakePlayerController({PlayerPlaybackState? initialState})
    : _initialState = initialState;

  final PlayerPlaybackState? _initialState;
  int togglePlayPauseCalls = 0;
  int playNextCalls = 0;
  int playPreviousCalls = 0;
  int cyclePlayModeCalls = 0;
  Duration? lastSeekPosition;

  @override
  PlayerPlaybackState build() {
    return _initialState ??
        PlayerPlaybackState.initial(const <PlayerTrack>[
          PlayerTrack(id: 'song-1', title: '歌曲标题 1', artist: '歌手 1'),
          PlayerTrack(id: 'song-2', title: '歌曲标题 2', artist: '歌手 2'),
        ]).copyWith(
          currentIndex: 0,
          duration: const Duration(seconds: 240),
          position: Duration.zero,
        );
  }

  void updateProgress({
    required Duration position,
    Duration? bufferedPosition,
  }) {
    state = state.copyWith(
      position: position,
      bufferedPosition: bufferedPosition ?? state.bufferedPosition,
    );
  }

  void updateTrack(PlayerTrack track) {
    state = state.copyWith(queue: <PlayerTrack>[track], currentIndex: 0);
  }

  void updatePlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  void updatePlayMode(PlayerPlayMode mode) {
    state = state.copyWith(playMode: mode);
  }

  void updateRadioMode(bool isRadio) {
    state = state.copyWith(isRadioMode: isRadio);
  }

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalls++;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  Future<void> playNext() async {
    playNextCalls++;
  }

  @override
  Future<void> playPrevious() async {
    playPreviousCalls++;
  }

  @override
  Future<void> cyclePlayMode() async {
    cyclePlayModeCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeekPosition = position;
    state = state.copyWith(position: position);
  }
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh-CN');
  }
}

Widget _buildTestApp({
  required _FakePlayerController controller,
  VoidCallback? onOpenMore,
  VoidCallback? onOpenQueue,
  VoidCallback? debugOnBuild,
}) {
  return ProviderScope(
    overrides: [
      playerControllerProvider.overrideWith(() => controller),
      appConfigProvider.overrideWith(_TestAppConfigController.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PlayerFullscreenLyricsBar(
          controller: controller,
          noTrackText: '暂无播放歌曲',
          onOpenMore: onOpenMore ?? () {},
          onOpenQueue: onOpenQueue ?? () {},
          debugOnBuild: debugOnBuild,
        ),
      ),
    ),
  );
}

void main() {
  group('PlayerFullscreenLyricsBar 无效重建防护验证', () {
    testWidgets('高频播放进度更新时只重建进度条，不触发控制栏及曲目信息重建', (tester) async {
      final controller = _FakePlayerController();
      int lyricsBarBuildCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          controller: controller,
          debugOnBuild: () => lyricsBarBuildCount++,
        ),
      );
      await tester.pump();

      expect(lyricsBarBuildCount, 1);
      expect(find.text('歌曲标题 1'), findsOneWidget);
      expect(find.text('歌手 1'), findsOneWidget);

      // 模拟音频播放时的高频进度变化 (例如 10 次毫秒级 tick)
      for (int i = 1; i <= 10; i++) {
        controller.updateProgress(
          position: Duration(seconds: i * 2),
          bufferedPosition: Duration(seconds: i * 3),
        );
        await tester.pump();
      }

      // 验收标准：高频进度状态下沉至独立组件，外层控制栏 0 次无效重建
      expect(
        lyricsBarBuildCount,
        1,
        reason: '高频 position 变动不应触发 PlayerFullscreenLyricsBar 重新 build',
      );

      // 验证 PlayerProgressBar 的值确实正确更新
      final progressBar = tester.widget<PlayerProgressBar>(
        find.byType(PlayerProgressBar),
      );
      expect(progressBar.position, const Duration(seconds: 20));
      expect(progressBar.bufferedPosition, const Duration(seconds: 30));
    });

    testWidgets('必要业务状态变化仍正常更新', (tester) async {
      final controller = _FakePlayerController();
      int lyricsBarBuildCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          controller: controller,
          debugOnBuild: () => lyricsBarBuildCount++,
        ),
      );
      await tester.pump();
      expect(lyricsBarBuildCount, 1);

      // 1. 切歌 (displayTrack 变化) -> 正常更新曲目信息与控制条
      controller.updateTrack(
        const PlayerTrack(id: 'song-new', title: '崭新歌曲', artist: '新锐歌手'),
      );
      await tester.pump();

      expect(lyricsBarBuildCount, 2);
      expect(find.text('崭新歌曲'), findsOneWidget);
      expect(find.text('新锐歌手'), findsOneWidget);

      // 2. 播放状态变化 (isPlaying 变化) -> 正常更新播放/暂停按钮图标
      expect(controller.state.isPlaying, isFalse);
      controller.updatePlaying(true);
      await tester.pump();

      expect(lyricsBarBuildCount, 3);
      final controlBar = tester.widget<PlayerControlBar>(
        find.byType(PlayerControlBar),
      );
      expect(controlBar.isPlaying, isTrue);

      // 3. 循环模式变化 (playMode 变化) -> 正常传递给控制栏
      controller.updatePlayMode(PlayerPlayMode.single);
      await tester.pump();

      expect(lyricsBarBuildCount, 4);
      final controlBar2 = tester.widget<PlayerControlBar>(
        find.byType(PlayerControlBar),
      );
      expect(controlBar2.playMode, PlayerPlayMode.single);

      // 4. 电台模式切换 (isRadioMode 变化) -> 隐藏循环模式和队列按钮
      controller.updateRadioMode(true);
      await tester.pump();

      expect(lyricsBarBuildCount, 5);
      final controlBar3 = tester.widget<PlayerControlBar>(
        find.byType(PlayerControlBar),
      );
      expect(controlBar3.showPlayModeButton, isFalse);
      expect(controlBar3.showQueueButton, isFalse);
    });

    testWidgets('交互事件（播放、切歌、弹窗回调等）正常响应', (tester) async {
      final controller = _FakePlayerController();
      bool moreOpened = false;
      bool queueOpened = false;

      await tester.pumpWidget(
        _buildTestApp(
          controller: controller,
          onOpenMore: () => moreOpened = true,
          onOpenQueue: () => queueOpened = true,
        ),
      );
      await tester.pump();

      // 点击播放/暂停
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(controller.togglePlayPauseCalls, 1);

      // 点击下一曲
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();
      expect(controller.playNextCalls, 1);

      // 点击上一曲
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();
      expect(controller.playPreviousCalls, 1);

      // 点击更多按钮
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump();
      expect(moreOpened, isTrue);

      // 点击队列按钮
      await tester.tap(find.byIcon(Icons.queue_music_rounded));
      await tester.pump();
      expect(queueOpened, isTrue);
    });
  });
}
