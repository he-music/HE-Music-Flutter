import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/layout/ranking_layout_spec.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/ranking_group.dart';
import '../../domain/entities/ranking_info.dart';
import '../providers/ranking_providers.dart';

class RankingListPage extends ConsumerStatefulWidget {
  const RankingListPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<RankingListPage> createState() => _RankingListPageState();
}

class _RankingListPageState extends ConsumerState<RankingListPage> {
  String? _platformId;

  @override
  void initState() {
    super.initState();
    _platformId = widget.initialPlatform;
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(rankingPlatformsProvider);
    final config = ref.watch(appConfigProvider);

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'ranking.title')),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: platformsAsync.when(
                data: (platforms) {
                  _syncPlatform(platforms);
                  return OnlinePlatformTabs(
                    platforms: platforms,
                    selectedId: _platformId,
                    requiredFeatureFlag: PlatformFeatureSupportFlag.getTopList,
                    onSelected: (id) => setState(() => _platformId = id),
                  );
                },
                loading: () => const PlazaPlatformTabsSkeleton(),
                error: (error, _) => _PlatformsErrorView(
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: platformsAsync.when(
                loading: () => const RankingGroupsSkeleton(),
                error: (error, _) => _ErrorView(
                  message: '$error',
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                ),
                data: (platforms) {
                  if (platforms.isEmpty) {
                    return Center(
                      child: Text(
                        AppI18n.t(config, 'ranking.no_platform'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    );
                  }

                  final selected = _platformId;
                  final supportsRanking = _supportsRanking(selected, platforms);
                  final groupsAsync = selected == null || selected.isEmpty
                      ? const AsyncValue<List<RankingGroup>>.data(
                          <RankingGroup>[],
                        )
                      : (supportsRanking
                            ? ref.watch(rankingGroupsProvider(selected))
                            : const AsyncValue<List<RankingGroup>>.data(
                                <RankingGroup>[],
                              ));

                  return groupsAsync.when(
                    data: (groups) {
                      if (selected != null &&
                          selected.isNotEmpty &&
                          !supportsRanking) {
                        return Center(
                          child: Text(
                            AppI18n.t(config, 'ranking.unsupported'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        );
                      }
                      return _RankingGroupsView(
                        groups: groups,
                        onTapRanking: (ranking) => _openRanking(
                          context,
                          id: ranking.id,
                          platform: ranking.platform,
                          title: ranking.name,
                        ),
                      );
                    },
                    loading: () => const RankingGroupsSkeleton(),
                    error: (error, _) => _ErrorView(
                      message: '$error',
                      onRetry: selected == null
                          ? null
                          : () =>
                                ref.invalidate(rankingGroupsProvider(selected)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncPlatform(List<OnlinePlatform> platforms) {
    if (platforms.isEmpty) {
      return;
    }
    final selected = _platformId?.trim() ?? '';
    final exists = platforms.any((p) => p.id == selected);
    if (exists) {
      return;
    }
    final fallback = platforms
        .firstWhere(
          (platform) =>
              platform.supports(PlatformFeatureSupportFlag.getTopList),
          orElse: () => platforms.first,
        )
        .id;
    if (fallback == _platformId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _platformId = fallback);
    });
  }

  bool _supportsRanking(String? selected, List<OnlinePlatform> platforms) {
    final id = selected?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    for (final platform in platforms) {
      if (platform.id != id) {
        continue;
      }
      return platform.supports(PlatformFeatureSupportFlag.getTopList);
    }
    return false;
  }

  void _openRanking(
    BuildContext context, {
    required String id,
    required String platform,
    required String title,
  }) {
    context.push(
      Uri(
        path: AppRoutes.rankingDetail,
        queryParameters: <String, String>{
          'id': id,
          'platform': platform,
          'title': title,
        },
      ).toString(),
    );
  }
}

class _PlatformsErrorView extends StatelessWidget {
  const _PlatformsErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return SizedBox(
      height: 28,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'ranking.platform_load_failed'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppI18n.tByLocaleCode(localeCode, 'common.retry')),
          ),
        ],
      ),
    );
  }
}

class _RankingGroupsView extends StatelessWidget {
  const _RankingGroupsView({required this.groups, required this.onTapRanking});

  final List<RankingGroup> groups;
  final ValueChanged<RankingInfo> onTapRanking;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (groups.isEmpty) {
      return Center(
        child: Text(
          AppI18n.tByLocaleCode(localeCode, 'ranking.empty'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        if (group.rankings.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              _RankingGroupContent(
                rankings: group.rankings,
                onTap: onTapRanking,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankingGroupContent extends StatelessWidget {
  const _RankingGroupContent({required this.rankings, required this.onTap});

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

        return Material(
          color: theme.cardTheme.color,
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
                      _Cover(url: ranking.coverUrl, side: rowSpec.coverSide),
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
                                  final idx = entry.key + 1;
                                  final song = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '$idx. ${song.name} - ${song.artist}',
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
            _Cover(url: ranking.coverUrl, side: side),
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

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.side});

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

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          if (onRetry != null)
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppI18n.t(config, 'common.retry')),
            ),
        ],
      ),
    );
  }
}
