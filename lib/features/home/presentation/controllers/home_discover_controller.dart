import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/home_discover_providers.dart';
import '../../domain/entities/home_discover_section.dart';
import '../../domain/entities/home_discover_state.dart';
import '../../domain/entities/home_platform.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../providers/home_discover_providers.dart';

class HomeDiscoverController extends Notifier<HomeDiscoverState> {
  bool _initialized = false;
  Future<void>? _initializing;
  final Map<String, List<HomeDiscoverSection>> _discoverCacheByPlatform =
      <String, List<HomeDiscoverSection>>{};

  @override
  HomeDiscoverState build() {
    ref.listen(onlinePlatformsProvider, (previous, next) {
      final platforms = next.value;
      if (platforms == null ||
          platforms.isEmpty ||
          state.errorMessage == null ||
          _initialized) {
        return;
      }
      unawaited(initialize());
    });
    return HomeDiscoverState.initial;
  }

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }
    final future = _initialize();
    _initializing = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      await _loadInitialData();
      _initialized = state.errorMessage == null && state.platforms.isNotEmpty;
    } finally {
      _initializing = null;
    }
  }

  Future<void> retry() async {
    final selected = state.selectedPlatformId;
    if (selected != null && selected.isNotEmpty) {
      _discoverCacheByPlatform.remove(selected);
    }
    await _loadInitialData();
  }

  Future<void> selectPlatform(String platformId) async {
    if (platformId == state.selectedPlatformId) {
      return;
    }
    final cached = _discoverCacheByPlatform[platformId];
    if (cached != null) {
      state = state.copyWith(
        loading: false,
        selectedPlatformId: platformId,
        sections: cached,
        clearError: true,
      );
      return;
    }
    await _loadDiscover(platformId, state.platforms);
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final platforms = await _resolvePlatforms();
      final selected = _resolveSelectedPlatform(platforms);
      await _loadDiscover(selected.id, platforms);
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  Future<void> _loadDiscover(
    String platformId,
    List<HomePlatform> platforms,
  ) async {
    // 平台列表已由 startup 预加载，发现页内容请求期间也应立即展示平台标签。
    state = state.copyWith(
      loading: true,
      platforms: platforms,
      selectedPlatformId: platformId,
      clearError: true,
    );
    try {
      final sections = await _apiClient.fetchDiscoverSections(platformId);
      _discoverCacheByPlatform[platformId] = sections;
      state = state.copyWith(
        loading: false,
        platforms: platforms,
        selectedPlatformId: platformId,
        sections: sections,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        platforms: platforms,
        selectedPlatformId: platformId,
        errorMessage: '$error',
      );
    }
  }

  HomePlatform _resolveSelectedPlatform(List<HomePlatform> platforms) {
    if (platforms.isEmpty) {
      throw StateError('No platform available from /v1/platforms');
    }
    final available = platforms.where(_supportsHomeDiscover);
    if (available.isEmpty) {
      throw StateError('No online platform available from /v1/platforms');
    }
    final selected = available.firstWhere(
      (platform) => platform.id == state.selectedPlatformId,
      orElse: () => available.first,
    );
    return selected;
  }

  HomeDiscoverApiClient get _apiClient {
    return ref.read(homeDiscoverApiClientProvider);
  }

  Future<List<HomePlatform>> _resolvePlatforms() async {
    final globalPlatforms = await _readGlobalPlatforms();
    final mappedGlobalPlatforms = _mapGlobalPlatforms(globalPlatforms);
    if (mappedGlobalPlatforms.isNotEmpty) {
      return mappedGlobalPlatforms;
    }
    throw StateError(
      'No online platform available from global platforms store',
    );
  }

  Future<List<OnlinePlatform>> _readGlobalPlatforms() async {
    final cached = ref.read(onlinePlatformsProvider).value;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      return await ref.read(onlinePlatformsProvider.notifier).ensureLoaded();
    } catch (_) {
      return const <OnlinePlatform>[];
    }
  }

  List<HomePlatform> _mapGlobalPlatforms(List<OnlinePlatform> platforms) {
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(PlatformFeatureSupportFlag.getDiscoverPage),
        )
        .map(
          (platform) => HomePlatform(
            id: platform.id,
            name: platform.name,
            shortName: platform.shortName,
            status: platform.status,
            featureSupportFlag: platform.featureSupportFlag,
          ),
        )
        .toList(growable: false);
  }

  bool _supportsHomeDiscover(HomePlatform platform) {
    return platform.available &&
        platform.supports(PlatformFeatureSupportFlag.getDiscoverPage);
  }
}
