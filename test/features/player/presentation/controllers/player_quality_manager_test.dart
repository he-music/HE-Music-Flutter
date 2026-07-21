import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_quality_manager.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

AppConfigState _config({
  AppOnlineAudioQuality preference = AppOnlineAudioQuality.auto,
  String? lastSelectedQualityName,
}) {
  return AppConfigState(
    apiBaseUrl: 'https://api.test',
    themeMode: AppThemeMode.dark,
    themeAccent: AppThemeAccent.cobalt,
    skinId: 'classic',
    enableSkinAnimation: true,
    isMonochrome: false,
    localeCode: 'zh',
    onlineAudioQualityPreference: preference,
    autoCheckUpdates: true,
    playerStyleId: 'classic',
    lyricHighlightMode: AppLyricHighlightMode.preset,
    lyricHighlightPreset: AppLyricHighlightColor.sky,
    lyricFontPreset: AppLyricFontPreset.medium,
    enableWordByWordLyric: false,
    enableDesktopLyric: false,
    enableDesktopLyricLock: false,
    lastSelectedOnlineAudioQualityName: lastSelectedQualityName,
  );
}

const _link128 = LinkInfo(
  name: '128k',
  quality: 128,
  format: 'mp3',
  size: '3000000',
  url: 'https://cdn/128.mp3',
);
const _link320 = LinkInfo(
  name: '320k',
  quality: 320,
  format: 'mp3',
  size: '8000000',
  url: 'https://cdn/320.mp3',
);

PlayerTrack _track({
  String id = 's1',
  String title = 'Song',
  String url = 'https://cdn/song.mp3',
  String? path,
  String? platform,
  List<LinkInfo> links = const [],
}) {
  return PlayerTrack(
    id: id,
    title: title,
    url: url,
    path: path,
    platform: platform,
    links: links,
  );
}

OnlinePlatform _platform({
  required String id,
  Map<String, String> qualities = const {},
}) {
  return OnlinePlatform(
    id: id,
    name: 'Platform $id',
    shortName: id,
    status: 1,
    featureSupportFlag: BigInt.zero,
    qualities: qualities,
  );
}

