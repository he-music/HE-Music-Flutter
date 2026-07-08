import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics_overlay/data/overlay_message.dart';

void main() {
  group('OverlayMessage', () {
    test('OverlayPositionMessage serializes and deserializes', () {
      final original = OverlayPositionMessage(12345);
      final json = original.toJson();
      final restored = OverlayMessage.fromJson(json) as OverlayPositionMessage;

      expect(json['type'], 'position');
      expect(json['positionMs'], 12345);
      expect(restored.positionMs, 12345);
    });

    test('OverlayTrackChangedMessage serializes and deserializes', () {
      final original = OverlayTrackChangedMessage(
        title: '测试歌曲',
        artist: '测试歌手',
      );
      final json = original.toJson();
      final restored =
          OverlayMessage.fromJson(json) as OverlayTrackChangedMessage;

      expect(json['type'], 'trackChanged');
      expect(json['title'], '测试歌曲');
      expect(json['artist'], '测试歌手');
      expect(restored.title, '测试歌曲');
      expect(restored.artist, '测试歌手');
    });

    test('OverlayStyleUpdateMessage serializes and deserializes', () {
      final original = OverlayStyleUpdateMessage(
        highlightColorValue: 0xFF0000,
        fontPresetIndex: 2,
        enableWordByWord: true,
      );
      final json = original.toJson();
      final restored =
          OverlayMessage.fromJson(json) as OverlayStyleUpdateMessage;

      expect(json['type'], 'styleUpdate');
      expect(json['highlightColorValue'], 0xFF0000);
      expect(json['fontPresetIndex'], 2);
      expect(json['enableWordByWord'], true);
      expect(restored.highlightColorValue, 0xFF0000);
      expect(restored.fontPresetIndex, 2);
      expect(restored.enableWordByWord, true);
    });

    test('OverlayLockStateMessage serializes and deserializes', () {
      final original = OverlayLockStateMessage(true);
      final json = original.toJson();
      final restored = OverlayMessage.fromJson(json) as OverlayLockStateMessage;

      expect(json['type'], 'lockState');
      expect(json['locked'], true);
      expect(restored.locked, true);
    });

    test('OverlayCloseMessage serializes and deserializes', () {
      const original = OverlayCloseMessage();
      final json = original.toJson();
      final restored = OverlayMessage.fromJson(json) as OverlayCloseMessage;

      expect(json['type'], 'close');
      expect(restored, isA<OverlayCloseMessage>());
    });

    test('OverlayLyricDocMessage serializes and deserializes', () {
      final doc = LyricDocument(
        offset: 500,
        lines: <LyricLine>[
          LyricLine(
            start: const Duration(milliseconds: 1000),
            end: const Duration(milliseconds: 3000),
            text: 'Hello World',
            translation: '你好世界',
            romanization: '',
            tokens: <LyricToken>[
              LyricToken(
                text: 'Hello',
                startOffset: const Duration(milliseconds: 0),
                duration: const Duration(milliseconds: 1000),
              ),
              LyricToken(
                text: 'World',
                startOffset: const Duration(milliseconds: 1000),
                duration: const Duration(milliseconds: 1000),
              ),
            ],
          ),
        ],
      );
      final original = OverlayLyricDocMessage(doc);
      final json = original.toJson();
      final restored = OverlayMessage.fromJson(json) as OverlayLyricDocMessage;

      expect(json['type'], 'lyricDoc');
      expect(restored.document.offset, 500);
      expect(restored.document.lines, hasLength(1));
      expect(restored.document.lines.first.text, 'Hello World');
      expect(restored.document.lines.first.translation, '你好世界');
      expect(restored.document.lines.first.tokens, hasLength(2));
    });

    test('fromJson throws on unknown type', () {
      expect(
        () => OverlayMessage.fromJson({'type': 'unknown'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('OverlayStyleUpdateMessage defaults for missing fields', () {
      final json = <String, dynamic>{'type': 'styleUpdate'};
      final restored =
          OverlayMessage.fromJson(json) as OverlayStyleUpdateMessage;

      expect(restored.highlightColorValue, 0xFF4FC3F7);
      expect(restored.fontPresetIndex, 1);
      expect(restored.enableWordByWord, false);
    });
  });
}
