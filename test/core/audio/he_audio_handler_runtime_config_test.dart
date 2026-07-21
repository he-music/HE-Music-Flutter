import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/token_refresh_interceptor.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics_overlay/data/overlay_message.dart';
import 'package:he_music_flutter/features/lyrics_overlay/domain/services/overlay_channel_service.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    globalTokenHolder
      ..accessToken = null
      ..refreshToken = null
      ..expiresAt = null;
  });

  test(
    'loadHeAudioHandlerRuntimeConfig should restore persisted playback config',
    () async {
      const dataSource = AppConfigDataSource();
      await dataSource.save(
        (await dataSource.load()).copyWith(
          apiBaseUrl: 'https://example.com/',
          authToken: 'token-123',
          refreshToken: 'refresh-123',
          tokenExpiresAt: 123,
          onlineAudioQualityPreference: AppOnlineAudioQuality.flac,
          lastSelectedOnlineAudioQualityName: 'FLAC',
        ),
      );

      final config = await loadHeAudioHandlerRuntimeConfig(
        dataSource: dataSource,
      );

      expect(config.apiBaseUrl, AppEnvironment.apiBaseUrl);
      expect(config.authToken, 'token-123');
      expect(config.refreshToken, 'refresh-123');
      expect(config.tokenExpiresAt, 123);
      expect(config.qualityPreference, AppOnlineAudioQuality.flac);
      expect(config.lastSelectedQualityName, 'FLAC');
    },
  );

  test('切歌时 song url 401 应刷新 token 并重放原请求', () async {
    HttpOverrides.global = null;
    final server = await _AudioRefreshTestServer.start();
    addTearDown(server.close);
    globalTokenHolder
      ..accessToken = 'expired-token'
      ..refreshToken = 'refresh-token'
      ..expiresAt = 1;
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchLyricsOverride:
          ({
            required String trackId,
            String? platform,
            String? localPath,
          }) async => const LyricDocument.empty(),
      setAudioSourceOverride: (source, player) async {
        loadedUrls.add((source as UriAudioSource).uri.toString());
        return null;
      },
      playOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: server.baseUrl,
      authToken: 'expired-token',
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '歌曲一', url: '', platform: 'qq'),
    ]);

    expect(server.refreshRequestCount, 1);
    expect(server.songUrlAuthorizations, <String>[
      'Bearer expired-token',
      'Bearer fresh-token',
    ]);
    expect(loadedUrls, <String>['https://audio.example.com/song-1.mp3']);
    expect(globalTokenHolder.accessToken, 'fresh-token');
    expect(globalTokenHolder.refreshToken, 'fresh-refresh-token');
    expect(globalTokenHolder.expiresAt, 123);
    final persisted = await const AppConfigDataSource().load();
    expect(persisted.authToken, 'fresh-token');
    expect(persisted.refreshToken, 'fresh-refresh-token');
    expect(persisted.tokenExpiresAt, 123);

    // Riverpod/播放器可能仍持有旧快照，后续配置同步不能覆盖实时 token。
    await handler.syncConfig(
      apiBaseUrl: server.baseUrl,
      authToken: 'expired-token',
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );
    expect(globalTokenHolder.accessToken, 'fresh-token');
  });

  test('shouldRefreshRemotePlaybackUrl returns true for remote tracks', () {
    const track = AudioTrack(
      id: '1',
      title: 'Remote',
      url: 'https://cdn.example.com/audio.mp3',
      platform: 'netease',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isTrue);
  });

  test('shouldRefreshRemotePlaybackUrl returns false for local file path', () {
    const track = AudioTrack(
      id: '2',
      title: 'Local',
      url: '',
      path: '/tmp/demo.mp3',
      platform: 'local',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isFalse);
  });

  test('shouldRefreshRemotePlaybackUrl returns false for file scheme url', () {
    const track = AudioTrack(
      id: '3',
      title: 'LocalUrl',
      url: 'file:///tmp/demo.mp3',
    );

    expect(shouldRefreshRemotePlaybackUrl(track), isFalse);
  });

  test('自动歌词颜色只同步到对应的当前歌曲', () async {
    final overlayService = _RecordingOverlayChannelService();
    final handler = HeAudioHandler(
      overlayLyricsServiceOverride: overlayService,
      setAudioSourceOverride: (source, player) async => null,
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: true,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.auto,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: true,
    );
    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(
        id: 'song-1',
        title: '歌曲一',
        url: 'file:///tmp/song-1.mp3',
        platform: 'local',
      ),
    ]);
    overlayService.autoHighlightColorValues.clear();

    await handler.syncAutoLyricHighlightColor(
      trackId: 'song-1',
      platform: 'local',
      colorValue: 0xFF34D399,
    );
    await handler.syncAutoLyricHighlightColor(
      trackId: 'stale-song',
      platform: 'local',
      colorValue: 0xFFFB7185,
    );

    expect(overlayService.autoHighlightColorValues, <int?>[0xFF34D399]);
  });

  test('远程歌曲即使已有 url 也应该重新获取播放链接', () async {
    final requestedSongIds = <String>[];
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            return <String, dynamic>{
              'url':
                  'https://fresh.example.com/$songId-${requestedSongIds.length}.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );
    const track = AudioTrack(
      id: 'song-1',
      title: '远程歌曲',
      url: 'https://expired.example.com/song-1.mp3',
      platform: 'qq',
      links: <LinkInfo>[
        LinkInfo(
          name: '320k',
          quality: 320,
          format: 'mp3',
          size: '0',
          url: 'https://stale.example.com/song-1-320.mp3',
        ),
      ],
    );

    await handler.setQueueData(<AudioTrack>[track], initialIndex: 0);
    await handler.setQueueData(
      <AudioTrack>[track],
      initialIndex: 0,
      forceReloadCurrent: true,
    );

    expect(requestedSongIds.length, greaterThanOrEqualTo(2));
    expect(loadedUrls.length, greaterThanOrEqualTo(2));
    expect(loadedUrls[0], 'https://fresh.example.com/song-1-1.mp3');
    expect(loadedUrls[1], isNot(loadedUrls[0]));
  });

  test('setAudioSource 首次失败后应该重新获取新链接并重试', () async {
    final requestedUrls = <String>[];
    var setSourceAttempts = 0;
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            final nextUrl =
                'https://fresh.example.com/$songId-${requestedUrls.length + 1}.mp3';
            requestedUrls.add(nextUrl);
            return <String, dynamic>{'url': nextUrl};
          },
      setAudioSourceOverride: (source, player) async {
        setSourceAttempts += 1;
        if (setSourceAttempts == 1) {
          throw StateError('首次装载失败');
        }
        final uriSource = source as UriAudioSource;
        expect(uriSource.uri.toString(), requestedUrls.last);
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(
        id: 'song-2',
        title: '需要重试的远程歌曲',
        url: 'https://expired.example.com/song-2.mp3',
        platform: 'qq',
      ),
    ], initialIndex: 0);

    expect(requestedUrls, <String>[
      'https://fresh.example.com/song-2-1.mp3',
      'https://fresh.example.com/song-2-2.mp3',
    ]);
    expect(setSourceAttempts, 2);
  });

  test('应该后台预加载下一首链接并在有效期内复用', () async {
    var now = DateTime(2026, 1, 1, 12);
    final requestedSongIds = <String>[];
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      nowOverride: () => now,
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            return <String, dynamic>{
              'url':
                  'https://fresh.example.com/$songId-${requestedSongIds.length}.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
      playOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '第一首', url: '', platform: 'qq'),
      AudioTrack(id: 'song-2', title: '第二首', url: '', platform: 'qq'),
    ], initialIndex: 0);
    await Future<void>.delayed(Duration.zero);

    expect(requestedSongIds, <String>['song-1', 'song-2']);
    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(requestedSongIds.where((id) => id == 'song-2'), hasLength(1));
    expect(loadedUrls.last, 'https://fresh.example.com/song-2-2.mp3');

    final song1RequestCountBeforeExpiry = requestedSongIds
        .where((id) => id == 'song-1')
        .length;
    now = now.add(const Duration(minutes: 9));
    await handler.skipToPrevious();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      requestedSongIds.where((id) => id == 'song-1'),
      hasLength(song1RequestCountBeforeExpiry + 1),
    );
    expect(loadedUrls.last, startsWith('https://fresh.example.com/song-1-'));
  });

  test('随机播放时应该复用洗牌顺序中的预加载下一首链接', () async {
    final requestedSongIds = <String>[];
    final loadedUrls = <String>[];
    final queueEvents = <Map<String, dynamic>>[];
    final handler = HeAudioHandler(
      randomOverride: _SequenceRandom(<int>[2, 1, 0, 0]),
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            return <String, dynamic>{
              'url':
                  'https://fresh.example.com/$songId-${requestedSongIds.length}.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
      playOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is Map<String, dynamic> && event['type'] == 'queueState') {
        queueEvents.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );
    await handler.setShuffleModeEnabled(true);

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '第一首', url: '', platform: 'qq'),
      AudioTrack(id: 'song-2', title: '第二首', url: '', platform: 'qq'),
      AudioTrack(id: 'song-3', title: '第三首', url: '', platform: 'qq'),
    ], initialIndex: 0);
    await Future<void>.delayed(Duration.zero);

    expect(requestedSongIds, <String>['song-1', 'song-2']);
    expect(queueEvents.last['previousPreviewIndex'], 2);
    expect(queueEvents.last['nextPreviewIndex'], 1);
    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(handler.mediaItem.value?.id, 'song-2');
    expect(requestedSongIds.where((id) => id == 'song-2'), hasLength(1));
    expect(loadedUrls.last, 'https://fresh.example.com/song-2-2.mp3');
  });

  test('后台切歌遇到失败歌曲时应该继续尝试后续歌曲', () async {
    final requestedSongIds = <String>[];
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            if (songId == 'song-2') {
              final request = RequestOptions(path: '/v1/song/url');
              throw DioException(
                requestOptions: request,
                response: Response<dynamic>(
                  requestOptions: request,
                  statusCode: 404,
                ),
                type: DioExceptionType.badResponse,
              );
            }
            return <String, dynamic>{
              'url': 'https://fresh.example.com/$songId.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
      playOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(id: 'song-1', title: '第一首', url: '', platform: 'qq'),
      AudioTrack(id: 'song-2', title: '第二首', url: '', platform: 'qq'),
      AudioTrack(id: 'song-3', title: '第三首', url: '', platform: 'qq'),
    ], initialIndex: 0);
    await Future<void>.delayed(Duration.zero);

    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(requestedSongIds, containsAllInOrder(<String>['song-2', 'song-3']));
    expect(handler.mediaItem.value?.id, 'song-3');
    expect(handler.playbackState.value.queueIndex, 2);
    expect(loadedUrls.last, 'https://fresh.example.com/song-3.mp3');
  });

  test('快速切歌时旧请求不应在最后覆盖最新曲目', () async {
    final completer = Completer<void>();
    final loadedUrls = <String>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            if (songId == 'song-1') {
              await completer.future;
            }
            return <String, dynamic>{
              'url': 'https://fresh.example.com/$songId.mp3',
            };
          },
      setAudioSourceOverride: (source, player) async {
        final uriSource = source as UriAudioSource;
        loadedUrls.add(uriSource.uri.toString());
        return null;
      },
    );
    addTearDown(handler.disposeHandler);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );
    const queue = <AudioTrack>[
      AudioTrack(
        id: 'song-1',
        title: '第一首',
        url: 'https://expired.example.com/song-1.mp3',
        platform: 'qq',
      ),
      AudioTrack(
        id: 'song-2',
        title: '第二首',
        url: 'https://expired.example.com/song-2.mp3',
        platform: 'qq',
      ),
    ];

    final staleFuture = handler.setQueueData(
      queue,
      initialIndex: 0,
      forceReloadCurrent: true,
    );
    final latestFuture = handler.setQueueData(
      queue,
      initialIndex: 1,
      forceReloadCurrent: true,
    );
    await latestFuture;
    completer.complete();
    await staleFuture;

    expect(loadedUrls, isNotEmpty);
    expect(loadedUrls.last, 'https://fresh.example.com/song-2.mp3');
    expect(handler.mediaItem.value?.id, 'song-2');
    expect(handler.playbackState.value.queueIndex, 1);
  });

  test('切歌后应该广播后台歌词状态', () async {
    final lyricEvents = <Map<String, dynamic>>[];
    final handler = HeAudioHandler(
      fetchLyricsOverride:
          ({
            required String trackId,
            String? platform,
            String? localPath,
          }) async {
            return LyricDocument(
              lines: <LyricLine>[
                LyricLine(start: Duration.zero, text: 'lyric-$trackId'),
              ],
            );
          },
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is Map<String, dynamic> && event['type'] == 'lyricState') {
        lyricEvents.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(const <AudioTrack>[
      AudioTrack(
        id: 'song-lyric',
        title: '歌词测试',
        url: 'https://example.com/song-lyric.mp3',
      ),
    ]);
    // 歌词加载已改为异步不阻塞，等待微任务完成
    await Future<void>.delayed(Duration.zero);

    expect(lyricEvents, isNotEmpty);
    final lastEvent = lyricEvents.last;
    expect(lastEvent, <String, dynamic>{'type': 'lyricState'});

    final state = await handler.getCurrentLyricState();
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.request?.trackId, 'song-lyric');
    final lines = state.document.lines;
    expect(lines, hasLength(1));
    expect(lines.first.text, 'lyric-song-lyric');
  });

  test('电台队尾切歌时应该在后台请求下一页并接着播放', () async {
    final queueEvents = <Map<String, dynamic>>[];
    final lyricEvents = <Map<String, dynamic>>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async => <String, dynamic>{
            'url': 'https://fresh.example.com/$songId.mp3',
          },
      fetchRadioSongsOverride:
          ({
            required String id,
            required String platform,
            int pageIndex = 1,
            int pageSize = 50,
          }) async {
            if (pageIndex != 2) {
              return const <SongInfo>[];
            }
            return const <SongInfo>[
              SongInfo(
                name: '下一页歌曲',
                subtitle: '',
                id: 'radio-song-2',
                duration: 1000,
                mvId: '',
                album: null,
                artists: <SongInfoArtistInfo>[
                  SongInfoArtistInfo(id: 'artist-1', name: '歌手'),
                ],
                links: <LinkInfo>[],
                platform: 'qq',
                cover: '',
                sublist: <SongInfo>[],
                originalType: 0,
              ),
            ];
          },
      fetchLyricsOverride:
          ({
            required String trackId,
            String? platform,
            String? localPath,
          }) async => const LyricDocument.empty(),
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is! Map<String, dynamic>) {
        return;
      }
      if (event['type'] == 'queueState') {
        queueEvents.add(event);
      }
      if (event['type'] == 'lyricState') {
        lyricEvents.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(
      const <AudioTrack>[
        AudioTrack(
          id: 'radio-song-1',
          title: '第一页歌曲',
          url: 'https://example.com/radio-song-1.mp3',
          platform: 'qq',
        ),
      ],
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );

    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(queueEvents, isNotEmpty);
    final lastQueueEvent = queueEvents.last;
    expect(lastQueueEvent['currentIndex'], 1);
    expect(lastQueueEvent['currentRadioPageIndex'], 2);
    final tracks = lastQueueEvent['tracks'] as List<dynamic>;
    expect(tracks, hasLength(2));
    expect((tracks.last as Map<String, dynamic>)['id'], 'radio-song-2');
    expect(handler.mediaItem.value?.id, 'radio-song-2');
    expect(lyricEvents, isNotEmpty);
  });

  test('电台到达阈值时应先补页再预加载下一首播放链接', () async {
    final requestedSongIds = <String>[];
    final requestedRadioPages = <int>[];
    final queueEvents = <Map<String, dynamic>>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async {
            requestedSongIds.add(songId);
            return <String, dynamic>{
              'url': 'https://fresh.example.com/$songId.mp3',
            };
          },
      fetchRadioSongsOverride:
          ({
            required String id,
            required String platform,
            int pageIndex = 1,
            int pageSize = 50,
          }) async {
            requestedRadioPages.add(pageIndex);
            return const <SongInfo>[
              SongInfo(
                name: '下一页第一首',
                subtitle: '',
                id: 'radio-song-3',
                duration: 1000,
                mvId: '',
                album: null,
                artists: <SongInfoArtistInfo>[
                  SongInfoArtistInfo(id: 'artist-1', name: '歌手'),
                ],
                links: <LinkInfo>[],
                platform: 'qq',
                cover: '',
                sublist: <SongInfo>[],
                originalType: 0,
              ),
            ];
          },
      fetchLyricsOverride:
          ({
            required String trackId,
            String? platform,
            String? localPath,
          }) async => const LyricDocument.empty(),
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is Map<String, dynamic> && event['type'] == 'queueState') {
        queueEvents.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: null,
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );

    await handler.setQueueData(
      const <AudioTrack>[
        AudioTrack(id: 'radio-song-1', title: '第一首', url: '', platform: 'qq'),
        AudioTrack(id: 'radio-song-2', title: '第二首', url: '', platform: 'qq'),
      ],
      initialIndex: 1,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
    await Future<void>.delayed(Duration.zero);

    expect(requestedRadioPages, <int>[2]);
    expect(requestedSongIds, <String>['radio-song-2', 'radio-song-3']);
    expect(
      queueEvents.where((event) {
        final tracks = event['tracks'];
        return tracks is List &&
            tracks.any(
              (track) =>
                  track is Map<String, dynamic> &&
                  track['id'] == 'radio-song-3' &&
                  track['url'] == '',
            );
      }).length,
      1,
    );
  });

  test('电台后台补页的在线歌曲封面应使用统一解析方法', () async {
    final queueEvents = <Map<String, dynamic>>[];
    final handler = HeAudioHandler(
      fetchSongUrlOverride:
          ({
            required String songId,
            required String platform,
            int? quality,
            String? format,
          }) async => <String, dynamic>{
            'url': 'https://fresh.example.com/$songId.mp3',
          },
      fetchRadioSongsOverride:
          ({
            required String id,
            required String platform,
            int pageIndex = 1,
            int pageSize = 50,
          }) async {
            if (pageIndex != 2) {
              return const <SongInfo>[];
            }
            return const <SongInfo>[
              SongInfo(
                name: '下一页歌曲',
                subtitle: '',
                id: 'radio-cover-2',
                duration: 1000,
                mvId: '',
                album: null,
                artists: <SongInfoArtistInfo>[],
                links: <LinkInfo>[],
                platform: 'qq',
                cover: 'https://img.example.com/{x}/cover.jpg',
                sublist: <SongInfo>[],
                originalType: 0,
              ),
            ];
          },
      fetchLyricsOverride:
          ({
            required String trackId,
            String? platform,
            String? localPath,
          }) async => const LyricDocument.empty(),
      setAudioSourceOverride: (source, player) async => null,
      playOverride: (player) async {},
      disposeOverride: (player) async {},
    );
    addTearDown(handler.disposeHandler);
    final subscription = handler.customEvent.listen((event) {
      if (event is Map<String, dynamic> && event['type'] == 'queueState') {
        queueEvents.add(event);
      }
    });
    addTearDown(subscription.cancel);
    await handler.syncConfig(
      apiBaseUrl: 'https://api.example.com',
      authToken: 'token-1',
      qualityPreference: AppOnlineAudioQuality.auto,
      lastSelectedQualityName: null,
      enableDesktopLyric: false,
      enableDesktopLyricLock: false,
      lyricHighlightMode: AppLyricHighlightMode.preset,
      lyricHighlightPresetColorValue: AppLyricHighlightColor.sky.color
          .toARGB32(),
      lyricHighlightCustomColorValue: null,
      lyricFontPresetIndex: AppLyricFontPreset.medium.index,
      enableWordByWordLyric: false,
    );
    await handler.syncCoverPlatforms(<OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
        imageSizes: <int>[180, 300, 500],
      ),
    ]);
    await handler.setQueueData(
      const <AudioTrack>[
        AudioTrack(
          id: 'radio-cover-1',
          title: '第一页歌曲',
          url: 'https://example.com/radio-cover-1.mp3',
          platform: 'qq',
        ),
      ],
      isRadioMode: true,
      currentRadioId: 'radio-cover',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );

    await handler.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final lastQueueEvent = queueEvents.last;
    final tracks = lastQueueEvent['tracks'] as List<dynamic>;
    final artworkUrl =
        (tracks.last as Map<String, dynamic>)['artworkUrl'] as String?;
    expect(artworkUrl, 'https://img.example.com/500/cover.jpg');
  });
}

