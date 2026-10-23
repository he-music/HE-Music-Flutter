import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/network/unauthorized_redirect_interceptor.dart';
import '../../data/datasources/online_platform_cache_data_source.dart';
import '../../data/providers/online_providers.dart';
import '../../domain/entities/online_feature_state.dart';
import '../../domain/entities/online_platform.dart';
import '../controllers/online_controller.dart';

export '../../data/providers/online_providers.dart';

final onlineControllerProvider =
    NotifierProvider<OnlineController, OnlineFeatureState>(
      OnlineController.new,
    );

class SearchHotKeywordsCacheEntry {
  const SearchHotKeywordsCacheEntry({
    required this.keywords,
    required this.fetchedAt,
  });

  final List<String> keywords;
  final DateTime fetchedAt;

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) >= const Duration(minutes: 10);
}

class SearchHotKeywordsCacheController
    extends Notifier<Map<String, SearchHotKeywordsCacheEntry>> {
  final Map<String, Future<List<String>>> _pendingRequests =
      <String, Future<List<String>>>{};

  @override
  Map<String, SearchHotKeywordsCacheEntry> build() {
    return const <String, SearchHotKeywordsCacheEntry>{};
  }

  SearchHotKeywordsCacheEntry? getCached(String platformId) {
    final normalized = platformId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return state[normalized];
  }

  Future<List<String>> ensureKeywords(String platformId) async {
    final normalized = platformId.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final cached = state[normalized];
    if (cached != null && !cached.isExpired) {
      return cached.keywords;
    }
    if (cached != null && cached.keywords.isNotEmpty) {
      unawaited(refreshKeywords(normalized));
      return cached.keywords;
    }
    return refreshKeywords(normalized);
  }

  Future<List<String>> refreshKeywords(String platformId) {
    final normalized = platformId.trim();
    if (normalized.isEmpty) {
      return Future.value(const <String>[]);
    }
    final pending = _pendingRequests[normalized];
    if (pending != null) {
      return pending;
    }
    final future = _doRefresh(normalized);
    _pendingRequests[normalized] = future;
    future.whenComplete(() {
      _pendingRequests.remove(normalized);
    });
    return future;
  }

  Future<List<String>> _doRefresh(String platformId) async {
    final next = await ref
        .read(onlineSearchRepositoryProvider)
        .fetchHotKeywords(platform: platformId);
    state = <String, SearchHotKeywordsCacheEntry>{
      ...state,
      platformId: SearchHotKeywordsCacheEntry(
        keywords: next,
        fetchedAt: DateTime.now(),
      ),
    };
    return next;
  }
}

class SearchDefaultPlaceholderState {
  const SearchDefaultPlaceholderState({
    this.entries = const <SearchDefaultEntry>[],
    this.currentIndex = -1,
  });

  final List<SearchDefaultEntry> entries;
  final int currentIndex;

  SearchDefaultEntry? get currentEntry {
    if (entries.isEmpty || currentIndex < 0 || currentIndex >= entries.length) {
      return null;
    }
    return entries[currentIndex];
  }

