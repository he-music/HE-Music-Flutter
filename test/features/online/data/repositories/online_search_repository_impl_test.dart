import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/online/data/repositories/online_search_repository_impl.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';

void main() {
  test('fetchHotKeywords delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.fetchHotKeywords(platform: 'netease');

    expect(fake.lastHotKeywordsPlatform, 'netease');
    expect(result, hasLength(2));
  });

  test('fetchSearchSuggestions delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.fetchSearchSuggestions(
      keyword: 'test',
      platform: 'qq',
    );

    expect(fake.lastSuggestionKeyword, 'test');
    expect(result, hasLength(1));
  });

  test('fetchDefaultKeywords delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.fetchDefaultKeywords(platform: 'netease');

    expect(fake.lastDefaultPlatform, 'netease');
    expect(result, hasLength(1));
  });

  test('comprehensiveSearch delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.comprehensiveSearch(
      keyword: '周杰伦',
      platform: 'netease',
    );

    expect(fake.lastComprehensiveKeyword, '周杰伦');
    expect(result.keyword, '周杰伦');
  });

  test('searchMusic delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.searchMusic(
      keyword: '稻香',
      platform: 'qq',
      type: 'song',
      pageIndex: 2,
      pageSize: 20,
    );

    expect(fake.lastSearchKeyword, '稻香');
    expect(fake.lastSearchPlatform, 'qq');
    expect(fake.lastSearchPageIndex, 2);
    expect(fake.lastSearchPageSize, 20);
    expect(result, hasLength(1));
  });

  test('getSearchHistory delegates to historyDataSource', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.getSearchHistory();

    expect(history.listKeywordsCalled, isTrue);
    expect(result, contains('keyword1'));
  });

  test('saveSearchKeyword delegates to historyDataSource', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.saveSearchKeyword('new keyword');

    expect(history.lastAppendedKeyword, 'new keyword');
    expect(result, contains('new keyword'));
  });

  test('clearSearchHistory delegates to historyDataSource', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    await repo.clearSearchHistory();

    expect(history.clearKeywordsCalled, isTrue);
  });

  test('fetchHotKeywords propagates apiClient error', () async {
    final fake = _ThrowingOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    expect(() => repo.fetchHotKeywords(), throwsException);
  });
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());

  String? lastHotKeywordsPlatform;
  String? lastSuggestionKeyword;
  String? lastDefaultPlatform;
  String? lastComprehensiveKeyword;
  String? lastSearchKeyword;
  String? lastSearchPlatform;
  int? lastSearchPageIndex;
  int? lastSearchPageSize;

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) async {
    lastHotKeywordsPlatform = platform;
    return ['热门1', '热门2'];
  }

  @override
  Future<List<String>> fetchSearchSuggestions({
    required String keyword,
    String? platform,
  }) async {
    lastSuggestionKeyword = keyword;
    return ['suggestion'];
  }

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
  }) async {
    lastDefaultPlatform = platform;
    return [const SearchDefaultEntry(key: 'default', description: 'desc')];
  }

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) async {
    lastComprehensiveKeyword = keyword;
    return OnlineComprehensiveSearchResult(keyword: keyword);
  }

  @override
  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    lastSearchKeyword = keyword;
    lastSearchPlatform = platform;
    lastSearchPageIndex = pageIndex;
    lastSearchPageSize = pageSize;
    return [
      {'id': '1', 'title': 'Song'},
    ];
  }
}

class _FakeSearchHistoryDataSource extends SearchHistoryDataSource {
  _FakeSearchHistoryDataSource() : super();

  bool listKeywordsCalled = false;
  String? lastAppendedKeyword;
  bool clearKeywordsCalled = false;

  @override
  Future<List<String>> listKeywords() async {
    listKeywordsCalled = true;
    return ['keyword1', 'keyword2'];
  }

  @override
  Future<List<String>> appendKeyword(String keyword) async {
    lastAppendedKeyword = keyword;
    return [keyword, 'keyword1'];
  }

  @override
  Future<void> clearKeywords() async {
    clearKeywordsCalled = true;
  }
}

class _ThrowingOnlineApiClient extends OnlineApiClient {
  _ThrowingOnlineApiClient() : super(Dio());

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) =>
      throw Exception('network error');

  @override
  Future<List<String>> fetchSearchSuggestions({
    required String keyword,
    String? platform,
  }) => throw Exception('network error');

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({String? platform}) =>
      throw Exception('network error');

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) => throw Exception('network error');

  @override
  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
    int pageIndex = 1,
    int pageSize = 30,
  }) => throw Exception('network error');
}
