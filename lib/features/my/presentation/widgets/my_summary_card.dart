import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../domain/entities/my_summary.dart';

class MySummaryCard extends StatelessWidget {
  const MySummaryCard({required this.summary, required this.config, super.key});

  final MySummary summary;
  final AppConfigState config;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(30),
      blurSigma: 0,
      tintColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppI18n.t(config, 'my.summary'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.55,
            children: <Widget>[
              _SummaryTile(
                icon: Icons.favorite_rounded,
                title: AppI18n.t(config, 'my.summary.songs'),
                value: summary.favoriteSongCount,
              ),
              _SummaryTile(
                icon: Icons.queue_music_rounded,
                title: AppI18n.t(config, 'my.summary.playlists'),
                value: summary.favoritePlaylistCount,
              ),
              _SummaryTile(
                icon: Icons.person_pin_rounded,
                title: AppI18n.t(config, 'my.summary.artists'),
                value: summary.favoriteArtistCount,
              ),
              _SummaryTile(
                icon: Icons.album_rounded,
                title: AppI18n.t(config, 'my.summary.albums'),
                value: summary.favoriteAlbumCount,
              ),
              _SummaryTile(
                icon: Icons.library_music_rounded,
                title: AppI18n.t(config, 'my.summary.created_playlists'),
                value: summary.createdPlaylistCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
