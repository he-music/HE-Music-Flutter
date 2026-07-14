import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/config/app_config_controller.dart';
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

  @override
  SearchDefaultPlaceholderState build() {
    ref.onDispose(() {
      _reloadTimer?.cancel();
      _rotateTimer?.cancel();
    });
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_initialize);
    }
    return const SearchDefaultPlaceholderState();
  }

  Future<void> _initialize() async {
    await refresh();
    _reloadTimer ??= Timer.periodic(_reloadInterval, (_) {
      unawaited(refresh());
    });
    _rotateTimer ??= Timer.periodic(_rotateInterval, (_) {
      _rotate();
    });
  }

  Future<void> refresh() async {
    final platforms = await ref.read(onlinePlatformsProvider.future);
    final platform = platforms
        .where(
          (item) =>
              item.available &&
              item.supports(PlatformFeatureSupportFlag.getSearchDefault),
        )
        .firstOrNull;
    if (platform == null) {
      return;
    }
    try {
      final next = await ref
          .read(onlineSearchRepositoryProvider)
          .fetchDefaultKeywords(platform: platform.id);
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

class OnlinePlatformsController extends AsyncNotifier<List<OnlinePlatform>> {
  Future<List<OnlinePlatform>>? _inFlight;

  @override
  Future<List<OnlinePlatform>> build() async {
    // Router 可能在 startup gate 展示期间提前构建首页，控制器自身也必须守住水合边界。
    await ref.read(appConfigProvider.notifier).waitUntilHydrated();
    return _startFetch();
  }

  Future<List<OnlinePlatform>> ensureLoaded({bool forceRefresh = false}) async {
    final current = state.value;
    if (!forceRefresh && current != null && current.isNotEmpty) {
      return current;
    }
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    state = forceRefresh ? const AsyncLoading() : state;
    final next = await _guardFetch();
    return next;
  }

  Future<void> refresh() async {
    await ensureLoaded(forceRefresh: true);
  }

  Future<List<OnlinePlatform>> _guardFetch() async {
    try {
      final next = await _startFetch();
      state = AsyncData(next);
      return next;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<OnlinePlatform>> _startFetch() {
    return _inFlight ??= _runFetch();
  }

  Future<List<OnlinePlatform>> _runFetch() async {
    try {
      return await _fetchPlatforms();
    } finally {
      _inFlight = null;
    }
  }

  Future<List<OnlinePlatform>> _fetchPlatforms() async {
    final client = ref.read(onlineApiClientProvider);
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final rawList = await client.fetchPlatforms(silentErrorMessage: true);
        return rawList.map(OnlinePlatform.fromMap).toList(growable: false);
      } catch (error) {
        final isTimeout =
            error is DioException &&
            (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout);
        if (!isTimeout || attempt == maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return const <OnlinePlatform>[];
  }
}

final onlinePlatformsProvider =
    AsyncNotifierProvider<OnlinePlatformsController, List<OnlinePlatform>>(
      OnlinePlatformsController.new,
      retry: (_, _) => null,
    );