  SearchDefaultPlaceholderState copyWith({
    List<SearchDefaultEntry>? entries,
    int? currentIndex,
  }) {
    return SearchDefaultPlaceholderState(
      entries: entries ?? this.entries,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class SearchDefaultPlaceholderController
    extends Notifier<SearchDefaultPlaceholderState> {
  static const _reloadInterval = Duration(minutes: 10);
  static const _rotateInterval = Duration(minutes: 1);

  Timer? _reloadTimer;
  Timer? _rotateTimer;
  bool _initialized = false;
  late AppLifecycleState _lifecycleState;
  AppLifecycleListener? _lifecycleListener;

  @override
  SearchDefaultPlaceholderState build() {
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _lifecycleListener ??= AppLifecycleListener(
      onStateChange: _onAppLifecycleChanged,
    );
    ref.onDispose(() {
      _stopTimers();
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_initialize);
    }
    return const SearchDefaultPlaceholderState();
  }

  Future<void> _initialize() async {
    await refresh();
    _startTimers();
  }

  void _startTimers() {
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _reloadTimer ??= Timer.periodic(_reloadInterval, (_) {
      unawaited(refresh());
    });
    _rotateTimer ??= Timer.periodic(_rotateInterval, (_) {
      _rotate();
    });
  }

  void _stopTimers() {
    _reloadTimer?.cancel();
    _reloadTimer = null;
    _rotateTimer?.cancel();
    _rotateTimer = null;
  }

  void _onAppLifecycleChanged(AppLifecycleState lifecycleState) {
    _lifecycleState = lifecycleState;
    // 搜索占位词不是后台关键任务，离开前台后停止计时和网络刷新。
    if (lifecycleState != AppLifecycleState.resumed) {
      _stopTimers();
      return;
    }
    _startTimers();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      final platforms = await ref.read(onlinePlatformsProvider.future);
      if (!ref.mounted || _lifecycleState != AppLifecycleState.resumed) return;
      final platform = platforms
          .where(
            (item) =>
                item.available &&
                item.supports(PlatformFeatureSupportFlag.getSearchDefault),
          )
          .firstOrNull;
      if (platform == null) return;
      final next = await ref
          .read(onlineSearchRepositoryProvider)
          .fetchDefaultKeywords(
            platform: platform.id,
            silentErrorMessage: true,
          );
      if (!ref.mounted) return;
      if (next.isEmpty) {
        return;
      }
      state = SearchDefaultPlaceholderState(entries: next, currentIndex: 0);
    } catch (_) {
      return;
    }
  }

  void _rotate() {
    final entries = state.entries;
    if (entries.length <= 1) {
      return;
    }
    final nextIndex = (state.currentIndex + 1) % entries.length;
    state = state.copyWith(currentIndex: nextIndex);
  }
}

final searchDefaultPlaceholderProvider =
    NotifierProvider<
      SearchDefaultPlaceholderController,
      SearchDefaultPlaceholderState
    >(SearchDefaultPlaceholderController.new);

final searchHotKeywordsCacheProvider =
    NotifierProvider<
      SearchHotKeywordsCacheController,
      Map<String, SearchHotKeywordsCacheEntry>
    >(SearchHotKeywordsCacheController.new);

final onlinePlatformCacheDataSourceProvider =
    Provider<OnlinePlatformCacheDataSource>(
      (ref) => const OnlinePlatformCacheDataSource(),
    );

typedef OnlinePlatformSyncState = ({
  bool usingCache,
  bool refreshing,
  bool refreshFailed,
});

class OnlinePlatformSyncController extends Notifier<OnlinePlatformSyncState> {
  @override
  OnlinePlatformSyncState build() =>
      (usingCache: false, refreshing: false, refreshFailed: false);

  void update(OnlinePlatformSyncState value) => state = value;
}

final onlinePlatformSyncProvider =
    NotifierProvider<OnlinePlatformSyncController, OnlinePlatformSyncState>(
      OnlinePlatformSyncController.new,
    );

class OnlinePlatformsController extends AsyncNotifier<List<OnlinePlatform>> {
  Future<List<OnlinePlatform>>? _requestInFlight;
  Future<List<OnlinePlatform>>? _initialLoad;
  String? _cacheScope;
  int _generation = 0;

  @override
  Future<List<OnlinePlatform>> build() {
    final generation = ++_generation;
    ref.onDispose(() {
      _generation++;
      _requestInFlight = null;
      _initialLoad = null;
    });
    ref.listen(appConfigProvider.select((config) => config.apiBaseUrl), (_, _) {
      ref.invalidateSelf();
    });
    final load = _initialize(generation);
    _initialLoad = load;
    load.then<void>(
      (_) {
        if (identical(_initialLoad, load)) _initialLoad = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_initialLoad, load)) _initialLoad = null;
      },
    );
    return load;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<List<OnlinePlatform>> _initialize(int generation) async {
    try {
      // Home and playback may read this provider before the startup gate.
      await ref.read(appConfigProvider.notifier).waitUntilHydrated();
      if (!_isCurrent(generation)) {
        throw StateError('Platform initialization superseded');
      }
      _cacheScope = _currentCacheScope();
      final cached = await ref
          .read(onlinePlatformCacheDataSourceProvider)
          .read(_cacheScope!);
      if (!_isCurrent(generation)) {
        throw StateError('Platform initialization superseded');
      }
      if (cached != null && cached.isNotEmpty) {
        _sync(usingCache: true);
        // Publish the valid snapshot before refreshing it. A refresh failure
        // must never hide metadata that can still power online pages.
        Future<void>.delayed(Duration.zero, () async {
          if (!_isCurrent(generation)) return;
          try {
            await _startRefresh(generation);
          } catch (_) {
            // The sync state exposes the stale-cache failure to the UI.
          }
        });
        return cached;
      }
      _sync(refreshing: true);
      return _startRefresh(generation);
    } catch (_) {
      if (_isCurrent(generation)) _sync(refreshFailed: true);
      rethrow;
    }
  }

  Future<List<OnlinePlatform>> ensureLoaded({bool forceRefresh = false}) {
    final initializing = _initialLoad;
    if (initializing != null) return initializing;
    final current = state.value;
    if (!forceRefresh && current != null && current.isNotEmpty) {
      return Future<List<OnlinePlatform>>.value(current);
    }
    final inFlight = _requestInFlight;
    if (inFlight != null) return inFlight;
    return _startRefresh(_generation);
  }

  Future<void> refresh() async {
    try {
      await ensureLoaded(forceRefresh: true);
    } catch (_) {
      // Button callbacks can safely retry; failure remains visible in state.
    }
  }

  String _currentCacheScope() {
    final config = ref.read(appConfigProvider);
    return OnlinePlatformCacheDataSource.scopeFor(
      config.apiBaseUrl,
      config.authToken,
    );
  }

  Future<List<OnlinePlatform>> _startRefresh(int generation) {
    final existing = _requestInFlight;
    if (existing != null) return existing;
    _cacheScope = _currentCacheScope();
    final future = _refresh(generation);
    _requestInFlight = future;
    future.then<void>(
      (_) {
        if (identical(_requestInFlight, future)) _requestInFlight = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_requestInFlight, future)) _requestInFlight = null;
      },
    );
    return future;
  }

  Future<List<OnlinePlatform>> _refresh(int generation) async {
    final previous = state.value;
    if (previous == null || previous.isEmpty) state = const AsyncLoading();
    _sync(usingCache: previous?.isNotEmpty ?? false, refreshing: true);
    try {
      final next = await _fetchPlatforms(generation);
      if (_isCurrent(generation)) {
        state = AsyncData(next);
        _sync();
      }
      return next;
    } catch (error, stackTrace) {
      if (_isCurrent(generation)) {
        final unauthorized =
            error is DioException && shouldRedirectUnauthorized(error);
        final canKeepSnapshot =
            !unauthorized && (previous?.isNotEmpty ?? false);
        state = canKeepSnapshot
            ? AsyncData(previous!)
            : AsyncError(error, stackTrace);
        _sync(usingCache: canKeepSnapshot, refreshFailed: true);
        if (unauthorized && _cacheScope != null) {
          await ref
              .read(onlinePlatformCacheDataSourceProvider)
              .clear(_cacheScope!);
        }
      }
      rethrow;
    }
  }

  void _sync({
    bool usingCache = false,
    bool refreshing = false,
    bool refreshFailed = false,
  }) => ref.read(onlinePlatformSyncProvider.notifier).update((
    usingCache: usingCache,
    refreshing: refreshing,
    refreshFailed: refreshFailed,
  ));

  Future<List<OnlinePlatform>> _fetchPlatforms(int generation) async {
    final client = ref.read(onlineApiClientProvider);
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!_isCurrent(generation)) {
        throw StateError('Platform request superseded');
      }
      try {
        final rawList = await client.fetchPlatforms(silentErrorMessage: true);
        if (!_isCurrent(generation)) {
          throw StateError('Platform request superseded');
        }
        final platforms = rawList
            .map(OnlinePlatform.fromMap)
            .toList(growable: false);
        if (platforms.isEmpty ||
            platforms.map((platform) => platform.id).toSet().length !=
                platforms.length) {
          throw StateError(
            AppI18n.t(
              ref.read(appConfigProvider),
              'startup.platforms_unavailable',
            ),
          );
        }
        if (_isCurrent(generation)) {
          // Explicit login/logout invalidates this generation. Token refresh
          // keeps the same session, so persist under its renewed credential.
          _cacheScope = _currentCacheScope();
          unawaited(
            ref
                .read(onlinePlatformCacheDataSourceProvider)
                .write(_cacheScope!, platforms),
          );
        }
        return List.unmodifiable(platforms);
      } catch (error) {
        final isTimeout =
            error is DioException &&
            (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout);
        if (!_isCurrent(generation) || !isTimeout || attempt == maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw StateError('Platform request attempts exhausted');
  }
}

final onlinePlatformsProvider =
    AsyncNotifierProvider<OnlinePlatformsController, List<OnlinePlatform>>(
      OnlinePlatformsController.new,
      retry: (_, _) => null,
    );
