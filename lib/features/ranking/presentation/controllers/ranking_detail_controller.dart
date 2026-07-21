import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ranking_detail.dart';
import '../../domain/entities/ranking_detail_request.dart';
import '../../domain/entities/ranking_song.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../../data/providers/ranking_providers.dart';

class RankingDetailState {
  const RankingDetailState({
    required this.loading,
    required this.loadingMore,
    required this.songs,
    required this.hasMore,
    required this.pageIndex,
    this.detail,
    this.errorMessage,
  });

  final bool loading;
  final bool loadingMore;
  final RankingDetail? detail;
  final List<RankingSong> songs;
  final bool hasMore;
  final int pageIndex;
  final String? errorMessage;

  RankingDetailState copyWith({
    bool? loading,
    bool? loadingMore,
    RankingDetail? detail,
    List<RankingSong>? songs,
    bool? hasMore,
    int? pageIndex,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RankingDetailState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      detail: detail ?? this.detail,
      songs: songs ?? this.songs,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = RankingDetailState(
    loading: true,
    loadingMore: false,
    detail: null,
    songs: <RankingSong>[],
    hasMore: false,
    pageIndex: 1,
    errorMessage: null,
  );
}

class RankingDetailController extends Notifier<RankingDetailState> {
  String _lastKey = '';

  @override
  RankingDetailState build() {
    return RankingDetailState.initial;
  }

  Future<void> initialize(RankingDetailRequest request) async {
    if (_lastKey == request.cacheKey && state.detail != null) {
      return;
    }
    _lastKey = request.cacheKey;
    await _loadFirst(request);
  }

  Future<void> retry(RankingDetailRequest request) async {
    await _loadFirst(request);
  }

  Future<void> loadMore(RankingDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    final detail = state.detail;
    if (detail == null || !state.hasMore || state.loadingMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final nextPage = state.pageIndex + 1;
      final next = await _repo.fetchRankingDetail(
        id: request.id,
        platform: request.platform,
        pageIndex: nextPage,
        lastId: detail.lastId,
      );
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        detail: next,
        songs: <RankingSong>[...state.songs, ...next.songs],
        hasMore: next.hasMore,
        pageIndex: nextPage,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(loadingMore: false, errorMessage: '$error');
    }
  }

  Future<void> _loadFirst(RankingDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loading: true,
      loadingMore: false,
      songs: const <RankingSong>[],
      pageIndex: 1,
      clearError: true,
    );
    try {
      final detail = await _repo.fetchRankingDetail(
        id: request.id,
        platform: request.platform,
        pageIndex: 1,
      );
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        detail: detail,
        songs: detail.songs,
        hasMore: detail.hasMore,
        pageIndex: 1,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  RankingRepository get _repo => ref.read(rankingRepositoryProvider);
}
