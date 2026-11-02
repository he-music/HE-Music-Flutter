import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_sheet_header.dart';
import '../../domain/entities/player_quality_option.dart';

/// Playback and download share selection feedback and readable quality details.
class PlayerQualitySelectionSheet extends StatelessWidget {
  const PlayerQualitySelectionSheet({
    required this.title,
    required this.qualities,
    required this.onSelected,
    this.selectedQualityName,
    this.listKey,
    super.key,
  });

  final String title;
  final List<PlayerQualityOption> qualities;
  final ValueChanged<PlayerQualityOption> onSelected;
  final String? selectedQualityName;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    final cupertino = AppUiTheme.usesCupertino(context);
    final theme = Theme.of(context);
    final rows = <Widget>[
      for (final quality in qualities)
        Semantics(
          selected: quality.name == selectedQualityName,
          child: AppListTile(
            leading: cupertino ? null : const Icon(Icons.graphic_eq_rounded),
            title: Text(quality.name),
            subtitle: _QualityDetails(quality: quality, cupertino: cupertino),
            trailing: quality.name == selectedQualityName
                ? ExcludeSemantics(
                    child: Icon(
                      cupertino
                          ? CupertinoIcons.check_mark
                          : Icons.check_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
            onTap: () => onSelected(quality),
          ),
        ),
    ];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: title,
            actionLabel: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
          Flexible(
            child: ListView(
              key: listKey,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: cupertino && rows.isNotEmpty
                  ? [
                      CupertinoListSection.insetGrouped(
                        margin: EdgeInsets.zero,
                        hasLeading: false,
                        backgroundColor: Colors.transparent,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            theme.colorScheme.onSurface.withValues(alpha: 0.04),
                            theme.colorScheme.surface,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        children: rows,
                      ),
                    ]
                  : rows,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityDetails extends StatelessWidget {
  const _QualityDetails({required this.quality, required this.cupertino});

  final PlayerQualityOption quality;
  final bool cupertino;

  @override
  Widget build(BuildContext context) {
    final description = (quality.description ?? '').trim();
    final detail = [
      if (quality.format.trim().isNotEmpty) quality.format.trim(),
      if (quality.sizeLabel.isNotEmpty) quality.sizeLabel,
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          Text(cupertino ? description : '${quality.name} · $description'),
        if (detail.isNotEmpty) Text(detail),
      ],
    );
  }
}
