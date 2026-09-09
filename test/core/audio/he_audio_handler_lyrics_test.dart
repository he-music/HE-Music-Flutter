import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/lyrics/domain/usecases/parse_lrc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LyricStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('handler-lyric-test');
    store = LyricStore(
      manualDirectory: () async => Directory('${root.path}/manual'),
      automaticDirectory: () async => Directory('${root.path}/auto'),
    );
  });
  tearDown(() async => root.delete(recursive: true));
  HeAudioHandler handler(HeAudioHandlerFetchLyrics fetch) => HeAudioHandler(
    lyricStore: store,
    fetchLyricsOverride: fetch,
    setAudioSourceOverride: (_, _) async => null,
    playOverride: (_) async {},
    disposeOverride: (_) async {},
  );
  const tracks = [
    AudioTrack(
      id: 'A',
      title: 'A',
      url: '',
      platform: 'local',
      path: '/tmp/A.mp3',
    ),
    AudioTrack(
      id: 'B',
      title: 'B',
      url: '',
      platform: 'local',
      path: '/tmp/B.mp3',
    ),
  ];

  test(
    'A to B to A rejects the first A completion despite matching identity',
    () async {
      final pending = <(String, Completer<LyricDocument>)>[];
      final audio = handler(({required trackId, platform, localPath}) {
        final completer = Completer<LyricDocument>();
        pending.add((trackId, completer));
        return completer.future;
      });
      addTearDown(audio.disposeHandler);
      await audio.setQueueData(tracks);
      await Future<void>.delayed(Duration.zero);
      await audio.playIndex(1);
      await Future<void>.delayed(Duration.zero);
      await audio.playIndex(0);
      await Future<void>.delayed(Duration.zero);
      expect(pending.map((v) => v.$1), ['A', 'B', 'A']);
      LyricDocument doc(String text) => LyricDocument(
        lines: [LyricLine(start: Duration.zero, text: text)],
      );
      pending[2].$2.complete(doc('new A'));
      await Future<void>.delayed(Duration.zero);
      pending[0].$2.complete(doc('stale A'));
      pending[1].$2.complete(doc('stale B'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (await audio.getCurrentLyricState()).document.lines.single.text,
        'new A',
      );
    },
  );

  test(
    'manual storage mutations update authoritative snapshots only for current target',
    () async {
      final audio = handler(({required trackId, platform, localPath}) async {
        final raw = await store.read(
          LyricRequest(
            trackId: trackId,
            platform: platform,
            localPath: localPath,
          ),
          manual: true,
        );
        return parseLyricDocument(
          lyric: raw?.lyric ?? '[00:00.00]default $trackId',
        );
      });
      addTearDown(audio.disposeHandler);
      await audio.setQueueData(tracks);
      Future<void> settle(String text) async {
        for (var i = 0; i < 100; i++) {
          if ((await audio.getCurrentLyricState())
                  .document
                  .lines
                  .firstOrNull
                  ?.text ==
              text) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        fail('snapshot did not become $text');
      }

      await settle('default A');
      const a = LyricRequest(
        trackId: 'A',
        platform: 'local',
        localPath: '/tmp/A.mp3',
      );
      final token = store.beginSelection(a);
      await audio.playIndex(1);
      await settle('default B');
      await store.saveManual(
        a,
        const RawLyricBundle(lyric: '[00:00.00]chosen A'),
        sourcePlatform: 'kg',
        sourceId: 'candidate',
        title: 'A',
        artist: '',
        token: token,
      );
      expect(audio.mediaItem.value!.id, 'B');
      expect(
        (await audio.getCurrentLyricState()).document.lines.single.text,
        'default B',
      );
      await audio.playIndex(0);
      await settle('chosen A');
      expect(audio.mediaItem.value!.id, 'A');
      await store.restoreDefault(a);
      await settle('default A');
      await store.saveManual(
        a,
        const RawLyricBundle(lyric: '[00:00.00]chosen again'),
        sourcePlatform: 'kg',
        sourceId: 'candidate',
        title: 'A',
        artist: '',
        token: store.beginSelection(a),
      );
      await settle('chosen again');
      await store.clearManual();
      await settle('default A');
    },
  );
}
