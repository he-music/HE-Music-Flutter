import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/monet_lyric_layout.dart';

@immutable
class MonetTokenPaintData {
  const MonetTokenPaintData({required this.token, required this.boxes});

  final MonetDisplayToken token;
  final List<Rect> boxes;
}

@immutable
class MonetLyricPaintLine {
  const MonetLyricPaintLine({
    required this.positioned,
    required this.mainPainter,
    required this.accentPainter,
    required this.glowPainter,
    required this.translationPainter,
    required this.tokens,
  });

  final MonetPositionedLyricLine positioned;
  final TextPainter mainPainter;
  final TextPainter? accentPainter;
  final TextPainter? glowPainter;
  final TextPainter? translationPainter;
  final List<MonetTokenPaintData> tokens;
}

@immutable
class MonetLyricRenderData {
  const MonetLyricRenderData({
    required this.size,
    required this.lines,
    required this.timelineOffset,
    required this.textDirection,
  });

  final Size size;
  final List<MonetLyricPaintLine> lines;
  final Duration timelineOffset;
  final TextDirection textDirection;
}

MonetLyricRenderData buildMonetLyricRenderData({
  required List<MonetPositionedLyricLine> positionedLines,
  required MonetLyricLayoutOptions options,
  required PlayerScenePalette palette,
  required bool enableWordByWordLyric,
  required Duration timelineOffset,
}) {
  final contentWidth = (options.railSize.width - options.horizontalPadding * 2)
      .clamp(0.0, double.infinity);
  final lines = positionedLines
      .map((positioned) {
        final entry = positioned.entry;
        final isActive = entry.status == MonetLyricLineStatus.active;
        final distance = entry.offset.abs().clamp(1, 4);
        final opacity = isActive
            ? 1.0
            : entry.status == MonetLyricLineStatus.waiting
            ? (0.68 - (distance - 1) * 0.13).clamp(0.26, 0.68)
            : (0.48 - (distance - 1) * 0.09).clamp(0.22, 0.48);
        final baseStyle =
            (isActive ? options.activeTextStyle : options.inactiveTextStyle)
                .copyWith(
                  color: isActive
                      ? palette.foreground.withValues(alpha: 0.98)
                      : palette.secondaryForeground.withValues(alpha: opacity),
                );
        final displayTokens = isActive && enableWordByWordLyric
            ? buildMonetDisplayTokens(entry.line)
            : const <MonetDisplayToken>[];
        final hasTimedTokens = displayTokens.any((token) => token.hasTiming);
        final mainPainter = _layoutPainter(
          text: entry.line.text,
          style: hasTimedTokens
              ? baseStyle.copyWith(
                  color: palette.foreground.withValues(alpha: 0.34),
                )
              : baseStyle,
          options: options,
          maxWidth: contentWidth,
          maxLines: isActive ? null : options.inactiveMaxLines.clamp(1, 1000),
          ellipsis: isActive ? null : '\u2026',
        );
        final accentPainter = hasTimedTokens
            ? _layoutPainter(
                text: entry.line.text,
                style: baseStyle.copyWith(
                  color: palette.accent,
                  shadows: const <Shadow>[],
                ),
                options: options,
                maxWidth: contentWidth,
              )
            : null;
        final glowPainter = hasTimedTokens
            ? _layoutPainter(
                text: entry.line.text,
                style: baseStyle.copyWith(
                  color: Color.lerp(
                    palette.accent,
                    palette.edge,
                    0.35,
                  )!.withValues(alpha: 0.38),
                  shadows: const <Shadow>[],
                ),
                options: options,
                maxWidth: contentWidth,
              )
            : null;
        final tokenPaintData = accentPainter == null
            ? const <MonetTokenPaintData>[]
            : displayTokens
                  .map((token) {
                    if (!token.hasTiming ||
                        token.endOffset <= token.startOffset) {
                      return MonetTokenPaintData(
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
                        .where((rect) => rect.width > 0 && rect.height > 0)
                        .toList(growable: false);
                    return MonetTokenPaintData(
                      token: token,
                      boxes: List<Rect>.unmodifiable(boxes),
                    );
                  })
                  .toList(growable: false);
        final translationText = positioned.measurement.translationText;
        final translationPainter = translationText == null
            ? null
            : _layoutPainter(
                text: translationText,
                style: options.translationTextStyle.copyWith(
                  color: palette.secondaryForeground.withValues(alpha: 0.78),
                ),
                options: options,
                maxWidth: contentWidth,
              );
        return MonetLyricPaintLine(
          positioned: positioned,
          mainPainter: mainPainter,
          accentPainter: accentPainter,
          glowPainter: glowPainter,
          translationPainter: translationPainter,
          tokens: List<MonetTokenPaintData>.unmodifiable(tokenPaintData),
        );
      })
      .toList(growable: false);

  return MonetLyricRenderData(
    size: options.railSize,
    lines: List<MonetLyricPaintLine>.unmodifiable(lines),
    timelineOffset: timelineOffset,
    textDirection: options.textDirection,
  );
}

TextPainter _layoutPainter({
  required String text,
  required TextStyle style,
  required MonetLyricLayoutOptions options,
  required double maxWidth,
  int? maxLines,
  String? ellipsis,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: options.textDirection,
    textAlign: options.textAlign,
    textScaler: TextScaler.linear(options.textScaleFactor),
    maxLines: maxLines,
    ellipsis: ellipsis,
  )..layout(maxWidth: maxWidth);
}

List<Rect> resolveMonetTokenClipRects({
  required List<Rect> boxes,
  required double progress,
  required TextDirection textDirection,
}) {
  if (boxes.isEmpty || progress <= 0) {
    return const <Rect>[];
  }
  if (progress >= 1) {
    return List<Rect>.unmodifiable(boxes);
  }
  final totalWidth = boxes.fold<double>(0, (sum, box) => sum + box.width);
  var remaining = totalWidth * progress.clamp(0.0, 1.0);
  final clips = <Rect>[];
  for (final box in boxes) {
    if (remaining <= 0) {
      break;
    }
    final width = remaining.clamp(0.0, box.width);
    clips.add(
      textDirection == TextDirection.rtl
          ? Rect.fromLTRB(box.right - width, box.top, box.right, box.bottom)
          : Rect.fromLTWH(box.left, box.top, width, box.height),
    );
    remaining -= box.width;
  }
  return List<Rect>.unmodifiable(clips);
}

@visibleForTesting
double resolveMonetLineTransitionScale({
  required double currentFontSize,
  required double? previousFontSize,
  required double transitionValue,
}) {
  final current = currentFontSize.isFinite && currentFontSize > 0
      ? currentFontSize
      : 1.0;
  final previous =
      previousFontSize != null &&
          previousFontSize.isFinite &&
          previousFontSize > 0
      ? previousFontSize
      : current;
  final progress = transitionValue.isFinite
      ? transitionValue.clamp(0.0, 1.0)
      : 1.0;
  return ui.lerpDouble(previous / current, 1.0, progress)!;
}

double _fontSize(TextPainter painter) {
  final span = painter.text;
  return span is TextSpan && span.style?.fontSize != null
      ? span.style!.fontSize!
      : 1.0;
}

class MonetLyricPainter extends CustomPainter {
  MonetLyricPainter({
    required this.data,
    required this.previousData,
    required this.position,
    required this.transition,
    this.onPaint,
  }) : super(repaint: Listenable.merge(<Listenable>[position, transition]));

  final MonetLyricRenderData data;
  final MonetLyricRenderData? previousData;
  final ValueListenable<Duration> position;
  final Animation<double> transition;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final timelinePosition = position.value + data.timelineOffset;
    final animationValue = Curves.easeOutCubic.transform(transition.value);
    for (final line in data.lines) {
      final previousLine = _previousLineFor(line);
      _paintLine(
        canvas,
        line,
        timelinePosition,
        animationValue,
        previousLine?.positioned.rect.top,
        previousLine,
      );
    }
    canvas.restore();
  }

  MonetLyricPaintLine? _previousLineFor(MonetLyricPaintLine line) {
    final previous = previousData;
    if (previous == null) {
      return null;
    }
    for (final candidate in previous.lines) {
      if (candidate.positioned.entry.key == line.positioned.entry.key) {
        return candidate;
      }
    }
    return null;
  }

  void _paintLine(
    Canvas canvas,
    MonetLyricPaintLine line,
    Duration timelinePosition,
    double transitionValue,
    double? previousTop,
    MonetLyricPaintLine? previousLine,
  ) {
    final positioned = line.positioned;
    final currentTop = positioned.rect.top;
    final entryOffset = positioned.entry.offset >= 0 ? 24.0 : -24.0;
    final startTop = previousTop ?? currentTop + entryOffset;
    final paintedTop = ui.lerpDouble(startTop, currentTop, transitionValue)!;
    final shift = paintedTop - currentTop;
    final mainOrigin =
        positioned.rect.topLeft +
        positioned.measurement.mainTextOffset +
        Offset(0, shift);

    final currentFontSize = _fontSize(line.mainPainter);
    final previousFontSize = previousLine == null
        ? null
        : _fontSize(previousLine.mainPainter);
    final lineScale = resolveMonetLineTransitionScale(
      currentFontSize: currentFontSize,
      previousFontSize: previousFontSize,
      transitionValue: transitionValue,
    );
    // Keep the left edge fixed so Monet text grows toward the right.
    final transformOrigin = mainOrigin;
    canvas.save();
    canvas.translate(transformOrigin.dx, transformOrigin.dy);
    canvas.scale(lineScale, lineScale);
    canvas.translate(-transformOrigin.dx, -transformOrigin.dy);
    line.mainPainter.paint(canvas, mainOrigin);
    final accentPainter = line.accentPainter;
    if (accentPainter != null) {
      final revealedClips = <Rect>[];
      final glowClips = <Rect>[];
      for (final tokenData in line.tokens) {
        if (tokenData.boxes.isEmpty || !tokenData.token.hasTiming) {
          continue;
        }
        final progress = resolveMonetTokenProgress(
          timelinePosition: timelinePosition,
          token: tokenData.token,
        );
        final clips = resolveMonetTokenClipRects(
          boxes: tokenData.boxes,
          progress: progress,
          textDirection: data.textDirection,
        );
        revealedClips.addAll(clips);
        if (progress > 0 && progress < 1) {
          glowClips.addAll(clips);
        }
      }
      if (glowClips.isNotEmpty && line.glowPainter != null) {
        _paintTokenGlow(canvas, line.glowPainter!, glowClips, mainOrigin);
      }
      if (revealedClips.isNotEmpty) {
        final clipPath = Path();
        for (final clip in revealedClips) {
          clipPath.addRect(clip.shift(mainOrigin));
        }
        canvas.save();
        canvas.clipPath(clipPath);
        accentPainter.paint(canvas, mainOrigin);
        canvas.restore();
      }
    }

    final translationPainter = line.translationPainter;
    final translationOffset = positioned.measurement.translationOffset;
    if (translationPainter != null && translationOffset != null) {
      translationPainter.paint(
        canvas,
        positioned.rect.topLeft + translationOffset + Offset(0, shift),
      );
    }
    canvas.restore();
  }

  // Blur an isolated revealed glyph mask so the glow can extend beyond the clip.
  void _paintTokenGlow(
    Canvas canvas,
    TextPainter accentPainter,
    List<Rect> clips,
    Offset origin,
  ) {
    final shiftedClips = clips
        .map((clip) => clip.shift(origin))
        .toList(growable: false);
    final glowBounds = shiftedClips
        .skip(1)
        .fold<Rect>(shiftedClips.first, (bounds, clip) {
          return bounds.expandToInclude(clip);
        })
        .inflate(8);
    final clipPath = Path();
    for (final clip in shiftedClips) {
      clipPath.addRect(clip);
    }
    canvas.saveLayer(
      glowBounds,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
    );
    canvas.clipPath(clipPath);
    accentPainter.paint(canvas, origin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MonetLyricPainter oldDelegate) {
    return !identical(data, oldDelegate.data) ||
        !identical(previousData, oldDelegate.previousData) ||
        !identical(position, oldDelegate.position) ||
        !identical(transition, oldDelegate.transition);
  }
}
