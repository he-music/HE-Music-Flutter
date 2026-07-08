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
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../online/presentation/widgets/search_artist_list_item.dart';
import '../../domain/entities/artist_plaza_state.dart';
import '../providers/artist_plaza_providers.dart';

class ArtistPlazaPage extends ConsumerStatefulWidget {
  const ArtistPlazaPage({this.initialPlatform, super.key});

  final String? initialPlatform;

  @override
  ConsumerState<ArtistPlazaPage> createState() => _ArtistPlazaPageState();
}

class _ArtistPlazaPageState extends ConsumerState<ArtistPlazaPage> {
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
    final state = ref.watch(artistPlazaControllerProvider);
    final config = ref.watch(appConfigProvider);

    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(config, 'artist.plaza.title')),
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
                    requiredFeatureFlag:
                        PlatformFeatureSupportFlag.searchSinger,
                    onSelected: (id) => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .selectPlatform(id),
                  );
                },
                loading: () => const PlazaPlatformTabsSkeleton(),
                error: (error, _) => PlazaPlatformsErrorView(
                  onRetry: () =>
                      ref.read(onlinePlatformsProvider.notifier).refresh(),
                  i18nKey: 'artist.plaza.platform_load_failed',
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
                      label: AppI18n.t(config, 'artist.plaza.empty'),
                    );
                  }
                  return _ArtistPlazaBody(
                    localeCode: config.localeCode,
                    scrollController: _scrollController,
                    state: state,
                    onRetry: () => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .retry(),
                    onSelectFilter: (groupId, value) => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .selectFilter(groupId: groupId, value: value),
                    onLoadMoreRetry: () => ref
                        .read(artistPlazaControllerProvider.notifier)
                        .loadMore(),
                  );
                },
                loading: () => const _ArtistPlazaLoadingView(),
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
              platform.supports(PlatformFeatureSupportFlag.listArtistTabs),
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
          .read(artistPlazaControllerProvider.notifier)
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
    ref.read(artistPlazaControllerProvider.notifier).loadMore();
  }
}

class _ArtistPlazaBody extends StatelessWidget {
  const _ArtistPlazaBody({
    required this.localeCode,
    required this.scrollController,
    required this.state,
    required this.onRetry,
    required this.onSelectFilter,
    required this.onLoadMoreRetry,
  });

  final String localeCode;
  final ScrollController scrollController;
  final ArtistPlazaState state;
  final VoidCallback onRetry;
  final void Function(String groupId, String value) onSelectFilter;
  final VoidCallback onLoadMoreRetry;

  @override
  Widget build(BuildContext context) {
    if (state.filtersLoading && state.filterGroups.isEmpty) {
      return const _ArtistPlazaLoadingView();
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
      return const PlazaArtistListSkeleton();
    }
    if (state.itemsErrorMessage != null && state.items.isEmpty) {
      return PlazaErrorView(
        message: state.itemsErrorMessage!,
        onRetry: onRetry,
      );
    }
    if (state.items.isEmpty) {
      return PlazaEmptyState(label: AppI18n.t(config, 'artist.plaza.empty'));
    }
    final showTail = state.loadingMore || state.itemsErrorMessage != null;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: state.items.length + (showTail ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          if (state.loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return PlazaLoadMoreRetryCard(
            message: state.itemsErrorMessage,
            onRetry: onLoadMoreRetry,
            fallbackI18nKey: 'artist.plaza.load_failed',
          );
        }
        final artist = state.items[index];
        return SearchArtistListItem(
          localeCode: localeCode,
          title: artist.name,
          coverUrl: artist.cover,
          songCount: artist.songCount,
          albumCount: artist.albumCount,
          videoCount: artist.mvCount,
          onTap: () => context.push(
            Uri(
              path: AppRoutes.artistDetail,
              queryParameters: <String, String>{
                'id': artist.id,
                'platform': artist.platform,
                'title': artist.name,
              },
            ).toString(),
          ),
        );
      },
    );
  }
}

class _ArtistPlazaLoadingView extends StatelessWidget {
  const _ArtistPlazaLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        PlazaFilterPanelSkeleton(rowCount: 2),
        Divider(height: 1, indent: 12, endIndent: 12),
        Expanded(child: PlazaArtistListSkeleton()),
      ],
    );
  }
}
