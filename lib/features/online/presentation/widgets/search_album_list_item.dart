import 'package:flutter/material.dart';

import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/widgets/app_network_image.dart';

class SearchAlbumListItem extends StatelessWidget {
  const SearchAlbumListItem({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final String coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSkinContentSurface(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: <Widget>[
                _Cover(url: coverUrl, icon: Icons.album_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.hintColor.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: Theme.of(context).hintColor),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AppNetworkImage(
        url: url,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        cacheWidth: 160,
        fallback: fallback,
      ),
    );
  }
}
