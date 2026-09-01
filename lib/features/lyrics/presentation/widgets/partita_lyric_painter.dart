import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/monet_lyric_layout.dart';
import '../helpers/partita_lyric_layout.dart';
import 'monet_lyric_painter.dart' show resolveMonetTokenClipRects;

@immutable
class PartitaTokenPaintData {
  const PartitaTokenPaintData({required this.token, required this.boxes});

  final MonetDisplayToken token;
  final List<Rect> boxes;
}

@immutable
class PartitaLyricPaintLine {
  const PartitaLyricPaintLine({
    required this.positioned,
    required this.mainPainter,
    required this.accentPainter,
    required this.glowPainter,
    required this.auxiliaryPainter,
    required this.tokens,
  });

  final PartitaPositionedLyricLine positioned;
  final TextPainter mainPainter;
  final TextPainter? accentPainter;
  final TextPainter? glowPainter;
  final TextPainter? auxiliaryPainter;
  final List<PartitaTokenPaintData> tokens;
}

@immutable
class PartitaLyricRenderData {
  const PartitaLyricRenderData({
    required this.size,
    required this.lines,
    required this.timelineOffset,
    required this.textDirection,
    required this.palette,
  });

  final Size size;
  final List<PartitaLyricPaintLine> lines;
  final Duration timelineOffset;
  final TextDirection textDirection;
  final PlayerScenePalette palette;
}

PartitaLyricRenderData buildPartitaLyricRenderData({
  required List<PartitaPositionedLyricLine> positionedLines,
  required PartitaLyricLayoutOptions options,
  required PlayerScenePalette palette,
  required bool enableWordByWordLyric,
  required Duration timelineOffset,
}) {
  final lines = positionedLines
      .map((positioned) {
        final entry = positioned.entry;
        final isActive = entry.status == MonetLyricLineStatus.active;
        final distance = entry.offset.abs().clamp(1, 4);
        final opacity = isActive
            ? 1.0
            : entry.status == MonetLyricLineStatus.waiting
            ? (0.66 - (distance - 1) * 0.10).clamp(0.34, 0.66)
            : (0.50 - (distance - 1) * 0.07).clamp(0.29, 0.50);
        final style =
            (isActive ? options.activeTextStyle : options.inactiveTextStyle)
                .copyWith(
                  color: isActive
                      ? palette.foreground.withValues(alpha: 0.98)
                      : palette.secondaryForeground.withValues(alpha: opacity),
                );
        final displayTokens = isActive && enableWordByWordLyric
            ? buildPartitaDisplayTokens(entry.line)
            : const <MonetDisplayToken>[];
        final hasTimedTokens = displayTokens.any((token) => token.hasTiming);
        final mainPainter = _layoutPainter(
          text: entry.line.text,
          style: hasTimedTokens
              ? style.copyWith(
                  color: palette.foreground.withValues(alpha: 0.46),
                )
              : style,
          options: options,
          maxWidth: positioned.measurement.layoutWidth,
          maxLines: isActive ? null : options.inactiveMaxLines.clamp(1, 1000),
          ellipsis: isActive ? null : '\u2026',
        );
        final accentPainter = hasTimedTokens
            ? _layoutPainter(
                text: entry.line.text,
                style: style.copyWith(color: palette.accent, shadows: const []),
                options: options,
                maxWidth: positioned.measurement.layoutWidth,
              )
            : null;
        final glowPainter = hasTimedTokens
            ? _layoutPainter(
                text: entry.line.text,
                style: style.copyWith(
                  color: Color.lerp(
                    palette.accent,
                    palette.edge,
                    0.45,
                  )!.withValues(alpha: 0.34),
                  shadows: const [],
                ),
                options: options,
                maxWidth: positioned.measurement.layoutWidth,
              )
            : null;
        final tokens = accentPainter == null
            ? const <PartitaTokenPaintData>[]
            : displayTokens
                  .map((token) {
                    if (!token.hasTiming ||
                        token.endOffset <= token.startOffset) {
                      return PartitaTokenPaintData(
                        token: token,
                        boxes: const <Rect>[],
                      );
                    }
                    final boxes = mainPainter
                        .getBoxesForSelection(
                          TextSelection(
                            baseOffset: token.startOffset,
                            extentOffset: token.endOffset,
                          ),
                          boxHeightStyle: ui.BoxHeightStyle.tight,
                          boxWidthStyle: ui.BoxWidthStyle.tight,
                        )
                        .map((box) => box.toRect())
                        .where((box) => box.width > 0 && box.height > 0)
                        .toList(growable: false);
                    return PartitaTokenPaintData(
                      token: token,
                      boxes: List<Rect>.unmodifiable(boxes),
                    );
                  })
                  .toList(growable: false);
        final auxiliaryText = positioned.measurement.auxiliaryText;
        final auxiliaryPainter = auxiliaryText == null
            ? null
            : _layoutPainter(
                text: auxiliaryText,
                style: options.auxiliaryTextStyle.copyWith(
                  color: palette.secondaryForeground.withValues(alpha: 0.82),
                ),
                options: options,
                maxWidth: positioned.measurement.layoutWidth,
              );
        return PartitaLyricPaintLine(
          positioned: positioned,
          mainPainter: mainPainter,
          accentPainter: accentPainter,
          glowPainter: glowPainter,
          auxiliaryPainter: auxiliaryPainter,
          tokens: List<PartitaTokenPaintData>.unmodifiable(tokens),
        );
      })
      .toList(growable: false);

  return PartitaLyricRenderData(
    size: options.railSize,
    lines: List<PartitaLyricPaintLine>.unmodifiable(lines),
    timelineOffset: timelineOffset,
    textDirection: options.textDirection,
    palette: palette,
  );
}

