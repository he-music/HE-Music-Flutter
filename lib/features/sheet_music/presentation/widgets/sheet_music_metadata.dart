import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/sheet_music_info.dart';

String sheetMusicTags(SheetMusicInfo sheet) => [
  ...sheet.instruments,
  ...sheet.notationTypes,
  sheet.arrangementType,
  sheet.difficulty,
].where((value) => value.isNotEmpty).join(' · ');

String sheetMusicTitle(SheetMusicInfo sheet, String locale) =>
    sheet.title.isNotEmpty
    ? sheet.title
    : sheet.songName.isNotEmpty
    ? sheet.songName
    : AppI18n.tByLocaleCode(locale, 'sheet_music.untitled');

String _sheetMusicKey(String originalKey, String locale) {
  final value = originalKey.trim();
  final key = value.endsWith('调')
      ? value.substring(0, value.length - 1).trimRight()
      : value;
  if (key.isEmpty) return '';
  return AppI18n.formatByLocaleCode(locale, 'sheet_music.key_short', {
    'key': key,
  });
}

class SheetMusicMetadata extends StatelessWidget {
  const SheetMusicMetadata({
    required this.sheet,
    required this.locale,
    this.showDetail = false,
    super.key,
  });

  final SheetMusicInfo sheet;
  final String locale;
  final bool showDetail;

  @override
  Widget build(BuildContext context) {
    String field(String key, String value) =>
        '${AppI18n.tByLocaleCode(locale, key)}$value';
    final tags = sheetMusicTags(sheet);
    if (!showDetail) {
      final key = _sheetMusicKey(sheet.originalKey, locale);
      final summary = [
        if (key.isNotEmpty) key,
        if (sheet.pageCount > 0)
          AppI18n.formatByLocaleCode(locale, 'sheet_music.pages_short', {
            'count': '${sheet.pageCount}',
          }),
      ].join(' · ');
      return Text(
        [tags, summary].where((line) => line.isNotEmpty).join('\n'),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final key = _sheetMusicKey(sheet.originalKey, locale);
    final lines = [
      if (sheet.songName.isNotEmpty &&
          sheet.songName != sheetMusicTitle(sheet, locale))
        sheet.songName,
      if (sheet.uploader.isNotEmpty)
        field('sheet_music.uploader', sheet.uploader),
      if (key.isNotEmpty) field('sheet_music.original_key', key),
      if (sheet.bpm > 0) field('sheet_music.bpm', '${sheet.bpm} BPM'),
      if (sheet.pageCount > 0)
        field('sheet_music.page_count', '${sheet.pageCount}'),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('sheet-music-metadata'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final line in lines)
            Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
