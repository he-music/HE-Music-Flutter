import 'package:flutter/material.dart';

import '../constants/layout_tokens.dart';

import 'package:flutter/cupertino.dart';
import '../../app/theme/app_ui_theme.dart';

class UnderlineTab extends StatelessWidget {
  const UnderlineTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.prominent = false,
    this.minHeight = LayoutTokens.controlMinExtent,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool prominent;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    if (AppUiTheme.usesCupertino(context)) {
      return Semantics(
        selected: selected,
        enabled: enabled,
        child: CupertinoButton(
          onPressed: enabled ? onTap : null,
          minimumSize: Size(44, minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: selected ? primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: !enabled
                  ? theme.disabledColor
                  : selected
                  ? primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (prominent
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.titleSmall)
                            ?.copyWith(
                              fontWeight: prominent
                                  ? (selected
                                        ? FontWeight.w700
                                        : FontWeight.w500)
                                  : null,
                              color: !enabled
                                  ? theme.hintColor.withValues(alpha: 0.55)
                                  : selected
                                  ? primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
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
          ),
        ),
      ),
    );
  }
}
