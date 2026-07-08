import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/plaza_widgets.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/video_plaza_state.dart';
import '../providers/video_plaza_providers.dart';

class VideoPlazaPage extends ConsumerStatefulWidget {
  const VideoPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<VideoPlazaPage> createState() => _VideoPlazaPageState();
}

class _VideoPlazaPageState extends ConsumerState<VideoPlazaPage> {
  late final ScrollController _scrollController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    final state = ref.watch(videoPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'video.plaza.title')),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: platformsAsync.when(
                data: (platforms) {
                  final supportedPlatforms = _supportedPlatforms(platforms);
                  _initializeIfNeeded(supportedPlatforms);
                  return OnlinePlatformTabs(
                    platforms: supportedPlatforms,
                    selectedId: state.selectedPlatformId,
                    requiredFeatureFlag: PlatformFeatureSupportFlag.getMvInfo,
                    onSelected: (id) => ref
                        .read(videoPlazaControllerProvider.notifier)
                        .selectPlatform(id),
                  );
                },
                loading: () => const PlazaPlatformTabsSkeleton(),
                error: (error, _) => PlazaPlatformsErrorView(
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                  i18nKey: 'video.platform_load_failed',
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: platformsAsync.when(
                data: (platforms) {
                  final supportedPlatforms = _supportedPlatforms(platforms);
                  if (supportedPlatforms.isEmpty) {
                    return PlazaEmptyState(
                      label: AppI18n.t(config, 'video.plaza.empty'),
                    );
                  }
                  return _VideoPlazaBody(
                    scrollController: _scrollController,
                    state: state,
                    onRetry: () =>
                        ref.read(videoPlazaControllerProvider.notifier).retry(),
                    onSelectFilter: (groupId, value) => ref
                        .read(videoPlazaControllerProvider.notifier)
                        .selectFilter(groupId: groupId, value: value),
                    onLoadMoreRetry: () => ref
                        .read(videoPlazaControllerProvider.notifier)
                        .loadMore(),
                  );
                },
                loading: () => const _VideoPlazaLoadingView(),
                error: (error, _) => PlazaErrorView(
                  message: '$error',
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OnlinePlatform> _supportedPlatforms(List<OnlinePlatform> platforms) {
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(PlatformFeatureSupportFlag.getMvInfo) &&
              platform.supports(PlatformFeatureSupportFlag.getMvUrl) &&
              platform.supports(PlatformFeatureSupportFlag.listMvFilters) &&
              platform.supports(PlatformFeatureSupportFlag.listFilterMvs),
        )
        .toList(growable: false);
  }

  void _initializeIfNeeded(List<OnlinePlatform> platforms) {
    if (_initialized || platforms.isEmpty) {
      return;
    }
    _initialized = true;
    final initialPlatformId = _resolveInitialPlatform(platforms);
    if (initialPlatformId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(videoPlazaControllerProvider.notifier)
          .initialize(initialPlatformId);
    });
  }

  String? _resolveInitialPlatform(List<OnlinePlatform> platforms) {
    final preferred = widget.initialPlatform?.trim() ?? '';
    if (preferred.isNotEmpty) {
      for (final platform in platforms) {
        if (platform.id == preferred) {
          return preferred;
        }
      }
    }
    if (platforms.isEmpty) {
      return null;
    }
    return platforms.first.id;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    ref.read(videoPlazaControllerProvider.notifier).loadMore();
  }
}

class _VideoPlazaBody extends StatelessWidget {
  const _VideoPlazaBody({
    required this.scrollController,
    required this.state,
    required this.onRetry,
    required this.onSelectFilter,
    required this.onLoadMoreRetry,
  });

  final ScrollController scrollController;
  final VideoPlazaState state;
  final VoidCallback onRetry;
  final void Function(String groupId, String value) onSelectFilter;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    if (state.filtersLoading && state.filterGroups.isEmpty) {
      return const _VideoPlazaLoadingView();
    }
    if (state.filtersErrorMessage != null && state.filterGroups.isEmpty) {
      return PlazaErrorView(
        message: state.filtersErrorMessage!,
        onRetry: onRetry,
      );
    }
    return Column(
      children: <Widget>[
        PlazaFiltersPanel(
          filterGroups: state.filterGroups,
          selectedFilters: state.selectedFilters,
          onSelectFilter: onSelectFilter,
        ),
        const Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final config = ProviderScope.containerOf(context).read(appConfigProvider);
    if (state.itemsLoading && state.items.isEmpty) {
      return const PlazaVideoGridSkeleton();
    }
    if (state.itemsErrorMessage != null && state.items.isEmpty) {
      return PlazaErrorView(
        message: state.itemsErrorMessage!,
        onRetry: onRetry,
      );
    }
    if (state.items.isEmpty) {
      return PlazaEmptyState(label: AppI18n.t(config, 'video.empty_filtered'));
    }
    final showTail = state.loadingMore || state.itemsErrorMessage != null;
    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          sliver: SliverGrid.builder(
            itemCount: state.items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: videoGridItemChildAspectRatio,
            ),
            itemBuilder: (context, index) {
              final video = state.items[index];
              return VideoGridItem(
                title: video.name,
                creator: video.creator,
                duration: '${video.duration}',
                coverUrl: video.cover,
                playCount: video.playCount,
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.videoDetail,
                    queryParameters: <String, String>{
                      'id': video.id,
                      'platform': video.platform,
                      'title': video.name,
                    },
                  ).toString(),
                ),
              );
            },
          ),
        ),
        if (showTail)
          SliverToBoxAdapter(
            child: state.loadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    child: PlazaLoadMoreRetryCard(
                      message: state.itemsErrorMessage,
                      onRetry: onLoadMoreRetry,
                      fallbackI18nKey: 'video.load_failed',
                    ),
                  ),
          ),
      ],
    );
  }
}

class _VideoPlazaLoadingView extends StatelessWidget {
  const _VideoPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        PlazaFilterPanelSkeleton(rowCount: 2),
        Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: PlazaVideoGridSkeleton()),
      ],
    );
  }
}
