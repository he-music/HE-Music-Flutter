import 'package:flutter/material.dart';

class UnderlineTab extends StatelessWidget {
  const UnderlineTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final normal = theme.textTheme.bodyMedium?.color;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: !enabled
                    ? theme.hintColor.withValues(alpha: 0.55)
                    : (selected ? primary : normal),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 22 : 0,
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: enabled ? primary : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
