import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_progress_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller_callback.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_progress_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用 ControllerCallback。
class _FakeCallback implements PlayerControllerCallback {
  PlayerPlaybackState _state = PlayerPlaybackState.initial(const []);

  @override
  PlayerPlaybackState get currentState => _state;

  @override
  void updateState(
    PlayerPlaybackState Function(PlayerPlaybackState current) updater,
  ) {
    _state = updater(_state);
  }
}

const _t1 = PlayerTrack(id: 's1', title: 'Song 1', platform: 'netease');
const _t2 = PlayerTrack(id: 's2', title: 'Song 2', platform: 'netease');

void main() {
  group('PlayerProgressManager', () {
    late PlayerProgressManager manager;
    late _FakeCallback callback;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      manager = PlayerProgressManager(
        dataSource: const PlayerProgressDataSource(),
      );
      callback = _FakeCallback();
    });

    group('persistTrackProgress', () {
      test('track 为 null 时不保存', () async {
        await manager.persistTrackProgress(
          callback: callback,
          track: null,
          position: const Duration(seconds: 10),
        );
        // 不抛异常即通过
      });

      test('position < 3s 时不保存', () async {
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 2),
        );
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, isNull);
      });

      test('接近尾部时清除进度', () async {
        // 先保存一个进度
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 10),
          force: true,
        );

        // 接近尾部（position >= duration - 2s）
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 58),
          durationOverride: const Duration(seconds: 60),
          force: true,
        );
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, isNull);
      });

      test('force=true 跳过节流直接保存', () async {
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 10),
          force: true,
        );
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, 10000);
      });

      test('正常保存和读取', () async {
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 30),
          force: true,
        );
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, 30000);
      });
    });

    group('restoreTrackProgress', () {
      test('无已存进度返回 null', () async {
        final result = await manager.restoreTrackProgress(
          callback: callback,
          track: _t1,
          currentDuration: const Duration(seconds: 60),
        );
        expect(result, isNull);
      });

      test('已存进度 < 3s 返回 null', () async {
        final ds = const PlayerProgressDataSource();
        await ds.saveProgress(track: _t1, positionMs: 2000);

        final result = await manager.restoreTrackProgress(
          callback: callback,
          track: _t1,
          currentDuration: const Duration(seconds: 60),
        );
        expect(result, isNull);
      });

      test('接近尾部时清除并返回 null', () async {
        final ds = const PlayerProgressDataSource();
        await ds.saveProgress(track: _t1, positionMs: 59000);

        final result = await manager.restoreTrackProgress(
          callback: callback,
          track: _t1,
          currentDuration: const Duration(seconds: 60),
        );
        expect(result, isNull);
        // 进度应被清除
        final saved = await ds.readProgress(_t1);
        expect(saved, isNull);
      });

      test('正常范围返回 Duration', () async {
        final ds = const PlayerProgressDataSource();
        await ds.saveProgress(track: _t1, positionMs: 30000);

        final result = await manager.restoreTrackProgress(
          callback: callback,
          track: _t1,
          currentDuration: const Duration(seconds: 60),
        );
        expect(result, const Duration(milliseconds: 30000));
      });
    });

    group('resetThrottle', () {
      test('重置后新保存不受节流限制', () async {
        // 先保存一次
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 10),
          force: true,
        );

        // 重置节流
        manager.resetThrottle();

        // 立即再次保存应成功（force=false 但节流已重置）
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 15),
        );
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, 15000);
      });
    });

    group('onPositionUpdateFromStream', () {
      test('isPlaying=false 时不保存', () async {
        manager.onPositionUpdateFromStream(
          callback: callback,
          currentTrack: _t1,
          position: const Duration(seconds: 10),
          isPlaying: false,
        );
        // 给 unawaited 一个完成的机会
        await Future<void>.delayed(Duration.zero);
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, isNull);
      });

      test('isPlaying=true 时触发保存', () async {
        // force 先保存一次以跳过 minPositionMs 限制
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 5),
          force: true,
        );

        manager.onPositionUpdateFromStream(
          callback: callback,
          currentTrack: _t1,
          position: const Duration(seconds: 10),
          isPlaying: true,
        );
        // unawaited 需要微任务完成
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final saved = await const PlayerProgressDataSource().readProgress(_t1);
        expect(saved, 10000);
      });
    });

    group('切歌重置节流', () {
      test('不同 track 的保存不受前一首的节流影响', () async {
        // 保存 t1
        await manager.persistTrackProgress(
          callback: callback,
          track: _t1,
          position: const Duration(seconds: 10),
          force: true,
        );

        // 立即保存 t2 应成功（不同 trackKey，节流不生效）
        await manager.persistTrackProgress(
          callback: callback,
          track: _t2,
          position: const Duration(seconds: 20),
        );

        final saved1 = await const PlayerProgressDataSource().readProgress(_t1);
        final saved2 = await const PlayerProgressDataSource().readProgress(_t2);
        expect(saved1, 10000);
        expect(saved2, 20000);
      });
    });
  });
}
