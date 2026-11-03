import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_cupertino_content_section.dart';

/// Optional item backgrounds inside an always-opaque player modal surface.
class PlayerSheetSection extends StatelessWidget {
  const PlayerSheetSection({
    required this.children,
    this.title,
    this.hasLeading = true,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) => AppCupertinoContentSection(
    margin: const EdgeInsets.only(bottom: 12),
    hasLeading: hasLeading,
    header: title == null
        ? null
        : Semantics(
            header: true,
            child: Text(
              title!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
    children: children,
  );
}
