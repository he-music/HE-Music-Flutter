import 'package:flutter/material.dart';

import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/layout/ranking_layout_spec.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../domain/entities/ranking_info.dart';

class RankingCards extends StatelessWidget {
  const RankingCards({required this.rankings, required this.onTap, super.key});

  final List<RankingInfo> rankings;
  final ValueChanged<RankingInfo> onTap;

  @override
  Widget build(BuildContext context) {
    final listRankings = rankings
        .where((ranking) => ranking.previewSongs.isNotEmpty)
        .toList(growable: false);
    final gridRankings = rankings
        .where((ranking) => ranking.previewSongs.isEmpty)
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrapSpec = resolveRankingWrapLayoutSpec(
          maxWidth: constraints.maxWidth,
        );
        final gridSpec = resolveRankingGridLayoutSpec(
          maxWidth: constraints.maxWidth,
        );
        return Wrap(
          spacing: wrapSpec.spacing,
          runSpacing: wrapSpec.spacing,
          children: <Widget>[
            ...listRankings.map(
              (ranking) => SizedBox(
                width: wrapSpec.itemWidth,
                child: _RankingRowCard(ranking: ranking, onTap: onTap),
              ),
            ),
            ...gridRankings.map(
              (ranking) => SizedBox(
                width: gridSpec.itemWidth,
                child: _RankingGridItem(
                  ranking: ranking,
                  onTap: onTap,
                  side: gridSpec.itemWidth,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RankingRowCard extends StatelessWidget {
  const _RankingRowCard({required this.ranking, required this.onTap});

  final RankingInfo ranking;
  final ValueChanged<RankingInfo> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowSpec = resolveRankingRowLayoutSpec(
          maxWidth: constraints.maxWidth,
        );
        return AppSkinContentSurface(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => onTap(ranking),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ranking.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _RankingCover(
                          url: ranking.coverUrl,
                          side: rowSpec.coverSide,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: rowSpec.coverSide,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ranking.previewSongs
                                  .take(3)
                                  .toList(growable: false)
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key + 1;
                                    final song = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '$index. ${song.name} - ${song.artist}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor),
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RankingGridItem extends StatelessWidget {
  const _RankingGridItem({
    required this.ranking,
    required this.onTap,
    required this.side,
  });

  final RankingInfo ranking;
  final ValueChanged<RankingInfo> onTap;
  final double side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(ranking),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RankingCover(url: ranking.coverUrl, side: side),
            const SizedBox(height: 8),
            Text(
              ranking.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingCover extends StatelessWidget {
  const _RankingCover({required this.url, required this.side});

  final String url;
  final double side;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.leaderboard_rounded),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AppNetworkImage(
        url: url,
        width: side,
        height: side,
        fit: BoxFit.cover,
        cacheWidth: 160,
        fallback: fallback,
      ),
    );
  }
}
