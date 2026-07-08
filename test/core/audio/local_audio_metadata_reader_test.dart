import 'dart:typed_data';

import 'package:audiotags/audiotags.dart' as at;
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';

void main() {
  test('reader maps audiotags tag into local audio metadata', () async {
    final reader = LocalAudioMetadataReader(
      readTag: (_) async => at.Tag(
        title: '夜曲',
        artists: const <String>['周杰伦'],
        album: '十一月的萧邦',
        albumArtists: const <String>[],
        lyrics: '[00:01.00]一群嗜血的蚂蚁',
        duration: 245, // audiotags 返回的 duration 单位是秒
        bitrate: 320,
        sampleRate: 44100,
        bpm: 120,
        pictures: <at.Picture>[
          at.Picture(
            pictureType: at.PictureType.coverFront,
            mimeType: at.MimeType.png,
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      ),
      fileExists: (_) async => true,
    );

    final metadata = await reader.read('/tmp/night.mp3', fetchArtwork: true);

    expect(metadata, isNotNull);
    expect(metadata!.title, '夜曲');
    expect(metadata.artist, '周杰伦');
    expect(metadata.album, '十一月的萧邦');
    expect(metadata.embeddedLyrics, '[00:01.00]一群嗜血的蚂蚁');
    expect(metadata.duration, const Duration(seconds: 245));
    expect(metadata.bitrate, 320);
    expect(metadata.sampleRate, 44100);
    expect(metadata.artworkBytes, Uint8List.fromList(<int>[1, 2, 3]));
  });

  test('reader normalizes v2.4 multi artist separator for display', () async {
    final reader = LocalAudioMetadataReader(
      readTag: (_) async => at.Tag(
        title: '夜曲',
        artists: const <String>['周杰伦', '五月天', '林俊杰'],
        album: '十一月的萧邦',
        albumArtists: const <String>[],
        pictures: const <at.Picture>[],
      ),
      fileExists: (_) async => true,
    );

    final metadata = await reader.read('/tmp/night.mp3');

    expect(metadata, isNotNull);
    expect(metadata!.artist, '周杰伦 / 五月天 / 林俊杰');
  });

  group('edge cases', () {
    test('空路径返回 null', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: 'T',
          artists: const [],
          album: '',
          albumArtists: const [],
          pictures: const [],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('   ');
      expect(metadata, isNull);
    });

    test('文件不存在返回 null', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: 'T',
          artists: const [],
          album: '',
          albumArtists: const [],
          pictures: const [],
        ),
        fileExists: (_) async => false,
      );

      final metadata = await reader.read('/tmp/missing.mp3');
      expect(metadata, isNull);
    });

    test('readTag 返回 null 时返回 null', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => null,
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('/tmp/empty.mp3');
      expect(metadata, isNull);
    });

    test('所有字段为 null 时返回 null（_isEmpty 守卫）', () async {
      // 注意：audiotags Tag 的 bitrate/sampleRate 为 int，无法设为 null
      // 当 title/artist/album 等全为 null/空时，_isEmpty 仍可能因 bitrate!=null 而返回 false
      // 因此用一个 readTag 返回已知非 null 但全空的 tag 来测试
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: null,
          artists: const [],
          album: null,
          albumArtists: const [],
          duration: null,
          bitrate: null,
          sampleRate: null,
          lyrics: null,
          genre: null,
          year: null,
          pictures: const [],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('/tmp/bare.mp3');
      expect(metadata, isNull);
    });

    test('<unknown> 文本标准化为 null', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: '<unknown>',
          artists: const ['<unknown>'],
          album: '<unknown>',
          albumArtists: const [],
          pictures: const [],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('/tmp/unknown.mp3');
      // title/artist/album 全为 <unknown> → normalized 为 null
      // 其余字段也为 null → _isEmpty 为 true → 返回 null
      expect(metadata, isNull);
    });

    test('artwork 优先选取 coverFront', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: 'Song',
          artists: const ['Artist'],
          album: 'Album',
          albumArtists: const [],
          pictures: <at.Picture>[
            at.Picture(
              pictureType: at.PictureType.other,
              mimeType: at.MimeType.jpeg,
              bytes: Uint8List.fromList(<int>[9, 9]),
            ),
            at.Picture(
              pictureType: at.PictureType.coverFront,
              mimeType: at.MimeType.jpeg,
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
            ),
          ],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('/tmp/cover.mp3', fetchArtwork: true);

      expect(metadata, isNotNull);
      expect(metadata!.artworkBytes, Uint8List.fromList(<int>[1, 2, 3]));
    });

    test('无 coverFront 时回退到首个非空图片', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: 'Song',
          artists: const ['Artist'],
          album: 'Album',
          albumArtists: const [],
          pictures: <at.Picture>[
            at.Picture(
              pictureType: at.PictureType.other,
              mimeType: at.MimeType.jpeg,
              bytes: Uint8List.fromList(<int>[4, 5, 6]),
            ),
          ],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read(
        '/tmp/fallback.mp3',
        fetchArtwork: true,
      );

      expect(metadata, isNotNull);
      expect(metadata!.artworkBytes, Uint8List.fromList(<int>[4, 5, 6]));
    });

    test('duration 为 0 或负数时返回 null', () async {
      final reader = LocalAudioMetadataReader(
        readTag: (_) async => at.Tag(
          title: 'Song',
          artists: const ['Artist'],
          album: '',
          albumArtists: const [],
          duration: 0,
          pictures: const [],
        ),
        fileExists: (_) async => true,
      );

      final metadata = await reader.read('/tmp/zero-dur.mp3');
      expect(metadata, isNotNull);
      expect(metadata!.duration, isNull);
    });
  });
}
