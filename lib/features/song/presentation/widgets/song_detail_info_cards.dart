import 'package:flutter/material.dart';

import '../../domain/entities/song_detail_field.dart';

class SongDetailInfoCards extends StatelessWidget {
  const SongDetailInfoCards({
    required this.source,
    required this.duration,
    required this.fields,
    required this.sourceLabel,
    required this.durationLabel,
    super.key,
  });

  final String source;
  final String duration;
  final List<SongDetailField> fields;
  final String sourceLabel;
  final String durationLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _InfoCardRows(
        key: const ValueKey<String>('song-detail-meta-compact'),
        maxColumns: 2,
        children: <Widget>[
          _InfoCard(
            key: const ValueKey<String>('song-detail-source-card'),
            label: sourceLabel,
            value: source.isEmpty ? '-' : source,
          ),
          _InfoCard(
            key: const ValueKey<String>('song-detail-duration-card'),
            label: durationLabel,
            value: duration,
          ),
        ],
      ),
      if (fields.isNotEmpty) ...<Widget>[
        const SizedBox(height: 10),
        _InfoCardRows(
          key: const ValueKey<String>('song-detail-fields'),
          children: <Widget>[
            for (var index = 0; index < fields.length; index++)
              _InfoCard(
                key: ValueKey<String>('song-detail-field-$index'),
                label: fields[index].label,
                value: fields[index].value,
              ),
          ],
        ),
      ],
    ],
  );
}

class _InfoCardRows extends StatelessWidget {
  const _InfoCardRows({required this.children, this.maxColumns = 4, super.key});

  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      // 让大字体也参与列数计算，避免窄卡片挤压文字。
      final minWidth = 130 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + spacing) / (minWidth + spacing))
          .floor()
          .clamp(1, maxColumns);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
