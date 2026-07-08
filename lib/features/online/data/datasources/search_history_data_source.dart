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
}
