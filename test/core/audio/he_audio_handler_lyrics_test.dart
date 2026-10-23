import 'dart:async';
import 'dart:io';

import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/lyrics_overlay/application/overlay_lyrics_service.dart';
import 'package:he_music_flutter/core/database/app_database.dart';
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
  HeAudioHandler handler(
    HeAudioHandlerFetchLyrics fetch, {
    _RecordingOverlay? overlay,
  }) => HeAudioHandler(
    initialConfig: overlay == null
        ? null
        : AppConfigState.initial.copyWith(enableDesktopLyric: true),
    overlayLyricsServiceOverride: overlay,
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
    'timing updates current lyrics and overlay without fetching or changing tracks',
    () async {
      const a = LyricRequest(
        trackId: 'A',
        platform: 'local',
        localPath: '/tmp/A.mp3',
      );
      const b = LyricRequest(
        trackId: 'B',
        platform: 'local',
        localPath: '/tmp/B.mp3',
      );
      await store.adjustOffset(a, 100, manual: false);
      await store.adjustOffset(b, -200, manual: false);
      final overlay = _RecordingOverlay();
      var fetches = 0;
      final audio = handler(({required trackId, platform, localPath}) async {
        fetches++;
        return LyricDocument(
          lines: [LyricLine(start: const Duration(seconds: 1), text: trackId)],
          offset: 250,
          source: LyricSource.local,
        );
      }, overlay: overlay);
      addTearDown(audio.disposeHandler);
      await audio.setQueueData(tracks);
      await _waitFor(
        () async => !(await audio.getCurrentLyricState()).isLoading,
      );
      expect((await audio.getCurrentLyricState()).document.offset, 350);
      await store.adjustOffset(a, 100, manual: false);
      expect((await audio.getCurrentLyricState()).document.offset, 450);
      expect(audio.mediaItem.value!.id, 'A');
      expect(fetches, 1);
      await _waitFor(() async => overlay.documents.lastOrNull?.offset == 450);
      expect(
        overlay.documents.last.lines.single.start,
        const Duration(seconds: 1),
      );

      await audio.playIndex(1);
      await _waitFor(
        () async =>
            (await audio.getCurrentLyricState())
                .document
                .lines
                .firstOrNull
                ?.text ==
            'B',
      );
      expect((await audio.getCurrentLyricState()).document.offset, 50);
      await store.adjustOffset(a, 100, manual: false);
      expect((await audio.getCurrentLyricState()).document.offset, 50);
      await audio.playIndex(0);
      await _waitFor(
        () async =>
            (await audio.getCurrentLyricState())
                .document
                .lines
                .firstOrNull
                ?.text ==
            'A',
      );
      expect((await audio.getCurrentLyricState()).document.offset, 550);
      await store.resetOffset(a, manual: false);
      expect((await audio.getCurrentLyricState()).document.offset, 250);
    },
  );

  for (final manual in [false, true]) {
    test(
      'reset all timing updates the active source and overlay without refetching: manual=$manual',
      () async {
        const request = LyricRequest(
          trackId: 'A',
          platform: 'local',
          localPath: '/tmp/A.mp3',
        );
        if (manual) {
          await store.saveManual(
            request,
            const RawLyricBundle(lyric: '[offset:250]\n[00:01.00]manual'),
            sourcePlatform: 'qq',
            sourceId: 'candidate',
            title: 'A',
            artist: '',
            token: store.beginSelection(request),
          );
        }
        await store.adjustOffset(request, 100, manual: manual);
        final overlay = _RecordingOverlay();
        var fetches = 0;
        final audio = handler(({required trackId, platform, localPath}) async {
          fetches++;
          return LyricDocument(
            lines: const [
              LyricLine(start: Duration(seconds: 1), text: 'current'),
            ],
            offset: 250,
            source: manual ? LyricSource.manual : LyricSource.local,
          );
        }, overlay: overlay);
        addTearDown(audio.disposeHandler);
        await audio.setQueueData(tracks);
        await _waitFor(
          () async => !(await audio.getCurrentLyricState()).isLoading,
        );
        expect((await audio.getCurrentLyricState()).document.offset, 350);
        await store.resetAllOffsets();
        await _waitFor(
          () async =>
              (await audio.getCurrentLyricState()).document.offset == 250,
        );
        await _waitFor(() async => overlay.documents.lastOrNull?.offset == 250);
        expect(fetches, 1);
        expect(audio.mediaItem.value!.id, 'A');
        expect(
          (await audio.getCurrentLyricState()).document.lines.single.text,
          'current',
        );
        expect(
          (await audio.getCurrentLyricState()).document.source,
          manual ? LyricSource.manual : LyricSource.local,
        );
        if (manual) expect(await store.hasManual(request), isTrue);
      },
    );
  }

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
      await _waitFor(
        () async =>
            (await audio.getCurrentLyricState())
                .document
                .lines
                .firstOrNull
                ?.text ==
            'new A',
      );
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
    'normal playback and track switches never create user offset rows',
    () async {
      final audio = handler(
        ({required trackId, platform, localPath}) async => LyricDocument(
          lines: [LyricLine(start: Duration.zero, text: trackId)],
          offset: 180,
          source: LyricSource.local,
        ),
      );
      addTearDown(audio.disposeHandler);
      await audio.setQueueData(tracks);
      await _waitFor(
        () async => !(await audio.getCurrentLyricState()).isLoading,
      );
      expect((await audio.getCurrentLyricState()).document.offset, 180);
      expect(await appDatabase.select(appDatabase.lyricOffsets).get(), isEmpty);
      await audio.playIndex(1);
      await _waitFor(
        () async =>
            (await audio.getCurrentLyricState())
                .document
                .lines
                .firstOrNull
                ?.text ==
            'B',
      );
      expect(await appDatabase.select(appDatabase.lyricOffsets).get(), isEmpty);
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

Future<void> _waitFor(Future<bool> Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('lyric state did not settle');
}

class _RecordingOverlay extends OverlayLyricsService {
  _RecordingOverlay() : super(isSupportedPlatform: false);
  final documents = <LyricDocument>[];

  @override
  Future<void> sendDocument(
    LyricDocument document,
    AppConfigState config, {
    int? autoHighlightColorValue,
  }) async {
    documents.add(document);
  }
}