TextPainter _layoutPainter({
  required String text,
  required TextStyle style,
  required PartitaLyricLayoutOptions options,
  required double maxWidth,
  int? maxLines,
  String? ellipsis,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: options.textDirection,
    textAlign: TextAlign.left,
    textScaler: TextScaler.linear(options.textScaleFactor),
    maxLines: maxLines,
    ellipsis: ellipsis,
  )..layout(maxWidth: maxWidth);
}

@immutable
class PartitaGuideSegment {
  const PartitaGuideSegment(this.start, this.end);

  final Offset start;
  final Offset end;
}

@visibleForTesting
List<PartitaGuideSegment> resolvePartitaGuideSegments({
  required Rect textRect,
  required Rect bounds,
  required double progress,
}) {
  if (textRect.isEmpty || bounds.isEmpty || progress <= 0) {
    return const <PartitaGuideSegment>[];
  }
  final resolvedProgress = progress.clamp(0.0, 1.0);
  const gap = 9.0;
  final arm = math.min(16.0, math.max(textRect.width * 0.12, 9.0));
  final vertical = math.min(30.0, math.max(textRect.height * 0.48, 16.0));
  final centerY = textRect.center.dy;
  final leftX = (textRect.left - gap).clamp(bounds.left, bounds.right);
  final rightX = (textRect.right + gap).clamp(bounds.left, bounds.right);
  final top = (centerY - vertical / 2).clamp(bounds.top, bounds.bottom);
  final bottom = (centerY + vertical / 2).clamp(bounds.top, bounds.bottom);
  final leftEnd = (leftX - arm * resolvedProgress).clamp(
    bounds.left,
    bounds.right,
  );
  final rightEnd = (rightX + arm * resolvedProgress).clamp(
    bounds.left,
    bounds.right,
  );
  return <PartitaGuideSegment>[
    PartitaGuideSegment(Offset(leftX, centerY), Offset(leftX, bottom)),
    PartitaGuideSegment(Offset(leftX, bottom), Offset(leftEnd, bottom)),
    PartitaGuideSegment(Offset(rightX, centerY), Offset(rightX, top)),
    PartitaGuideSegment(Offset(rightX, top), Offset(rightEnd, top)),
  ];
}

