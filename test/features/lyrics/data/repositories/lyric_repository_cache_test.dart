import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/demo_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/online_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/repositories/lyric_repository_impl.dart';
import 'package:he_music_flutter/features/lyrics/data/storage/lyric_store.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';

void main() {
  late Directory root;
  late LyricStore store;
  late _Source source;
  late LyricRepositoryImpl repository;
  final warnings = <String>[];
  const target = LyricRequest(trackId: 'song', platform: 'qq');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('lyric-repo-test');
    store = LyricStore(
      manualDirectory: () async => Directory('${root.path}/manual'),
      automaticDirectory: () async => Directory('${root.path}/auto'),
    );
    source = _Source();
    warnings.clear();
    repository = LyricRepositoryImpl(
      source,
      DemoLyricDataSource(),
      const LocalAudioMetadataReader(),
      store: store,
      onWarning: warnings.add,
    );
  });
  tearDown(() async => root.delete(recursive: true));
  Future<void> choose(LyricRequest request) => store.saveManual(
    request,
    const RawLyricBundle(lyric: '[00:00.00]chosen'),
    sourcePlatform: 'kg',
    sourceId: 'candidate',
    title: 'song',
    artist: 'artist',
    token: store.beginSelection(request),
  );

  test(
    'reports the actual source across cache, replacement and refresh',
    () async {
      Future<LyricDocument> load() => repository.fetchLyrics(
        trackId: target.trackId,
        platform: target.platform,
      );
      expect((await load()).source, LyricSource.online);
      expect((await load()).source, LyricSource.cache);
      await choose(target);
      expect((await load()).source, LyricSource.manual);
      await store.restoreDefault(target);
      expect((await load()).source, LyricSource.cache);
      await store.refreshAutomatic(target);
      expect((await load()).source, LyricSource.online);
      expect(source.calls, 2);
    },
  );

  test(
    'online default is reused offline; manual override and reset retain original identity',
    () async {
      expect(
        (await repository.fetchLyrics(
          trackId: 'song',
          platform: 'qq',
        )).lines.single.text,
        'default',
      );
      source.fail = true;
      expect(
        (await repository.fetchLyrics(
          trackId: 'song',
          platform: 'qq',
        )).lines.single.romanization,
        'roma',
      );
      expect(source.calls, 1);
      await choose(target);
      expect(
        (await repository.fetchLyrics(
          trackId: 'song',
          platform: 'qq',
        )).lines.single.text,
        'chosen',
      );
      await store.restoreDefault(target);
      expect(
        (await repository.fetchLyrics(
          trackId: 'song',
          platform: 'qq',
        )).lines.single.text,
        'default',
      );
      expect(source.calls, 1);
    },
  );

  test(
    'broken manual choice warns and falls back without removing association',
    () async {
      await choose(target);
      await File(
        '${root.path}/manual/${lyricStorageKey(target)}.json',
      ).writeAsString('broken');
      expect(
        (await repository.fetchLyrics(
          trackId: 'song',
          platform: 'qq',
        )).lines.single.text,
        'default',
      );
      expect(warnings, hasLength(1));
      expect(await store.hasManual(target), isTrue);
    },
  );

  test(
    'local sidecar and manual override never fetch online or populate automatic cache',
    () async {
      final path = '${root.path}/song.mp3';
      final local = LyricRequest(
        trackId: 'scan',
        platform: 'local',
        localPath: path,
      );
      await File('${root.path}/song.lrc').writeAsString('[00:00.00]sidecar');
      expect(
        (await repository.fetchLyrics(
          trackId: 'scan',
          platform: 'local',
          localPath: path,
        )).lines.single.text,
        'sidecar',
      );
      await choose(local);
      expect(
        (await repository.fetchLyrics(
          trackId: 'scan',
          platform: 'local',
          localPath: path,
        )).lines.single.text,
        'chosen',
      );
      await store.restoreDefault(local);
      expect(
        (await repository.fetchLyrics(
          trackId: 'scan',
          platform: 'local',
          localPath: path,
        )).lines.single.text,
        'sidecar',
      );
      expect(source.calls, 0);
      expect((await store.statistics()).automaticBytes, 0);
    },
  );

  test(
    'sidecar outranks embedded lyrics; unsupported sidecar falls back to embedded',
    () async {
      final metadata = _Metadata();
      repository = LyricRepositoryImpl(
        source,
        DemoLyricDataSource(),
        metadata,
        store: store,
      );
      final path = '${root.path}/song.mp3';
      final sidecar = File('${root.path}/song.lrc');
      await sidecar.writeAsString('[00:00.00]sidecar');
      expect(
        (await repository.fetchLyrics(
          trackId: 'scan',
          platform: 'local',
          localPath: path,
        )).lines.single.text,
        'sidecar',
      );
      expect(metadata.calls, 0);
      await sidecar.writeAsString('unsupported plain text');
      expect(
        (await repository.fetchLyrics(
          trackId: 'scan',
          platform: 'local',
          localPath: path,
        )).lines.single.text,
        'embedded',
      );
      expect(metadata.calls, 1);
      expect(source.calls, 0);
    },
  );

  test(
    'clear during default network request prevents stale cache repopulation',
    () async {
      source.pending = Completer<RawLyricBundle?>();
      final fetch = repository.fetchLyrics(trackId: 'song', platform: 'qq');
      while (source.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.clearAutomatic();
      source.pending!.complete(const RawLyricBundle(lyric: '[00:00.00]late'));
      expect((await fetch).lines.single.text, 'late');
      expect((await store.statistics()).automaticBytes, 0);
    },
  );
}

class _Source extends OnlineLyricDataSource {
  _Source() : super(OnlineApiClient(Dio()));
  int calls = 0;
  bool fail = false;
  Completer<RawLyricBundle?>? pending;
  @override
  Future<RawLyricBundle?> fetchRawLyric({
    required String trackId,
    required String platform,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return const RawLyricBundle(
      lyric: '[00:00.00]default',
      translation: '[00:00.00]translation',
      romanization: '[00:00.00]roma',
    );
  }
}

class _Metadata extends LocalAudioMetadataReader {
  int calls = 0;
  @override
  Future<LocalAudioMetadata?> read(
    String filePath, {
    bool fetchArtwork = false,
  }) async {
    calls++;
    return const LocalAudioMetadata(embeddedLyrics: '[00:00.00]embedded');
  }
}
