import 'package:flutter/material.dart';

import 'app_skin_models.dart';
import 'app_skin_theme.dart';

class AppSkinControlTexture extends StatelessWidget {
  const AppSkinControlTexture({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final woodland =
        theme.extension<AppSkinTheme>()?.config.visualStyle ==
        AppSkinVisualStyle.woodland;
    return CustomPaint(
      foregroundPainter: woodland
          ? WoodlandSurfacePainter(
              color: theme.colorScheme.secondary,
              compact: true,
            )
          : null,
      child: child,
    );
  }
}

/// 叶脉是控件材质的一部分，静态绘制，不参与环境动画时钟。
class WoodlandSurfacePainter extends CustomPainter {
  const WoodlandSurfacePainter({required this.color, required this.compact});
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = (compact ? size.height * .5 : 84.0).clamp(24.0, 100.0);
    canvas.save();
    canvas.translate(size.width - extent * .58, size.height + extent * .18);
    canvas.rotate(-.65);
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        -extent * .1,
        -extent * .6,
        extent * .18,
        -extent * 1.3,
      );
    final ink = Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(stem, ink);
    for (var i = 1; i < 5; i++) {
      final y = -extent * i * .23;
      for (final side in [-1.0, 1.0]) {
        final leaf = Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(
            side * extent * .3,
            y + extent * .04,
            side * extent * .36,
            y - extent * .26,
          )
          ..quadraticBezierTo(side * extent * .06, y - extent * .31, 0, y)
          ..close();
        canvas.drawPath(leaf, Paint()..color = color.withValues(alpha: .09));
        canvas.drawPath(leaf, ink);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WoodlandSurfacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.compact != compact;
}
