import 'package:flutter/material.dart';

import 'app_activity_indicator.dart';

/// Compact feedback for an operation with no measurable completion percentage.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppActivityIndicator(size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
