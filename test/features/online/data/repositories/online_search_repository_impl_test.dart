import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/online/data/repositories/online_search_repository_impl.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

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

  test('searchSongs delegates typed song search to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final repo = OnlineSearchRepositoryImpl(
      fake,
      _FakeSearchHistoryDataSource(),
    );

    final result = await repo.searchSongs(
      keyword: '稻香',
      platform: 'qq',
      pageIndex: 2,
      pageSize: 20,
    );

    expect(fake.lastSearchKind, 'song');
    expect(result.items.single.song.id, 'song-1');
  });

  test('searchLyrics delegates typed lyric search to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final repo = OnlineSearchRepositoryImpl(
      fake,
      _FakeSearchHistoryDataSource(),
    );

    final result = await repo.searchLyrics(keyword: '故事', platform: 'qq');

    expect(fake.lastSearchKind, 'lyric');
    expect(result.items.single.lyricSnippet, '故事的小黄花');
  });

  test('fetchDefaultKeywords delegates to apiClient', () async {
    final fake = _FakeOnlineApiClient();
    final history = _FakeSearchHistoryDataSource();
    final repo = OnlineSearchRepositoryImpl(fake, history);

    final result = await repo.fetchDefaultKeywords(
      platform: 'netease',
      silentErrorMessage: true,
    );

    expect(fake.lastDefaultPlatform, 'netease');
    expect(fake.lastDefaultSilentErrorMessage, isTrue);
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
      type: 'playlist',
      pageIndex: 2,
      pageSize: 20,
    );

    expect(fake.lastSearchKeyword, '稻香');
    expect(fake.lastSearchPlatform, 'qq');
    expect(fake.lastSearchPageIndex, 2);
    expect(fake.lastSearchPageSize, 20);
    expect(result.items, hasLength(1));
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
  bool? lastDefaultSilentErrorMessage;
  String? lastComprehensiveKeyword;
  String? lastSearchKeyword;
  String? lastSearchPlatform;
  int? lastSearchPageIndex;
  int? lastSearchPageSize;
  String? lastSearchKind;

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
    bool silentErrorMessage = false,
  }) async {
    lastDefaultPlatform = platform;
    lastDefaultSilentErrorMessage = silentErrorMessage;
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
  Future<OnlineSearchPageResult<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    required String type,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    lastSearchKeyword = keyword;
    lastSearchPlatform = platform;
    lastSearchPageIndex = pageIndex;
    lastSearchPageSize = pageSize;
    return OnlineSearchPageResult<Map<String, dynamic>>(
      platform: platform,
      keyword: keyword,
      items: const <Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'title': 'Playlist'},
      ],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 1,
      hasMore: false,
    );
  }

  @override
  Future<OnlineSearchPageResult<SearchSongInfo>> searchSongs({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    lastSearchKind = 'song';
    return _searchSongResult(
      keyword: keyword,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<OnlineSearchPageResult<SearchSongInfo>> searchLyrics({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    lastSearchKind = 'lyric';
    return _searchSongResult(
      keyword: keyword,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}

OnlineSearchPageResult<SearchSongInfo> _searchSongResult({
  required String keyword,
  required String platform,
  required int pageIndex,
  required int pageSize,
}) {
  return OnlineSearchPageResult<SearchSongInfo>(
    platform: platform,
    keyword: keyword,
    items: <SearchSongInfo>[
      SearchSongInfo(
        song: SongInfo.fromMap(<String, dynamic>{
          'id': 'song-1',
          'name': '稻香',
          'platform': platform,
        }),
        sublist: const <SearchSongInfo>[],
        originalType: 1,
        lyricSnippet: '故事的小黄花',
        lyric: '',
        matchedKeywords: <String>[keyword],
      ),
    ],
    pageIndex: pageIndex,
    pageSize: pageSize,
    totalCount: 1,
    hasMore: false,
  );
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
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
    bool silentErrorMessage = false,
  }) => throw Exception('network error');

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) => throw Exception('network error');

  @override
  Future<OnlineSearchPageResult<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    required String type,
    int pageIndex = 1,
    int pageSize = 30,
  }) => throw Exception('network error');
}
