import 'dart:io';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/data/services/download_lyric_resolver.dart';
import 'package:he_music_flutter/features/download/data/services/download_metadata_writer.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';

void main() {
  test(
    'metadata writer falls back to plain lyric when timed lyric is unavailable',
    () async {
      final adapter = _FakeMetadataAdapter();
      final writer = DownloadMetadataWriter(
        lyricResolver: _FakeDownloadLyricResolver(
          const ResolvedDownloadLyric(
            content: '一路向北',
            format: DownloadLyricFormat.plain,
          ),
        ),
        metadataAdapter: adapter,
      );

      final result = await writer.write(
        const DownloadMetadataRequest(
          filePath: '/tmp/song.mp3',
          songId: 'song-1',
          platform: 'qq',
          title: '一路向北',
          artist: '周杰伦',
          album: '十一月的萧邦',
        ),
      );

      expect(result.lyricFormat, DownloadLyricFormat.plain);
      expect(adapter.lastLyrics, '一路向北');
    },
  );

  test('metadata writer writes sidecar lrc when lyric is available', () async {
    final adapter = _FakeMetadataAdapter();
    final tempDir = await Directory.systemTemp.createTemp('download_meta_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final audioPath = '${tempDir.path}/song.mp3';
    final writer = DownloadMetadataWriter(
      lyricResolver: _FakeDownloadLyricResolver(
        const ResolvedDownloadLyric(
          content: '[00:01.00]夜曲',
          format: DownloadLyricFormat.timed,
        ),
      ),
      metadataAdapter: adapter,
    );

    final result = await writer.write(
      DownloadMetadataRequest(
        filePath: audioPath,
        songId: 'song-1',
        platform: 'qq',
        title: '夜曲',
        artist: '周杰伦',
        album: '十一月的萧邦',
      ),
    );

    final lrcFile = File('${tempDir.path}/song.lrc');
    expect(result.lyricFormat, DownloadLyricFormat.timed);
    expect(result.lyricPath, lrcFile.path);
    expect(await lrcFile.exists(), isTrue);
    expect(await lrcFile.readAsString(), '[00:01.00]夜曲');
  });

  test('metadata writer skips sidecar lrc when lyric is unavailable', () async {
    final adapter = _FakeMetadataAdapter();
    final tempDir = await Directory.systemTemp.createTemp('download_meta_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final audioPath = '${tempDir.path}/song.mp3';
    final writer = DownloadMetadataWriter(
      lyricResolver: _FakeDownloadLyricResolver(
        const ResolvedDownloadLyric.none(),
      ),
      metadataAdapter: adapter,
    );

    final result = await writer.write(
      DownloadMetadataRequest(
        filePath: audioPath,
        songId: 'song-1',
        platform: 'qq',
        title: '夜曲',
        artist: '周杰伦',
        album: '十一月的萧邦',
      ),
    );

    final lrcFile = File('${tempDir.path}/song.lrc');
    expect(result.lyricFormat, DownloadLyricFormat.none);
    expect(result.lyricPath, isNull);
    expect(await lrcFile.exists(), isFalse);
  });

  test(
    'lyric resolver keeps timed lyric when lyric payload contains timestamps',
    () {
      final resolver = DownloadLyricResolver(
        ({required trackId, required platform}) async =>
            const RawLyricBundle(lyric: '[00:01.00]夜曲'),
      );

      final result = resolver.resolveBundle(
        const RawLyricBundle(lyric: '[00:01.00]夜曲'),
      );

      expect(result.format, DownloadLyricFormat.timed);
      expect(result.content, '[00:01.00]夜曲');
    },
  );

  test('lyric resolver treats word lyric with timestamps as timed lyric', () {
    final resolver = DownloadLyricResolver(
      ({required trackId, required platform}) async =>
          const RawLyricBundle(lyric: '[00:01.00]<0,500>夜<500,500>曲'),
    );

    final result = resolver.resolveBundle(
      const RawLyricBundle(lyric: '[00:01.00]<0,500>夜<500,500>曲'),
    );

    expect(result.format, DownloadLyricFormat.timed);
    expect(result.content, '[00:01.00]夜曲');
  });

  test('audio metadata adapter infers png mime type from artwork bytes', () {
    final mimeType = inferArtworkMimeType(
      Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D]),
    );

    expect(mimeType, at.MimeType.png);
  });

  test(
    'audio metadata adapter creates mp3 metadata when file has no existing tag',
    () async {
      at.Tag? persistedMetadata;
      final adapter = AudioMetadataAdapter(
        readTag: (_) async => null,
        writeTag: (_, metadata) async {
          persistedMetadata = metadata;
        },
      );

      await adapter.write(
        path: '/tmp/test-song.mp3',
        title: '夜曲',
        artist: '周杰伦',
        album: '十一月的萧邦',
        lyrics: '一群嗜血的蚂蚁',
      );

      final metadata = persistedMetadata;
      expect(metadata, isNotNull);
      expect(metadata!.title, '夜曲');
      expect(metadata.artists, <String>['周杰伦']);
      expect(metadata.albumArtists, <String>['周杰伦']);
      expect(metadata.album, '十一月的萧邦');
      expect(metadata.lyrics, '一群嗜血的蚂蚁');
      expect(metadata.pictures, isEmpty);
    },
  );

  test(
    'audio metadata adapter normalizes multi artist separator for tag writing',
    () async {
      at.Tag? persistedMetadata;
      final adapter = AudioMetadataAdapter(
        readTag: (_) async => null,
        writeTag: (_, metadata) async {
          persistedMetadata = metadata;
        },
      );

      await adapter.write(
        path: '/tmp/test-song.mp3',
        title: '夜曲',
        artist: '周杰伦 / 五月天，林俊杰 & 陈奕迅',
        album: '十一月的萧邦',
      );

      final metadata = persistedMetadata;
      expect(metadata, isNotNull);
      expect(metadata!.artists, <String>['周杰伦', '五月天', '林俊杰', '陈奕迅']);
      expect(metadata.albumArtists, <String>['周杰伦', '五月天', '林俊杰', '陈奕迅']);
    },
  );

  test(
    'audio metadata adapter still writes when reading existing tag fails',
    () async {
      at.Tag? persistedMetadata;
      final adapter = AudioMetadataAdapter(
        readTag: (_) async => throw RangeError(1684098068),
        writeTag: (_, metadata) async {
          persistedMetadata = metadata;
        },
      );

      await adapter.write(
        path: '/tmp/test-song.flac',
        title: 'Runway(Explicit)',
        artist: 'Lady Gaga / Doechii',
        album: 'Runway (Explicit)',
      );

      final metadata = persistedMetadata;
      expect(metadata, isNotNull);
      expect(metadata!.artists, <String>['Lady Gaga', 'Doechii']);
      expect(metadata.albumArtists, <String>['Lady Gaga', 'Doechii']);
    },
  );
}

class _FakeMetadataAdapter implements DownloadMetadataAdapter {
  String? lastLyrics;

  @override
  Future<void> write({
    required String path,
    required String title,
    required String artist,
    required String album,
    Uint8List? artworkBytes,
    String? lyrics,
  }) async {
    lastLyrics = lyrics;
  }
}

class _FakeDownloadLyricResolver extends DownloadLyricResolver {
  _FakeDownloadLyricResolver(this._result)
    : super(({required trackId, required platform}) async => null);

  final ResolvedDownloadLyric _result;

  @override
  Future<ResolvedDownloadLyric> resolve({
    required String songId,
    required String platform,
  }) async {
    return _result;
  }
}
