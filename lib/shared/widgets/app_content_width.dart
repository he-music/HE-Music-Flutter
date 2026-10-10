import 'package:flutter/material.dart';

import '../constants/layout_tokens.dart';

/// Keep content centered on desktop while retaining the full mobile viewport.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    required this.child,
    this.maxWidth = LayoutTokens.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