void main() {
  group('PlayerQualityManager', () {
    late PlayerQualityManager manager;

    setUp(() {
      manager = PlayerQualityManager(
        platformsReader: () => [],
        configReader: _config,
      );
    });

    group('resolveAvailableQualities', () {
      test('空 links 返回空列表', () {
        final result = manager.resolveAvailableQualities(_track());
        expect(result, isEmpty);
      });

      test('正确解析 links 列表', () {
        final result = manager.resolveAvailableQualities(
          _track(links: [_link128, _link320]),
        );
        expect(result.length, 2);
        // 结果是 reversed 的
        expect(result[0].name, '320k');
        expect(result[1].name, '128k');
      });

      test('同名 link 去重（保留首次出现）', () {
        final duplicate = LinkInfo(
          name: '320k',
          quality: 320,
          format: 'mp3',
          size: '5000',
          url: 'https://cdn/dup.mp3',
        );
        final result = manager.resolveAvailableQualities(
          _track(links: [_link128, _link320, duplicate]),
        );
        // 去重后只有 2 个（reversed）
        expect(result.length, 2);
      });

      test('sizeBytes 解析正确', () {
        final result = manager.resolveAvailableQualities(
          _track(links: [_link128]),
        );
        expect(result.first.sizeBytes, 3000000);
      });

      test('无效 size 返回 null', () {
        final badSize = const LinkInfo(
          name: 'low',
          quality: 64,
          format: 'mp3',
          size: 'abc',
          url: 'https://cdn/low.mp3',
        );
        final result = manager.resolveAvailableQualities(
          _track(links: [badSize]),
        );
        expect(result.first.sizeBytes, isNull);
      });

      test('平台配置的描述被映射到 quality option', () {
        final mgr = PlayerQualityManager(
          platformsReader: () => [
            _platform(id: 'netease', qualities: {'320k': '超高音质'}),
          ],
          configReader: _config,
        );
        final result = mgr.resolveAvailableQualities(
          _track(platform: 'netease', links: [_link128, _link320]),
        );
        final q320 = result.firstWhere((q) => q.name == '320k');
        expect(q320.description, '超高音质');
      });
    });

    group('resolveSelectedQualityName', () {
      test('空列表返回 null', () {
        final result = manager.resolveSelectedQualityName(
          availableQualities: const [],
        );
        expect(result, isNull);
      });

      test('强制指定的音质优先', () {
        final qualities = manager.resolveAvailableQualities(
          _track(links: [_link128, _link320]),
        );
        final result = manager.resolveSelectedQualityName(
          availableQualities: qualities,
          forcedQualityName: '128k',
        );
        expect(result, '128k');
      });

      test('强制指定不在列表中时回退到配置偏好', () {
        final qualities = manager.resolveAvailableQualities(
          _track(links: [_link128, _link320]),
        );
        final result = manager.resolveSelectedQualityName(
          availableQualities: qualities,
          forcedQualityName: '999k',
        );
        // forced 未找到，走配置逻辑
        expect(result, isNotNull);
      });

      test('无强制时回退到首项', () {
        final qualities = manager.resolveAvailableQualities(
          _track(links: [_link128]),
        );
        final result = manager.resolveSelectedQualityName(
          availableQualities: qualities,
        );
        expect(result, '128k');
      });
    });

    group('findQualityOptionByName', () {
      test('命中返回选项', () {
        final qualities = manager.resolveAvailableQualities(
          _track(links: [_link128, _link320]),
        );
        final found = manager.findQualityOptionByName(qualities, '320k');
        expect(found, isNotNull);
        expect(found!.name, '320k');
      });

      test('未命中返回 null', () {
        final qualities = manager.resolveAvailableQualities(
          _track(links: [_link128]),
        );
        final found = manager.findQualityOptionByName(qualities, 'flac');
        expect(found, isNull);
      });
    });

    group('resolveTrackForPlayback', () {
      test('越界 index 抛出 AppException', () {
        expect(
          () => manager.resolveTrackForPlayback([_track()], 5),
          throwsA(isA<AppException>()),
        );
      });

      test('负 index 抛出 AppException', () {
        expect(
          () => manager.resolveTrackForPlayback([_track()], -1),
          throwsA(isA<AppException>()),
        );
      });

      test('有 local path 时转为 file:// URL', () async {
        final result = await manager.resolveTrackForPlayback([
          _track(path: '/music/song.mp3', platform: 'local'),
        ], 0);
        expect(result.track.url, startsWith('file:///'));
        expect(result.updatedQueue[0].url, startsWith('file:///'));
      });

      test('有 platform 时清空 url', () async {
        final result = await manager.resolveTrackForPlayback([
          _track(platform: 'netease', url: 'https://old/url.mp3'),
        ], 0);
        expect(result.track.url, isEmpty);
      });

      test('无 url 且无 platform 抛出 AppException', () {
        expect(
          () => manager.resolveTrackForPlayback([_track(url: '')], 0),
          throwsA(isA<AppException>()),
        );
      });

      test('正常在线曲目返回 resolution', () async {
        final result = await manager.resolveTrackForPlayback([
          _track(url: 'https://cdn/song.mp3'),
        ], 0);
        expect(result.track.id, 's1');
        expect(result.updatedQueue.length, 1);
      });

      test('updatedQueue 保持其他元素不变', () async {
        final queue = [_track(id: 'a'), _track(id: 'b'), _track(id: 'c')];
        final result = await manager.resolveTrackForPlayback(queue, 1);
        expect(result.updatedQueue[0].id, 'a');
        expect(result.updatedQueue[1].id, 'b');
        expect(result.updatedQueue[2].id, 'c');
      });
    });
  });
}
