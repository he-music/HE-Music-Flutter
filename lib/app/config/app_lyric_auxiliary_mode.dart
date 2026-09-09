import '../../features/lyrics/domain/entities/lyric_document.dart';
import '../../features/lyrics/domain/entities/lyric_line.dart';

enum AppLyricAuxiliaryMode {
  translation('翻译'),
  romanization('罗马音'),
  off('关闭');

  const AppLyricAuxiliaryMode(this.label);
  final String label;

  static AppLyricAuxiliaryMode fromValue(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? translation;

  AppLyricAuxiliaryMode effective(LyricDocument document) {
    if (this == off) return off;
    final hasTranslation = document.lines.any(
      (line) => line.translation.trim().isNotEmpty,
    );
    final hasRomanization = document.lines.any(
      (line) => line.romanization.trim().isNotEmpty,
    );
    if (this == translation && hasTranslation) return translation;
    if (this == romanization && hasRomanization) return romanization;
    return hasTranslation
        ? translation
        : hasRomanization
        ? romanization
        : off;
  }

  AppLyricAuxiliaryMode next(LyricDocument document) {
    final available = [
      if (document.lines.any((line) => line.translation.trim().isNotEmpty))
        translation,
      if (document.lines.any((line) => line.romanization.trim().isNotEmpty))
        romanization,
      off,
    ];
    return available[(available.indexOf(effective(document)) + 1) %
        available.length];
  }

  LyricDocument project(LyricDocument document) {
    final mode = effective(document);
    return LyricDocument(
      offset: document.offset,
      lines: [
        for (final line in document.lines)
          LyricLine(
            start: line.start,
            end: line.end,
            text: line.text,
            tokens: line.tokens,
            translation: switch (mode) {
              translation => line.translation,
              romanization => line.romanization,
              off => '',
            },
          ),
      ],
    );
  }
}
