import '../../data/online_api_client.dart';
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

  /// 按类型搜索（song / playlist / album / artist / mv）。
  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
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
