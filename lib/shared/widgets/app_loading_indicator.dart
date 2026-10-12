import 'package:flutter/material.dart';

/// Compact feedback for an operation with no measurable completion percentage.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 18,
              child: reduceMotion
                  ? Icon(
                      Icons.hourglass_empty_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
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
