import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/sheet_music_info.dart';
import 'sheet_music_metadata.dart';

class SheetMusicListSliver extends ConsumerWidget {
  const SheetMusicListSliver({
    required this.sheets,
    required this.platform,
    required this.songId,
    super.key,
  });

  final List<SheetMusicInfo> sheets;
  final String platform;
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final canGet = ref.watch(
      onlinePlatformsProvider.select(
        (state) => canGetSongSheetMusic(
          songId: songId,
          platformId: platform,
          platforms: state.value ?? const [],
        ),
      ),
    );
    return SliverList.separated(
      itemCount: sheets.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final sheet = sheets[index];
        final enabled = canGet && sheet.id.isNotEmpty;
        return AppSkinContentSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppNetworkImage(
                  url: sheet.cover,
                  width: 56,
                  height: 72,
                  fit: BoxFit.cover,
                  fallback: const SizedBox(
                    width: 56,
                    height: 72,
                    child: Icon(Icons.library_music_outlined),
                  ),
                ),
              ),
              title: Text(
                sheetMusicTitle(sheet, locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: SheetMusicMetadata(sheet: sheet, locale: locale),
              trailing: enabled
                  ? const Icon(Icons.chevron_right_rounded)
                  : null,
              onTap: enabled
                  ? () => context.push(
                      Uri(
                        path: AppRoutes.sheetMusicDetail,
                        queryParameters: {
                          'platform': platform,
                          'song_id': songId,
                          'id': sheet.id,
                          'title': sheetMusicTitle(sheet, locale),
                        },
                      ).toString(),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
