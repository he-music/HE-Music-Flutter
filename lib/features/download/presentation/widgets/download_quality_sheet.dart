import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../app/theme/player/app_player_style_theme.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../player/domain/entities/player_quality_option.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/link_info_size_parser.dart';

import '../../../player/presentation/widgets/player_quality_selection_sheet.dart';

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
        sizeBytes: parseLinkInfoSizeBytes(link.size),
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
  Widget buildSheet(BuildContext sheetContext) => PlayerQualitySelectionSheet(
    title: AppI18n.tByLocaleCode(
      Localizations.localeOf(sheetContext).languageCode,
      'download.quality.title',
    ),
    listKey: const ValueKey<String>('download-quality-sheet-list'),
    qualities: qualities,
    selectedQualityName: selectedQualityName,
    onSelected: (quality) => Navigator.of(sheetContext).pop(quality),
  );

  // 该面板也用于首页，仅播放器上下文使用播放器专属主题。
  if (Theme.of(context).extension<AppPlayerStyleTheme>() != null) {
    return showPlayerStyledBottomSheet<PlayerQualityOption>(
      context: context,
      isScrollControlled: true,
      fitContent: true,
      heightFactor: LayoutTokens.actionSheetMaxHeightFactor,
      builder: buildSheet,
    );
  }
  return showAppThemedBottomSheet<PlayerQualityOption>(
    context: context,
    heightFactor: LayoutTokens.actionSheetMaxHeightFactor,
    fitContent: true,
    isScrollControlled: true,
    builder: buildSheet,
  );
}
