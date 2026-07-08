import '../../lyrics/domain/entities/lyric_document.dart';
import '../../lyrics/domain/entities/lyric_line.dart';

sealed class OverlayMessage {
  const OverlayMessage();

  Map<String, dynamic> toJson();

  static OverlayMessage fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'lyricDoc':
        return OverlayLyricDocMessage._fromJson(json);
      case 'position':
        return OverlayPositionMessage._fromJson(json);
      case 'trackChanged':
        return OverlayTrackChangedMessage._fromJson(json);
      case 'styleUpdate':
        return OverlayStyleUpdateMessage._fromJson(json);
      case 'close':
        return const OverlayCloseMessage();
      case 'lockState':
        return OverlayLockStateMessage._fromJson(json);
      default:
        throw ArgumentError('Unknown overlay message type: ${json['type']}');
    }
  }
}

class OverlayLyricDocMessage extends OverlayMessage {
  OverlayLyricDocMessage(this.document);

  final LyricDocument document;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'lyricDoc',
    'document': _serializeDocument(document),
  };

  factory OverlayLyricDocMessage._fromJson(Map<String, dynamic> json) {
    return OverlayLyricDocMessage(
      _deserializeDocument(json['document'] as Map<String, dynamic>),
    );
  }
}

class OverlayPositionMessage extends OverlayMessage {
  OverlayPositionMessage(this.positionMs);

  final int positionMs;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'position',
    'positionMs': positionMs,
  };

  factory OverlayPositionMessage._fromJson(Map<String, dynamic> json) {
    return OverlayPositionMessage(json['positionMs'] as int);
  }
}

class OverlayTrackChangedMessage extends OverlayMessage {
  OverlayTrackChangedMessage({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'trackChanged',
    'title': title,
    'artist': artist,
  };

  factory OverlayTrackChangedMessage._fromJson(Map<String, dynamic> json) {
    return OverlayTrackChangedMessage(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
    );
  }
}

class OverlayStyleUpdateMessage extends OverlayMessage {
  OverlayStyleUpdateMessage({
    required this.highlightColorValue,
    required this.fontPresetIndex,
    required this.enableWordByWord,
  });

  final int highlightColorValue;
  final int fontPresetIndex;
  final bool enableWordByWord;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'styleUpdate',
    'highlightColorValue': highlightColorValue,
    'fontPresetIndex': fontPresetIndex,
    'enableWordByWord': enableWordByWord,
  };

  factory OverlayStyleUpdateMessage._fromJson(Map<String, dynamic> json) {
    return OverlayStyleUpdateMessage(
      highlightColorValue: json['highlightColorValue'] as int? ?? 0xFF4FC3F7,
      fontPresetIndex: json['fontPresetIndex'] as int? ?? 1,
      enableWordByWord: json['enableWordByWord'] as bool? ?? false,
    );
  }
}

class OverlayLockStateMessage extends OverlayMessage {
  const OverlayLockStateMessage(this.locked);

  final bool locked;

  @override
  Map<String, dynamic> toJson() => {'type': 'lockState', 'locked': locked};

  factory OverlayLockStateMessage._fromJson(Map<String, dynamic> json) {
    return OverlayLockStateMessage(json['locked'] as bool? ?? false);
  }
}

class OverlayCloseMessage extends OverlayMessage {
  const OverlayCloseMessage();

  @override
  Map<String, dynamic> toJson() => const {'type': 'close'};
}

Map<String, dynamic> _serializeDocument(LyricDocument doc) => {
  'offset': doc.offset,
  'lines': doc.lines.map(_serializeLine).toList(growable: false),
};

Map<String, dynamic> _serializeLine(LyricLine line) => {
  'startMs': line.start.inMilliseconds,
  'endMs': line.end?.inMilliseconds,
  'text': line.text,
  'translation': line.translation,
  'romanization': line.romanization,
  'tokens': line.tokens.map(_serializeToken).toList(growable: false),
};

Map<String, dynamic> _serializeToken(LyricToken token) => {
  'text': token.text,
  'startOffsetMs': token.startOffset.inMilliseconds,
  'durationMs': token.duration.inMilliseconds,
};

LyricDocument _deserializeDocument(Map<String, dynamic> json) {
  final lines = (json['lines'] as List)
      .map((e) => _deserializeLine(e as Map<String, dynamic>))
      .toList(growable: false);
  return LyricDocument(lines: lines, offset: json['offset'] as int? ?? 0);
}

LyricLine _deserializeLine(Map<String, dynamic> json) {
  final tokens =
      (json['tokens'] as List?)
          ?.map((e) => _deserializeToken(e as Map<String, dynamic>))
          .toList(growable: false) ??
      [];
  return LyricLine(
    start: Duration(milliseconds: json['startMs'] as int),
    end: json['endMs'] != null
        ? Duration(milliseconds: json['endMs'] as int)
        : null,
    text: json['text'] as String? ?? '',
    tokens: tokens,
    translation: json['translation'] as String? ?? '',
    romanization: json['romanization'] as String? ?? '',
  );
}

LyricToken _deserializeToken(Map<String, dynamic> json) => LyricToken(
  text: json['text'] as String? ?? '',
  startOffset: Duration(milliseconds: json['startOffsetMs'] as int? ?? 0),
  duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
);
