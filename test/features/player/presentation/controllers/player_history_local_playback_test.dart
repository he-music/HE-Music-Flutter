import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_history_data_source.dart';
import 'package:he_music_flutter/features/player/data/datasources/player_queue_data_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_history_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_history_manager.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_quality_manager.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_queue_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PlayerHistoryDataSource history;
  late PlayerHistoryManager manager;
  late PlayerQualityManager quality;
  late PlayerQueueManager queueManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('history-local-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    history = const PlayerHistoryDataSource();
    manager = PlayerHistoryManager(dataSource: history);
    quality = PlayerQualityManager(
      platformsReader: () => [],
      configReader: () => throw StateError('No quality preference needed'),
    );
    queueManager = PlayerQueueManager(
      dataSource: const PlayerQueueDataSource(),
      qualityManager: quality,
      fetchRadioSongs: (_, _, _) => throw StateError('Not a radio track'),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  Future<void> expectLocalSource(PlayerTrack track, String expectedPath) async {
    expect(track.path, expectedPath);
    final resolution = await quality.resolveTrackForPlayback([track], 0);
    final uri = Uri.tryParse(expectedPath)!;
    expect(
      resolution.track.url,
      uri.hasScheme ? uri.toString() : Uri.file(expectedPath).toString(),
    );
    expect(resolution.updatedQueue.single.path, expectedPath);
    expect(
      shouldRefreshRemotePlaybackUrl(
        AudioTrack(
          id: track.id,
          title: track.title,
          url: resolution.track.url,
          path: resolution.track.path,
          platform: track.platform,
        ),
      ),
      isFalse,
    );
  }

  test(
    'local history retains its source across persistence and queue restore',
    () async {
      final file = await File('${directory.path}/song with 空格.mp3').create();
      await history.appendTrack(
        PlayerTrack(
          id: 'local-1',
          title: 'Local song',
          platform: 'local',
          path: file.path,
        ),
      );

      final item = (await history.listHistory()).single;
      expect(item.path, file.path);
      expect((await history.watchHistory().first).single.path, file.path);
      final track = manager.historyItemToTrack(item);
      await expectLocalSource(track, file.path);
      await expectLocalSource(queueManager.historyItemToTrack(item), file.path);

      const queue = PlayerQueueDataSource();
      await queue.saveQueue(
        queue: [track],
        currentIndex: 0,
        playMode: PlayerPlayMode.sequence,
        isRadioMode: false,
      );
      await expectLocalSource(
        (await queue.readQueue())!.queue.single,
        file.path,
      );
    },
  );

  for (final useFileUri in [false, true]) {
    test(
      'legacy local history restores ${useFileUri ? 'file URI' : 'absolute path'}',
      () async {
        final file = await File('${directory.path}/old song.mp3').create();
        final source = useFileUri ? file.uri.toString() : file.path;
        SharedPreferences.setMockInitialValues({
          'player_play_history_v1': jsonEncode([
            {
              'id': 'local-old',
              'title': 'Legacy local',
              'platform': 'local',
              'url': source,
              'playedAt': 123,
            },
          ]),
        });
        final item = (await history.listHistory()).single;
        expect(item.path, isNull);
        expect(item.playedAt, 123);
        await expectLocalSource(manager.historyItemToTrack(item), source);
        await expectLocalSource(queueManager.historyItemToTrack(item), source);
      },
    );
  }

  test(
    'expired local history keeps the local source for existing playback errors',
    () async {
      final file = await File('${directory.path}/removed.mp3').create();
      await history.appendTrack(
        PlayerTrack(
          id: 'local-removed',
          title: 'Removed',
          platform: 'local',
          path: file.path,
        ),
      );
      await file.delete();
      expect(await file.exists(), isFalse);
      final item = (await history.listHistory()).single;
      await expectLocalSource(manager.historyItemToTrack(item), file.path);
    },
  );

  test(
    'online legacy URL remains subject to online and download resolution',
    () async {
      SharedPreferences.setMockInitialValues({
        'player_play_history_v1': jsonEncode([
          {
            'id': 'online',
            'title': 'Online',
            'platform': 'netease',
            'url': 'https://expired.example/song.mp3',
          },
        ]),
      });
      final item = (await history.listHistory()).single;
      for (final track in [
        manager.historyItemToTrack(item),
        queueManager.historyItemToTrack(item),
      ]) {
        expect(track.path, isNull);
        expect(track.url, isEmpty);
        final resolved = await quality.resolveTrackForPlayback([track], 0);
        expect(resolved.track.platform, 'netease');
        expect(resolved.track.url, isEmpty);
        expect(
          shouldRefreshRemotePlaybackUrl(
            AudioTrack(
              id: track.id,
              title: track.title,
              url: '',
              platform: track.platform,
            ),
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'explicit downloaded source survives history with online identity',
    () async {
      final file = await File('${directory.path}/download.mp3').create();
      await history.appendTrack(
        PlayerTrack(
          id: 'downloaded',
          title: 'Download',
          platform: 'qq',
          path: file.path,
        ),
      );
      final item = (await history.listHistory()).single;
      await expectLocalSource(manager.historyItemToTrack(item), file.path);
      await expectLocalSource(queueManager.historyItemToTrack(item), file.path);
    },
  );

  test('legacy missing and remote local URLs do not invent a file path', () {
    for (final url in ['', 'https://example/song.mp3', 'invalid%uri']) {
      final item = PlayerHistoryItem(
        id: 'local-unknown',
        title: '',
        artist: '',
        album: '',
        artworkUrl: '',
        url: url,
        playedAt: 0,
        platform: 'local',
      );
      expect(item.playbackPath, isNull);
    }
  });
}
