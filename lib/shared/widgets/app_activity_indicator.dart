import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/app_ui_theme.dart';

/// Indeterminate waiting feedback, selected by interface style rather than OS.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticsLabel,
    super.key,
  }) : assert(size > 0),
       assert(strokeWidth > 0);

  final double size;
  final double strokeWidth;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget indicator;
    if (reduceMotion) {
      indicator = Icon(
        Icons.hourglass_empty_rounded,
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      );
    } else if (AppUiTheme.usesCupertino(context)) {
      indicator = CupertinoActivityIndicator(radius: size / 2, color: color);
    } else {
      indicator = SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: color,
        ),
      );
    }
    return Semantics(
      label:
          semanticsLabel ??
          AppI18n.tByLocaleCode(
            Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
            'home.loading',
          ),
      child: ExcludeSemantics(
        child: SizedBox.square(dimension: size, child: indicator),
      ),
    );
  }
}