class PartitaLyricPainter extends CustomPainter {
  PartitaLyricPainter({
    required this.data,
    required this.previousData,
    required this.position,
    required this.transition,
    required this.breathing,
    this.onPaint,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           position,
           transition,
           breathing,
         ]),
       );

  final PartitaLyricRenderData data;
  final PartitaLyricRenderData? previousData;
  final ValueListenable<Duration> position;
  final Animation<double> transition;
  final Animation<double> breathing;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final timelinePosition = position.value + data.timelineOffset;
    final transitionValue = Curves.easeOutCubic.transform(transition.value);
    for (final line in data.lines) {
      _paintLine(
        canvas,
        line,
        _previousLineFor(line),
        timelinePosition,
        transitionValue,
        Offset.zero & size,
      );
    }
    canvas.restore();
  }

  PartitaLyricPaintLine? _previousLineFor(PartitaLyricPaintLine line) {
    final previous = previousData;
    if (previous == null) return null;
    for (final candidate in previous.lines) {
      if (candidate.positioned.entry.key == line.positioned.entry.key) {
        return candidate;
      }
    }
    return null;
  }

  void _paintLine(
    Canvas canvas,
    PartitaLyricPaintLine line,
    PartitaLyricPaintLine? previousLine,
    Duration timelinePosition,
    double transitionValue,
    Rect bounds,
  ) {
    final positioned = line.positioned;
    final previousRect = previousLine?.positioned.rect;
    final fallbackShift = Offset(
      positioned.entry.offset.isEven ? -18 : 18,
      positioned.entry.offset >= 0 ? 18 : -18,
    );
    final startRect = previousRect ?? positioned.rect.shift(fallbackShift);
    final paintedLeft = ui.lerpDouble(
      startRect.left,
      positioned.rect.left,
      transitionValue,
    )!;
    final paintedTop = ui.lerpDouble(
      startRect.top,
      positioned.rect.top,
      transitionValue,
    )!;
    final shift = Offset(
      paintedLeft - positioned.rect.left,
      paintedTop - positioned.rect.top,
    );
    final isActive = positioned.entry.status == MonetLyricLineStatus.active;
    final breath = isActive ? math.sin(breathing.value * math.pi * 2) : 0.0;
    final breathScale = 1 + breath * 0.006;
    final breathShift = Offset(0, breath * 1.4);
    final currentFontSize = _fontSize(line.mainPainter);
    final previousFontSize = previousLine == null
        ? currentFontSize
        : _fontSize(previousLine.mainPainter);
    final transitionScale = ui.lerpDouble(
      previousFontSize / math.max(currentFontSize, 1),
      1,
      transitionValue,
    )!;
    final transformScale = transitionScale * breathScale;
    final paintedRect = positioned.rect.shift(shift + breathShift);

    canvas.save();
    canvas.translate(paintedRect.center.dx, paintedRect.center.dy);
    canvas.scale(transformScale, transformScale);
    canvas.translate(-paintedRect.center.dx, -paintedRect.center.dy);

    if (isActive) {
      _paintGuides(canvas, paintedRect, bounds, transitionValue);
    }
    final mainOrigin =
        positioned.rect.topLeft +
        positioned.measurement.mainTextOffset +
        shift +
        breathShift;
    line.mainPainter.paint(canvas, mainOrigin);
    _paintTimedAccent(canvas, line, timelinePosition, mainOrigin);

    final auxiliaryOffset = positioned.measurement.auxiliaryOffset;
    if (line.auxiliaryPainter != null && auxiliaryOffset != null) {
      line.auxiliaryPainter!.paint(
        canvas,
        positioned.rect.topLeft + auxiliaryOffset + shift + breathShift,
      );
    }
    canvas.restore();
  }

  void _paintGuides(
    Canvas canvas,
    Rect textRect,
    Rect bounds,
    double progress,
  ) {
    final segments = resolvePartitaGuideSegments(
      textRect: textRect,
      bounds: bounds,
      progress: progress,
    );
    final paint = Paint()
      ..color = Color.lerp(
        data.palette.edge,
        data.palette.accent,
        0.35,
      )!.withValues(alpha: 0.72 * progress)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final segment in segments) {
      canvas.drawLine(segment.start, segment.end, paint);
    }
  }

  void _paintTimedAccent(
    Canvas canvas,
    PartitaLyricPaintLine line,
    Duration timelinePosition,
    Offset origin,
  ) {
    final accentPainter = line.accentPainter;
    if (accentPainter == null) return;
    final revealed = <Rect>[];
    final current = <Rect>[];
    for (final tokenData in line.tokens) {
      if (tokenData.boxes.isEmpty || !tokenData.token.hasTiming) continue;
      final progress = resolveMonetTokenProgress(
        timelinePosition: timelinePosition,
        token: tokenData.token,
      );
      final clips = resolveMonetTokenClipRects(
        boxes: tokenData.boxes,
        progress: progress,
        textDirection: data.textDirection,
      );
      revealed.addAll(clips);
      if (progress > 0 && progress < 1) current.addAll(clips);
    }
    if (current.isNotEmpty && line.glowPainter != null) {
      final shifted = current.map((clip) => clip.shift(origin)).toList();
      final glowBounds = shifted
          .skip(1)
          .fold<Rect>(
            shifted.first,
            (value, clip) => value.expandToInclude(clip),
          )
          .inflate(7);
      final path = Path();
      for (final clip in shifted) {
        path.addRect(clip);
      }
      canvas.saveLayer(
        glowBounds,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
      );
      canvas.clipPath(path);
      line.glowPainter!.paint(canvas, origin);
      canvas.restore();
    }
    if (revealed.isEmpty) return;
    final path = Path();
    for (final clip in revealed) {
      path.addRect(clip.shift(origin));
    }
    canvas.save();
    canvas.clipPath(path);
    accentPainter.paint(canvas, origin);
    canvas.restore();
  }

  double _fontSize(TextPainter painter) {
    final text = painter.text;
    return text is TextSpan ? text.style?.fontSize ?? 1 : 1;
  }

  @override
  bool shouldRepaint(covariant PartitaLyricPainter oldDelegate) {
    return !identical(data, oldDelegate.data) ||
        !identical(previousData, oldDelegate.previousData) ||
        !identical(position, oldDelegate.position) ||
        !identical(transition, oldDelegate.transition) ||
        !identical(breathing, oldDelegate.breathing);
  }
}
