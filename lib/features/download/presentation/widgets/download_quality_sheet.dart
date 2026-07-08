import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../player/domain/entities/player_quality_option.dart';
import '../../../../shared/models/he_music_models.dart';

List<PlayerQualityOption> buildDownloadQualityOptions({
  required List<LinkInfo> links,
  required Map<String, String> qualityDescriptions,
}) {
  final options = <PlayerQualityOption>[];
  final seenNames = <String>{};
  for (final link in links) {
    final name = link.name.trim();
    if (name.isEmpty || !seenNames.add(name)) {
      continue;
    }
    final description = (qualityDescriptions[name] ?? '').trim();
    options.add(
      PlayerQualityOption(
        name: name,
        quality: link.quality,
        format: link.format.trim(),
        url: link.url.trim(),
        description: description.isEmpty ? null : description,
        sizeBytes: _parseLinkSizeBytes(link.size),
      ),
    );
  }
  return List<PlayerQualityOption>.unmodifiable(options.reversed);
}

Future<PlayerQualityOption?> showDownloadQualitySheet({
  required BuildContext context,
  required List<PlayerQualityOption> qualities,
  String? selectedQualityName,
}) {
  return showModalBottomSheet<PlayerQualityOption>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final localeCode = Localizations.localeOf(sheetContext).languageCode;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                AppI18n.tByLocaleCode(localeCode, 'download.quality.title'),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final quality in qualities)
              ListTile(
                leading: const Icon(Icons.graphic_eq_rounded),
                title: Text(_qualityTitle(quality)),
                subtitle: _QualitySubtitle(quality: quality),
                trailing: selectedQualityName == quality.name
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(quality),
              ),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );
}

String _qualityTitle(PlayerQualityOption quality) {
  return quality.name;
}

class _QualitySubtitle extends StatelessWidget {
  const _QualitySubtitle({required this.quality});

  final PlayerQualityOption quality;

  @override
  Widget build(BuildContext context) {
    final description = (quality.description ?? '').trim();
    final parts = <String>[
      if (quality.format.trim().isNotEmpty) quality.format.trim(),
      if (quality.sizeLabel.isNotEmpty) quality.sizeLabel,
    ];
    final detail = parts.join(' · ');
    if (description.isEmpty) {
      return Text(detail);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${quality.name} · $description'),
        if (detail.isNotEmpty) Text(detail),
      ],
    );
  }
}

int? _parseLinkSizeBytes(String rawSize) {
  final normalized = rawSize.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
