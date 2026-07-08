import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';

void main() {
  group('LocalSong', () {
    const song = LocalSong(
      id: 'ls1',
      title: 'Test Song',
      filePath: '/music/test.mp3',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(minutes: 3, seconds: 30),
      mimeType: 'audio/mpeg',
      size: 5242880,
    );

    group('copyWith', () {
      test('应只覆盖 artworkBytes', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final updated = song.copyWith(artworkBytes: bytes);
        expect(updated.artworkBytes, bytes);
        // 其他字段不变
        expect(updated.id, song.id);
        expect(updated.title, song.title);
        expect(updated.filePath, song.filePath);
        expect(updated.artist, song.artist);
      });

      test('不传参应保持原值', () {
        final copy = song.copyWith();
        expect(copy.id, song.id);
        expect(copy.title, song.title);
        expect(copy.artworkBytes, isNull);
      });
    });

    group('formatLabel', () {
      test('应从 .flac 扩展名推断为 FLAC', () {
        const flacSong = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.flac',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(flacSong.formatLabel, 'FLAC');
      });

      test('应从 .wav 扩展名推断为 WAV', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.wav',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'WAV');
      });

      test('应从 .ape 扩展名推断为 APE', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.ape',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'APE');
      });

      test('应从 .aac 扩展名推断为 AAC', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.aac',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'AAC');
      });

      test('应从 .ogg 扩展名推断为 OGG', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.ogg',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'OGG');
      });

      test('应从 .m4a 扩展名推断为 M4A', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.m4a',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'M4A');
      });

      test('应从 .mp3 扩展名推断为 MP3', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.mp3',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(s.formatLabel, 'MP3');
      });

      test('扩展名无法匹配时应回退到 mimeType', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.unknown',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: 'audio/flac',
          size: 0,
        );
        expect(s.formatLabel, 'FLAC');
      });

      test('mimeType 包含 mpeg 应推断为 MP3', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.xyz',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: 'audio/mpeg',
          size: 0,
        );
        expect(s.formatLabel, 'MP3');
      });

      test('mimeType 包含 mp4 应推断为 M4A', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.xyz',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: 'audio/mp4',
          size: 0,
        );
        expect(s.formatLabel, 'M4A');
      });

      test('扩展名和 mimeType 都无法匹配时返回空字符串', () {
        const s = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/music/s.xyz',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: 'application/octet-stream',
          size: 0,
        );
        expect(s.formatLabel, '');
      });
    });

    group('默认值', () {
      test('应有正确的默认值', () {
        const minimal = LocalSong(
          id: '1',
          title: 'T',
          filePath: '/f.mp3',
          artist: '',
          album: '',
          duration: Duration.zero,
          mimeType: '',
          size: 0,
        );
        expect(minimal.genre, '');
        expect(minimal.year, isNull);
        expect(minimal.hasArtwork, isFalse);
        expect(minimal.metadataEdited, isFalse);
        expect(minimal.status, 'active');
        expect(minimal.artworkBytes, isNull);
      });
    });
  });
}
