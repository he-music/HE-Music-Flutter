import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/lyric_line.dart';
import 'lyric_painter_owner.dart';
import 'monet_lyric_layout.dart';

/// A grapheme keeps the source timing; multi-grapheme tokens are subdivided.
class KineticGlyph {
  KineticGlyph({required this.text, required this.start, required this.end});
  final String text;
  final Duration? start;
  final Duration? end;
}

List<KineticGlyph> buildKineticGlyphs(LyricLine line) {
  final result = <KineticGlyph>[];
  for (final token in buildMonetDisplayTokens(line)) {
    final characters = token.text.characters.toList(growable: false);
    final duration = token.hasTiming
        ? (token.end! - token.start!).inMicroseconds
        : 0;
    for (final (index, text) in characters.indexed) {
      result.add(
        KineticGlyph(
          text: text,
          start: token.hasTiming
              ? token.start! +
                    Duration(
                      microseconds: duration * index ~/ characters.length,
                    )
              : null,
          end: token.hasTiming
              ? token.start! +
                    Duration(
                      microseconds: duration * (index + 1) ~/ characters.length,
                    )
              : null,
        ),
      );
    }
  }
  return result;
}

class KineticPaintGlyph {
  KineticPaintGlyph(
    this.source,
    this.painter,
    this.center,
    this.rotation,
    this.rowY,
  );
  final KineticGlyph source;
  final TextPainter painter;
  final Offset center;
  final double rotation;
  // The camera follows the wrapped baseline, never individual letter jitter.
  final double rowY;
}

class KineticPaintLine implements LyricPaintResources {
  KineticPaintLine({
    required this.entry,
    required this.glyphs,
    required this.subtitle,
    required this.fallback,
  });
  final MonetVisibleLyricLine entry;
  final List<KineticPaintGlyph> glyphs;
  final TextPainter? subtitle;
  // Whole-paragraph fallback preserves shaping for languages with joining letters.
  final TextPainter fallback;
  double y = 0;

  late final double glyphTop = glyphs.isEmpty
      ? 0
      : glyphs.map((g) => g.center.dy - g.painter.height / 2).reduce(math.min);
  late final double glyphBottom = glyphs.isEmpty
      ? 0
      : glyphs.map((g) => g.center.dy + g.painter.height / 2).reduce(math.max);
  double get subtitleY => glyphBottom + 18;

  /// Adjacent lines share this geometry with painting, including auxiliary text.
  ({double top, double bottom}) bounds(bool animated) => animated
      ? (
          top: glyphTop,
          bottom: subtitle == null ? glyphBottom : subtitleY + subtitle!.height,
        )
      : (
          top: -fallback.height / 2,
          bottom:
              fallback.height / 2 +
              (subtitle == null ? 0 : 20 + subtitle!.height),
        );

  bool get hasTiming =>
      !entry.isInterlude && glyphs.any((g) => g.source.start != null);

  @override
  Iterable<TextPainter> get textPainters sync* {
    yield fallback;
    for (final glyph in glyphs) {
      yield glyph.painter;
    }
    if (subtitle != null) yield subtitle!;
  }
}

// Keep joining scripts in a shaped paragraph instead of splitting their glyphs.
final _requiresShaping = RegExp(r'[\u0590-\u109f\u1780-\u17ff]');

KineticPaintLine layoutKineticLine({
  required MonetVisibleLyricLine entry,
  required Size size,
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
  required Locale? locale,
}) {
  final width = math.max(1.0, size.width - 48);
  TextPainter paragraph(
    String text,
    TextStyle style, {
    int? maxLines,
    double? maxWidth,
  }) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textAlign: TextAlign.center,
    textScaler: scaler,
    locale: locale,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth ?? width);
  final font = scaler.scale(style.fontSize!);
  final fallback = paragraph(
    entry.line.text,
    style,
    maxLines: math.max(1, (size.height * .48 / (font * 1.3)).floor()),
    // Reserve a gutter for the line-level note, including its flag.
    maxWidth: math.max(1, size.width - 96),
  );
  final auxiliary = entry.line.translation.trim().isNotEmpty
      ? entry.line.translation
      : entry.line.romanization;
  final subtitle = auxiliary.isEmpty
      ? null
      : paragraph(
          auxiliary,
          style.copyWith(
            fontSize: style.fontSize! * .48,
            color: const Color(0xffaeb8ca),
          ),
          maxLines: 2,
        );
  final glyphs = <KineticPaintGlyph>[];
  final sources = _requiresShaping.hasMatch(entry.line.text)
      ? const <KineticGlyph>[]
      : buildKineticGlyphs(entry.line);
  var row = <(KineticGlyph, TextPainter)>[];
  var rowWidth = 0.0;
  var rowY = 0.0;
  final rowHeight = font * 2.15;
  final gap = font * .23;
  void flush() {
    if (row.isEmpty) return;
    var x = (size.width - rowWidth + gap) / 2;
    if (direction == TextDirection.rtl) x = size.width - x;
    for (final (source, painter) in row) {
      final i = glyphs.length;
      final wave = math.sin(i * .62 + entry.index * .85) * font * .18;
      final jitter = math.sin(i * 17.7 + entry.index * 31.1) * font * .045;
      final dx = direction == TextDirection.rtl
          ? -painter.width / 2
          : painter.width / 2;
      glyphs.add(
        KineticPaintGlyph(
          source,
          painter,
          Offset(x + dx, rowY + wave + jitter),
          math.sin(i * 13.3 + entry.index) * .045,
          rowY,
        ),
      );
      x += (painter.width + gap) * (direction == TextDirection.rtl ? -1 : 1);
    }
    rowY += rowHeight;
    row = [];
    rowWidth = 0;
  }

  for (final source in sources) {
    if (source.text == '\n') {
      flush();
      continue;
    }
    final painter = paragraph(source.text, style);
    final advance = painter.width + gap;
    if (rowWidth + advance > width && row.isNotEmpty) flush();
    row.add((source, painter));
    rowWidth += advance;
  }
  flush();
  return KineticPaintLine(
    entry: entry,
    glyphs: glyphs,
    subtitle: subtitle,
    fallback: fallback,
  );
}

/// No accumulated particle history: seeking to a timestamp gives the same arc.
Offset kineticArc(Offset from, Offset to, double progress, double maxHeight) {
  final p = progress.clamp(0.0, 1.0);
  final height = math.min(maxHeight, 28 + (to - from).distance * .32);
  return Offset.lerp(from, to, p)! - Offset(0, height * 4 * p * (1 - p));
}
