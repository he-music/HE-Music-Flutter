import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/player/app_player_scene_palette.dart';
import '../helpers/lyric_painter_owner.dart';
import '../helpers/monet_lyric_layout.dart';

@immutable
class CinemaLyricLayoutOptions {
  const CinemaLyricLayoutOptions({
    required this.size,
    required this.activeStyle,
    required this.inactiveStyle,
    required this.translationStyle,
    required this.textDirection,
    required this.textScaler,
    required this.horizontalPadding,
    required this.lineGap,
    this.locale,
  });

  final Size size;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final TextStyle translationStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final double horizontalPadding;
  final double lineGap;
}

@immutable
class CinemaTokenPaintData {
  const CinemaTokenPaintData({required this.token, required this.boxes});

  final MonetDisplayToken token;
  final List<Rect> boxes;
}

@immutable
class CinemaLyricPaintLine {
  const CinemaLyricPaintLine({
    required this.entry,
    required this.rect,
    required this.hitRect,
    required this.mainOrigin,
    required this.translationOrigin,
    required this.mainPainter,
    required this.accentPainter,
    required this.translationPainter,
    required this.tokens,
  });

  final MonetVisibleLyricLine entry;
  final Rect rect;
  final Rect hitRect;
  final Offset mainOrigin;
  final Offset? translationOrigin;
  final TextPainter mainPainter;
  final TextPainter? accentPainter;
  final TextPainter? translationPainter;
  final List<CinemaTokenPaintData> tokens;
}

@immutable
class CinemaLyricRenderData implements LyricPaintResources {
  const CinemaLyricRenderData({
    required this.size,
    required this.lines,
    required this.timelineOffset,
    required this.textDirection,
  });

  final Size size;
  final List<CinemaLyricPaintLine> lines;
  final Duration timelineOffset;
  final TextDirection textDirection;

  @override
  Iterable<TextPainter> get textPainters sync* {
    for (final line in lines) {
      yield line.mainPainter;
      if (line.accentPainter != null) yield line.accentPainter!;
      if (line.translationPainter != null) yield line.translationPainter!;
    }
  }
}

