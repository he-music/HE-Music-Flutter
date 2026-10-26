import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/providers/song_sort_providers.dart';
import 'package:he_music_flutter/shared/utils/song_sort.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists field and direction across provider containers', () async {
    final first = ProviderContainer();
    final controller = first.read(songSortPreferenceProvider.notifier);
    await controller.waitUntilHydrated();
    const preference = SongSortPreference(
      field: SongSortField.artist,
      ascending: false,
    );
    await controller.setPreference(preference);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(songSortPreferenceProvider.notifier).waitUntilHydrated();
    expect(second.read(songSortPreferenceProvider), preference);
  });

  test(
    'an edit before hydration wins over the previously saved preference',
    () async {
      SharedPreferences.setMockInitialValues({
        SongSortPreferenceController.storageKey: jsonEncode({
          'field': 'album',
          'ascending': false,
        }),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(songSortPreferenceProvider.notifier);
      const next = SongSortPreference(field: SongSortField.title);
      await controller.setPreference(next);
      await controller.waitUntilHydrated();
      expect(container.read(songSortPreferenceProvider), next);
    },
  );

  test('corrupt and unknown preferences fall back to original order', () async {
    for (final stored in ['{broken', '{"field":"removed","ascending":true}']) {
      SharedPreferences.setMockInitialValues({
        SongSortPreferenceController.storageKey: stored,
      });
      final container = ProviderContainer();
      await container
          .read(songSortPreferenceProvider.notifier)
          .waitUntilHydrated();
      expect(
        container.read(songSortPreferenceProvider),
        const SongSortPreference(),
      );
      container.dispose();
    }
  });

  test('rapid changes persist the last choice', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(songSortPreferenceProvider.notifier);
    final first = controller.setPreference(
      const SongSortPreference(field: SongSortField.title),
    );
    const last = SongSortPreference(
      field: SongSortField.duration,
      ascending: false,
    );
    final second = controller.setPreference(last);
    await Future.wait([first, second]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString(SongSortPreferenceController.storageKey)!),
      {'field': 'duration', 'ascending': false},
    );
  });

  test(
    'sorted list is cached and default restores the original source',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(songSortPreferenceProvider.notifier);
      await controller.waitUntilHydrated();
      final source = [_song('b', '上海'), _song('a', '北京')];
      final provider = sortedSongInfoProvider(source);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await controller.setPreference(
        const SongSortPreference(field: SongSortField.title),
      );
      final sorted = container.read(provider);
      expect(sorted.map((song) => song.id), ['a', 'b']);
      expect(container.read(provider), same(sorted));
      expect(source.first.id, 'b');
      await controller.setPreference(const SongSortPreference());
      expect(container.read(provider), same(source));
    },
  );
}

SongInfo _song(String id, String name) => SongInfo(
  name: name,
  subtitle: '',
  id: id,
  duration: 0,
  mvId: '',
  album: null,
  artists: const [],
  links: const [],
  platform: 'test',
  cover: '',
);
