import 'package:shared_preferences/shared_preferences.dart';

const _searchHistoryStorageKey = 'online_search_history_v1';
const _searchHistoryLimit = 20;

class SearchHistoryDataSource {
  const SearchHistoryDataSource();

  Future<List<String>> listKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_searchHistoryStorageKey) ?? <String>[];
    return list
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> appendKeyword(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return listKeywords();
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_searchHistoryStorageKey) ?? <String>[];
    final next = <String>[
      normalized,
      ...current.where((value) => value != normalized),
    ];
    final trimmed = next.take(_searchHistoryLimit).toList(growable: false);
    await prefs.setStringList(_searchHistoryStorageKey, trimmed);
    return trimmed;
  }

  Future<void> clearKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryStorageKey, const <String>[]);
  }

  Future<String?> preferredPlatform(String server) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('online_search_source_v1');
      return saved != null && saved.length == 2 && saved.first == server
          ? saved.last
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreferredPlatform(String server, String platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('online_search_source_v1', [server, platform]);
    } catch (_) {
      // A storage failure does not prevent searching.
    }
  }
}
