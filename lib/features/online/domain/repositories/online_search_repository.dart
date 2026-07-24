import '../../data/online_api_client.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../presentation/pages/online_search_models.dart';

/// 在线搜索功能的抽象接口。
///
/// 封装搜索关键词、建议、综合搜索、歌曲搜索及搜索历史管理。
abstract class OnlineSearchRepository {
  /// 获取指定平台的热门搜索关键词。
  Future<List<String>> fetchHotKeywords({String? platform});

  /// 获取搜索建议（自动补全）。
  Future<List<String>> fetchSearchSuggestions({
    required String keyword,
    String? platform,
  });

  /// 获取搜索框默认占位关键词。
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
    bool silentErrorMessage = false,
  });

  /// 综合搜索（返回歌曲、歌单、专辑、视频、歌手等多个维度）。
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  });

  /// 搜索歌单、专辑、歌手或 MV 等非歌曲资源。
  Future<OnlineSearchPageResult<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    required String type,
    int pageIndex = 1,
    int pageSize = 30,
  });

  /// 搜索歌曲，返回包含搜索元数据的歌曲包装结果。
  Future<OnlineSearchPageResult<SearchSongInfo>> searchSongs({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  });

  /// 根据歌词内容搜索歌曲。
  Future<OnlineSearchPageResult<SearchSongInfo>> searchLyricSong({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  });

  /// 读取搜索历史关键词列表。
  Future<List<String>> getSearchHistory();

  /// 保存一条搜索关键词到历史记录（自动去重）。
  Future<List<String>> saveSearchKeyword(String keyword);

  /// 清空搜索历史。
  Future<void> clearSearchHistory();
}
