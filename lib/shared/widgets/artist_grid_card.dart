import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/config/app_config_state.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/skin/app_skin_surface.dart';
import '../models/he_music_models.dart';
import 'app_network_image.dart';

const _artistCoverRadius = 8.0;

class ArtistGridCard extends ConsumerWidget {
  const ArtistGridCard({
    required this.artist,
    required this.onTap,
    this.coverUrl,
    super.key,
  });

  final ArtistInfo artist;
  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final subtitle = _subtitle(config);
    return AppSkinContentSurface(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_artistCoverRadius),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coverSide = (constraints.maxHeight - 36).clamp(
                  0.0,
                  constraints.maxWidth,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: coverSide,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_artistCoverRadius),
                        child: AppNetworkImage(
                          url: coverUrl ?? artist.cover,
                          fit: BoxFit.cover,
                          cacheWidth: 420,
                          filterQuality: FilterQuality.low,
                          fallback: ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.72),
                            child: Icon(
                              Icons.person_rounded,
                              color: theme.hintColor,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 15,
                      child: Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 13,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(AppConfigState config) {
    final alias = artist.alias.trim();
    if (alias.isNotEmpty) {
      return alias;
    }
    final songCount = artist.songCount.trim();
    if (songCount.isEmpty) {
      return '';
    }
    return AppI18n.format(config, 'artist.meta.song_count', <String, String>{
      'count': songCount,
    });
  }
}
