import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_content.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_field.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_section.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';
import 'package:he_music_flutter/features/song/domain/repositories/song_detail_repository.dart';
import 'package:he_music_flutter/features/song/presentation/providers/song_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  for (final fails in [false, true]) {
    test(
      'late detail ${fails ? 'error' : 'response'} cannot replace a newer song',
      () async {
        final oldDetail = Completer<SongDetailContent>();
        final repository = _Repository()..pending = oldDetail;
        final container = ProviderContainer(
          overrides: [
            songDetailRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final provider = songDetailControllerProvider('shared');
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        final controller = container.read(provider.notifier);
        final older = controller.initialize(_request('old'));
        await controller.initialize(_request('new'));
        final current = container.read(provider);
        expect(current.content!.song.id, 'new');
        if (fails) {
          oldDetail.completeError(StateError('stale failure'));
        } else {
          oldDetail.complete(_detail('old'));
        }
        await older;
        expect(container.read(provider), same(current));
        expect(current.errorMessage, isNull);
      },
    );
  }

  test(
    'one detail request exposes fields and sections and repeated initialize is deduplicated',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [songDetailRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final request = _request('song');
      final provider = songDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await controller.initialize(request);
      await controller.initialize(request);
      final state = container.read(provider);
      expect(repository.calls, 1);
      expect(state.loading, false);
      expect(state.content!.fields.single.value, '1704067200');
      expect(state.content!.sections.single.songs.single.platform, 'netease');
      await controller.retry(request);
      expect(repository.calls, 2);
    },
  );

  test('failed detail can be retried', () async {
    final repository = _Repository()..fails = true;
    final container = ProviderContainer(
      overrides: [songDetailRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final request = _request('song');
    final provider = songDetailControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    await controller.initialize(request);
    expect(container.read(provider).content, isNull);
    expect(container.read(provider).errorMessage, contains('failed'));
    repository.fails = false;
    await controller.retry(request);
    expect(container.read(provider).content, isNotNull);
    expect(container.read(provider).errorMessage, isNull);
  });
}

SongDetailRequest _request(String id) =>
    SongDetailRequest(id: id, platform: 'qq', title: id);
SongDetailContent _detail(String id) => SongDetailContent(
  song: SongInfo.fromMap({'id': id, 'name': id, 'platform': 'qq'}),
  fields: const [SongDetailField(label: '时间', value: '1704067200')],
  sections: [
    SongDetailSection(
      resourceType: 'song',
      title: '版本',
      songs: [
        SongInfo.fromMap({
          'id': 'related',
          'name': '相关',
          'platform': 'netease',
        }),
      ],
    ),
  ],
);

class _Repository implements SongDetailRepository {
  Completer<SongDetailContent>? pending;
  int calls = 0;
  bool fails = false;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    calls++;
    if (fails) throw StateError('failed');
    return request.id == 'old' ? pending!.future : _detail(request.id);
  }
}