class _SequenceRandom implements Random {
  _SequenceRandom(this._values);

  final List<int> _values;
  var _index = 0;

  @override
  int nextInt(int max) {
    final value = _values[_index % _values.length];
    _index += 1;
    return value % max;
  }

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(1000000) / 1000000;
}

class _AudioRefreshTestServer {
  _AudioRefreshTestServer._(this._server);

  final HttpServer _server;
  final List<String> songUrlAuthorizations = <String>[];
  int refreshRequestCount = 0;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<_AudioRefreshTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _AudioRefreshTestServer._(server);
    server.listen(fixture._handleRequest);
    return fixture;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handleRequest(HttpRequest request) async {
    switch (request.uri.path) {
      case '/v1/auth/token/refresh':
        refreshRequestCount++;
        await utf8.decoder.bind(request).join();
        await _writeJson(request.response, <String, dynamic>{
          'access_token': 'fresh-token',
          'refresh_token': 'fresh-refresh-token',
          'expires_at': 123,
        });
        return;
      case '/v1/song/url':
        final authorization =
            request.headers.value(HttpHeaders.authorizationHeader) ?? '';
        songUrlAuthorizations.add(authorization);
        if (authorization != 'Bearer fresh-token') {
          await _writeJson(request.response, <String, dynamic>{
            'error': 'expired',
          }, statusCode: HttpStatus.unauthorized);
          return;
        }
        await _writeJson(request.response, <String, dynamic>{
          'url': 'https://audio.example.com/song-1.mp3',
          'format': 'mp3',
        });
        return;
      default:
        await _writeJson(request.response, <String, dynamic>{
          'error': 'not found',
        }, statusCode: HttpStatus.notFound);
        return;
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, dynamic> payload, {
    int statusCode = HttpStatus.ok,
  }) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await response.close();
  }
}

class _RecordingOverlayChannelService implements OverlayChannelService {
  final List<int?> autoHighlightColorValues = <int?>[];

  @override
  Stream<OverlayMessage> get overlayToMainMessages =>
      const Stream<OverlayMessage>.empty();

  @override
  Future<void> close() async {}

  @override
  Future<bool> isActive() async => false;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<void> lock() async {}

  @override
  Future<void> open() async {}

  @override
  Future<bool?> requestPermission() async => true;

  @override
  Future<void> sendClose() async {}

  @override
  Future<void> sendDocument(
    LyricDocument document,
    AppConfigState config, {
    int? autoHighlightColorValue,
  }) async {}

  @override
  Future<void> sendPosition(Duration position) async {}

  @override
  Future<void> sendStyleUpdate(
    AppConfigState config, {
    int? autoHighlightColorValue,
  }) async {
    autoHighlightColorValues.add(autoHighlightColorValue);
  }

  @override
  Future<void> sendTrackChanged({
    required String title,
    required String artist,
  }) async {}

  @override
  Future<void> unlock() async {}
}
