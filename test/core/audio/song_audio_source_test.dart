import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/song_audio_source.dart';

void main() {
  test('keeps server-decrypted URLs and resolves actual output format', () {
    final source = SongAudioSource.fromPayload({
      'url': 'https://server.example/decrypted',
      'format': 'M4A',
    }, requestedFormat: 'flac');
    expect(source.url, 'https://server.example/decrypted');
    expect(source.format, 'm4a');
    expect(source.audioParams, isNull);
  });

  test(
    'preserves validated v1 execution material for playback and download',
    () {
      final parameters = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'v': 1,
                'kind': 1,
                'key': base64.encode([1, 2, 3]),
              }),
            ),
          )
          .replaceAll('=', '');
      final source = SongAudioSource.fromPayload({
        'url': 'https://cdn.example/encrypted',
        'format': 'flac',
        'audio_params': parameters,
      }, requestedFormat: 'mflac');
      expect(source.audioParams, parameters);
      expect(source.format, 'flac');
    },
  );

  test('rejects legacy raw keys rather than playing ciphertext', () {
    expect(
      () => SongAudioSource.fromPayload({
        'url': 'https://cdn.example/audio',
        'key': 'legacy-secret',
      }, requestedFormat: 'mp3'),
      throwsFormatException,
    );
  });

  test('rejects malformed or unsupported execution parameters', () {
    for (final parameters in [
      42,
      'bad+/=',
      base64Url.encode(utf8.encode('{"v":2}')),
    ]) {
      expect(
        () => SongAudioSource.fromPayload({
          'url': 'https://cdn.example/audio',
          'audio_params': parameters,
        }, requestedFormat: 'mp3'),
        throwsFormatException,
      );
    }
  });
}
