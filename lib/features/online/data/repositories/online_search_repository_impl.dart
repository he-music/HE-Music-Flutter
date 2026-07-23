import '../../data/datasources/search_history_data_source.dart';
import '../../data/online_api_client.dart';
import '../../domain/repositories/online_search_repository.dart';
import '../../presentation/pages/online_search_models.dart';

/// OnlineSearchRepository 的实现，委托给 OnlineApiClient 和 SearchHistoryDataSource。
class OnlineSearchRepositoryImpl implements OnlineSearchRepository {
  const OnlineSearchRepositoryImpl(this._apiClient, this._historyDataSource);

  final OnlineApiClient _apiClient;
  final SearchHistoryDataSource _historyDataSource;

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) {
    return _apiClient.fetchHotKeywords(platform: platform);
  }

  @override
  Future<List<String>> fetchSearchSuggestions({
    required String keyword,
    String? platform,
  }) {
    return _apiClient.fetchSearchSuggestions(
      keyword: keyword,
      platform: platform,
    );
  }

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
    bool silentErrorMessage = false,
  }) {
    return _apiClient.fetchDefaultKeywords(
      platform: platform,
      silentErrorMessage: silentErrorMessage,
    );
  }

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) {
    return _apiClient.comprehensiveSearch(keyword: keyword, platform: platform);
  }

  @override
  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
    int pageIndex = 1,
    int pageSize = 30,
  }) {
    return _apiClient.searchMusic(
      keyword: keyword,
      platform: platform,
      type: type,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> getSearchHistory() => _historyDataSource.listKeywords();

  @override
  Future<List<String>> saveSearchKeyword(String keyword) =>
      _historyDataSource.appendKeyword(keyword);

  @override
  Future<void> clearSearchHistory() => _historyDataSource.clearKeywords();
}
