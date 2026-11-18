import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../skin/app_skin_models.dart';
import '../skin/app_skin_theme.dart';

/// Player-only sheet material. It currently follows the selected application
/// skin, while keeping its own painting and tuning independent of app sheets.
class PlayerSheetMaterial extends StatelessWidget {
  const PlayerSheetMaterial({
    required this.backgroundColor,
    required this.child,
    this.decorationTop = 0,
    super.key,
  });

  final Color backgroundColor;
  final double decorationTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = theme.extension<AppSkinTheme>()?.config;
    final colors = config?.colorScheme ?? theme.colorScheme;
    final background = backgroundColor.withValues(alpha: 1);
    return ColoredBox(
      color: background,
      child: Stack(
        children: [
          Positioned.fill(
            top: decorationTop,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                height: 168,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('player-sheet-decoration'),
                        painter: config?.background.wallpaper.descriptor == null
                            ? null
                            : _PlayerSheetDecorationPainter(
                                background: background,
                                primary: colors.primary,
                                secondary: colors.secondary,
                                motif: config!.sheetMotif,
                                dark: colors.brightness == Brightness.dark,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PlayerSheetDecorationPainter extends CustomPainter {
  const _PlayerSheetDecorationPainter({
    required this.background,
    required this.primary,
    required this.secondary,
    required this.motif,
    required this.dark,
  });

  final Color background;
  final Color primary;
  final Color secondary;
  final AppSkinSheetMotif motif;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final height = math.min(size.height, 168.0);
    final bounds = Rect.fromLTWH(0, 0, size.width, height);
    canvas.save();
    canvas.clipRect(bounds);
    // Fade at both ends: the SDK drag handle above and the long list below
    // retain the same solid base color, with no visible seam.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background,
            Color.alphaBlend(
              primary.withValues(alpha: dark ? 0.08 : 0.06),
              background,
            ),
            background,
          ],
          stops: const [0, 0.35, 1],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, 0),
          radius: 0.48,
          colors: [
            secondary.withValues(alpha: dark ? 0.09 : 0.07),
            secondary.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    if (motif == AppSkinSheetMotif.woodland) {
      // Keep the motif at the edge; the center remains a quiet reading area.
      final extent = math.min(size.width * 0.24, 96.0);
      canvas.translate(size.width + extent * 0.12, 12);
      canvas.rotate(0.28);
      final ink = Paint()
        ..color = primary.withValues(alpha: dark ? 0.10 : 0.08);
      final stem = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          -extent * 0.65,
          extent * 0.45,
          -extent * 0.26,
          extent * 1.35,
        );
      canvas.drawPath(
        stem,
        Paint()
          ..color = ink.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      for (var index = 0; index < 4; index++) {
        final y = extent * (0.2 + index * 0.26);
        final x = -extent * (index == 0 ? 0.2 : 0.35);
        for (final side in [-1.0, 1.0]) {
          final leaf = Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(
              x + side * extent * 0.22,
              y - extent * 0.3,
              x + side * extent * 0.43,
              y - extent * 0.16,
            )
            ..quadraticBezierTo(
              x + side * extent * 0.3,
              y + extent * 0.08,
              x,
              y,
            )
            ..close();
          canvas.drawPath(leaf, ink);
        }
      }
    }
    if (motif == AppSkinSheetMotif.starlit) _paintStarlit(canvas, size);
    if (motif == AppSkinSheetMotif.urban) _paintUrban(canvas, size);
    if (motif == AppSkinSheetMotif.tidal) _paintTidal(canvas, size);
    canvas.restore();
  }

  void _paintStarlit(Canvas canvas, Size size) {
    final edge = math.min(size.width * 0.32, 124.0);
    final ink = (dark ? secondary : primary).withValues(
      alpha: dark ? 0.18 : 0.12,
    );
    final orbit = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final radius in [edge * 0.72, edge]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width + 20, 8), radius: radius),
        math.pi * 0.48,
        math.pi * 0.58,
        false,
        orbit,
      );
    }
    final dots = Paint()..color = ink;
    for (final point in const [
      Offset(0.22, 32),
      Offset(0.68, 54),
      Offset(0.42, 104),
      Offset(0.88, 122),
      Offset(0.12, 142),
    ]) {
      canvas.drawCircle(
        Offset(size.width - edge * point.dx, point.dy),
        1.3,
        dots,
      );
    }
    final center = Offset(size.width - edge * 0.7, 88);
    final star = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..quadraticBezierTo(
        center.dx + 1,
        center.dy - 1,
        center.dx + 4,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 1,
        center.dy + 1,
        center.dx,
        center.dy + 5,
      )
      ..quadraticBezierTo(
        center.dx - 1,
        center.dy + 1,
        center.dx - 4,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - 1,
        center.dy - 1,
        center.dx,
        center.dy - 5,
      )
      ..close();
    canvas.drawPath(star, dots);
  }

  void _paintTidal(Canvas canvas, Size size) {
    final edge = math.min(size.width * 0.28, 106.0);
    final current = Paint()
      ..color = primary.withValues(alpha: dark ? 0.15 : 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    for (var index = 0; index < 3; index++) {
      final y = 38.0 + index * 23;
      canvas.drawPath(
        Path()
          ..moveTo(size.width - edge, y)
          ..cubicTo(
            size.width - edge * 0.58,
            y - 18,
            size.width - edge * 0.28,
            y + 22,
            size.width + 6,
            y - 3,
          ),
        current,
      );
    }
    final pearl = Paint()
      ..color = secondary.withValues(alpha: dark ? 0.17 : 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final point in const [
      Offset(0.20, 26),
      Offset(0.62, 108),
      Offset(0.36, 88),
    ]) {
      canvas.drawCircle(
        Offset(size.width - edge * point.dx, point.dy),
        3,
        pearl,
      );
    }
  }

  void _paintUrban(Canvas canvas, Size size) {
    final edge = math.min(size.width * 0.26, 104.0);
    final left = size.width - edge;
    final light = Paint()
      ..color = secondary.withValues(alpha: dark ? 0.065 : 0.045);
    final frame = Paint()
      ..color = primary.withValues(alpha: dark ? 0.085 : 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    // Slanted panes echo the studio window, rather than adding a city skyline.
    for (var column = 0; column < 2; column++) {
      final x = left + column * edge * 0.52;
      final pane = Path()
        ..moveTo(x + 16, 16)
        ..lineTo(x + edge * 0.45, 24)
        ..lineTo(x + edge * 0.45 - 16, 130)
        ..lineTo(x, 114)
        ..close();
      canvas.drawPath(pane, light);
      canvas.drawPath(pane, frame);
      canvas.drawLine(
        Offset(x + 8, 66),
        Offset(x + edge * 0.45 - 8, 78),
        frame,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerSheetDecorationPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.motif != motif ||
      oldDelegate.dark != dark;
}
