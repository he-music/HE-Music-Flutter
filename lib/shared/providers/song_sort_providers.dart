import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/he_music_models.dart';
import '../utils/song_sort.dart';

final songSortPreferenceProvider =
    NotifierProvider<SongSortPreferenceController, SongSortPreference>(
      SongSortPreferenceController.new,
    );

final sortedSongInfoProvider = Provider.autoDispose
    .family<List<SongInfo>, List<SongInfo>>((ref, songs) {
      return sortSongItems(
        songs,
        ref.watch(songSortPreferenceProvider),
        valuesOf: SongSortValues.fromSong,
      );
    });

class SongSortPreferenceController extends Notifier<SongSortPreference> {
  static const storageKey = 'song_list_sort';
  late Future<void> _hydration;
  Future<void> _writes = Future<void>.value();
  bool _edited = false;

  @override
  SongSortPreference build() {
    _hydration = _hydrate();
    return const SongSortPreference();
  }

  Future<void> waitUntilHydrated() => _hydration;

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (stored == null || !ref.mounted || _edited) return;
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return;
      final field = SongSortField.values
          .where((field) => field.name == decoded['field'])
          .firstOrNull;
      if (field == null || decoded['ascending'] is! bool) return;
      state = SongSortPreference(
        field: field,
        ascending: decoded['ascending'] as bool,
      );
    } on Exception {
      // A corrupt or unavailable local preference keeps the original order.
    }
  }

  Future<void> setPreference(SongSortPreference preference) {
    _edited = true;
    state = preference;
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        storageKey,
        jsonEncode({
          'field': preference.field.name,
          'ascending': preference.ascending,
        }),
      );
      if (!saved) throw StateError('Unable to save song sorting preference');
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