CinemaLyricRenderData buildCinemaLyricRenderData({
  required List<MonetVisibleLyricLine> entries,
  required CinemaLyricLayoutOptions options,
  required PlayerScenePalette palette,
  required bool enableWordByWordLyric,
  required Duration timelineOffset,
}) {
  final contentWidth = (options.size.width - options.horizontalPadding * 2)
      .clamp(0.0, double.infinity);
  final measured = entries
      .map((entry) {
        final focused = entry.offset == 0;
        final baseStyle =
            (focused ? options.activeStyle : options.inactiveStyle).copyWith(
              color: focused
                  ? palette.foreground.withValues(alpha: 0.42)
                  : palette.secondaryForeground.withValues(
                      alpha: entry.status == MonetLyricLineStatus.passed
                          ? 0.30
                          : 0.46,
                    ),
            );
        final displayTokens = focused && enableWordByWordLyric
            ? buildMonetDisplayTokens(entry.line)
            : const <MonetDisplayToken>[];
        final hasTimedTokens = displayTokens.any((token) => token.hasTiming);
        final mainPainter = _layoutText(
          entry.line.text,
          hasTimedTokens
              ? baseStyle
              : focused
              ? baseStyle.copyWith(color: palette.accent)
              : baseStyle,
          options,
          contentWidth,
          maxLines: focused ? null : 2,
          ellipsis: focused ? null : '\u2026',
        );
        final accentPainter = hasTimedTokens
            ? _layoutText(
                entry.line.text,
                baseStyle.copyWith(
                  color: palette.accent,
                  shadows: <Shadow>[
                    Shadow(
                      color: palette.accent.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ],
                ),
                options,
                contentWidth,
              )
            : null;
        final translation = focused ? _secondaryText(entry) : null;
        final translationPainter = translation == null
            ? null
            : _layoutText(
                translation,
                options.translationStyle.copyWith(
                  color: palette.secondaryForeground.withValues(alpha: 0.82),
                ),
                options,
                contentWidth,
              );
        final translationGap = translationPainter == null ? 0.0 : 10.0;
        final height =
            mainPainter.height +
            translationGap +
            (translationPainter?.height ?? 0.0);
        final tokenData = accentPainter == null
            ? const <CinemaTokenPaintData>[]
            : displayTokens
                  .map((token) {
                    final boxes = !token.hasTiming
                        ? const <Rect>[]
                        : mainPainter
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
                    return CinemaTokenPaintData(
                      token: token,
                      boxes: List<Rect>.unmodifiable(boxes),
                    );
                  })
                  .toList(growable: false);
        return (
          entry: entry,
          mainPainter: mainPainter,
          accentPainter: accentPainter,
          translationPainter: translationPainter,
          tokenData: tokenData,
          height: height,
          translationGap: translationGap,
        );
      })
      .toList(growable: false);

  final anchorIndex = measured.indexWhere((line) => line.entry.offset == 0);
  final safeAnchorIndex = anchorIndex < 0 ? 0 : anchorIndex;
  final anchorHeight = measured.isEmpty
      ? 0.0
      : measured[safeAnchorIndex].height;
  final desiredCenter =
      options.size.height * (options.size.height < 300 ? 0.48 : 0.54);
  final anchorTop = (desiredCenter - anchorHeight / 2).clamp(
    0.0,
    (options.size.height - anchorHeight).clamp(0.0, double.infinity),
  );
  final tops = List<double>.filled(measured.length, anchorTop);
  for (var index = safeAnchorIndex + 1; index < measured.length; index++) {
    tops[index] =
        tops[index - 1] + measured[index - 1].height + options.lineGap;
  }
  for (var index = safeAnchorIndex - 1; index >= 0; index--) {
    tops[index] = tops[index + 1] - measured[index].height - options.lineGap;
  }

  final bounds = Offset.zero & options.size;
  final lines = List<CinemaLyricPaintLine>.generate(measured.length, (index) {
    final value = measured[index];
    final top = tops[index];
    final rect = Rect.fromLTWH(
      options.horizontalPadding,
      top,
      contentWidth,
      value.height,
    );
    final mainOrigin = Offset(
      (options.size.width - value.mainPainter.width) / 2,
      top,
    );
    final translationOrigin = value.translationPainter == null
        ? null
        : Offset(
            (options.size.width - value.translationPainter!.width) / 2,
            top + value.mainPainter.height + value.translationGap,
          );
    return CinemaLyricPaintLine(
      entry: value.entry,
      rect: rect,
      hitRect: rect.intersect(bounds),
      mainOrigin: mainOrigin,
      translationOrigin: translationOrigin,
      mainPainter: value.mainPainter,
      accentPainter: value.accentPainter,
      translationPainter: value.translationPainter,
      tokens: List<CinemaTokenPaintData>.unmodifiable(value.tokenData),
    );
  }, growable: false);

  return CinemaLyricRenderData(
    size: options.size,
    lines: List<CinemaLyricPaintLine>.unmodifiable(lines),
    timelineOffset: timelineOffset,
    textDirection: options.textDirection,
  );
}

String? _secondaryText(MonetVisibleLyricLine entry) {
  final translation = entry.line.translation.trim();
  if (translation.isNotEmpty) return translation;
  final romanization = entry.line.romanization.trim();
  return romanization.isEmpty ? null : romanization;
}

TextPainter _layoutText(
  String text,
  TextStyle style,
  CinemaLyricLayoutOptions options,
  double maxWidth, {
  int? maxLines,
  String? ellipsis,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: options.textDirection,
    textAlign: TextAlign.center,
    textScaler: options.textScaler,
    locale: options.locale,
    maxLines: maxLines,
    ellipsis: ellipsis,
  )..layout(maxWidth: maxWidth);
}

List<Rect> resolveCinemaTokenClipRects({
  required List<Rect> boxes,
  required double progress,
  required TextDirection textDirection,
}) {
  if (boxes.isEmpty || progress <= 0) return const <Rect>[];
  if (progress >= 1) return List<Rect>.unmodifiable(boxes);
  final totalWidth = boxes.fold<double>(0, (sum, box) => sum + box.width);
  var remaining = totalWidth * progress.clamp(0.0, 1.0);
  final clips = <Rect>[];
  for (final box in boxes) {
    if (remaining <= 0) break;
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

class CinemaLyricPainter extends CustomPainter {
  CinemaLyricPainter({
    required this.data,
    required this.previousData,
    required this.position,
    required this.transition,
    this.onPaint,
  }) : super(repaint: Listenable.merge(<Listenable>[position, transition]));

  final CinemaLyricRenderData data;
  final CinemaLyricRenderData? previousData;
  final ValueListenable<Duration> position;
  final Animation<double> transition;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final progress = Curves.easeOutCubic.transform(transition.value);
    final previous = previousData;
    if (previous != null && progress < 1) {
      _paintData(
        canvas,
        previous,
        opacity: 1 - progress,
        dy: ui.lerpDouble(0, -16, progress)!,
      );
    }
    _paintData(
      canvas,
      data,
      opacity: previous == null ? 1 : progress,
      dy: previous == null ? 0 : ui.lerpDouble(16, 0, progress)!,
    );
    canvas.restore();
  }

  void _paintData(
    Canvas canvas,
    CinemaLyricRenderData renderData, {
    required double opacity,
    required double dy,
  }) {
    if (opacity <= 0) return;
    final timelinePosition = position.value + renderData.timelineOffset;
    if (opacity >= 1) {
      canvas.save();
    } else {
      canvas.saveLayer(
        Offset.zero & renderData.size,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
    canvas.translate(0, dy);
    for (final line in renderData.lines) {
      line.mainPainter.paint(canvas, line.mainOrigin);
      final accentPainter = line.accentPainter;
      if (accentPainter != null) {
        final clipPath = Path();
        for (final tokenData in line.tokens) {
          final tokenProgress = resolveMonetTokenProgress(
            timelinePosition: timelinePosition,
            token: tokenData.token,
          );
          for (final clip in resolveCinemaTokenClipRects(
            boxes: tokenData.boxes,
            progress: tokenProgress,
            textDirection: renderData.textDirection,
          )) {
            clipPath.addRect(clip.shift(line.mainOrigin));
          }
        }
        if (clipPath.getBounds().isEmpty == false) {
          canvas.save();
          canvas.clipPath(clipPath);
          accentPainter.paint(canvas, line.mainOrigin);
          canvas.restore();
        }
      }
      final translationPainter = line.translationPainter;
      final translationOrigin = line.translationOrigin;
      if (translationPainter != null && translationOrigin != null) {
        translationPainter.paint(canvas, translationOrigin);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CinemaLyricPainter oldDelegate) {
    return !identical(data, oldDelegate.data) ||
        !identical(previousData, oldDelegate.previousData) ||
        !identical(position, oldDelegate.position) ||
        !identical(transition, oldDelegate.transition);
  }
}
