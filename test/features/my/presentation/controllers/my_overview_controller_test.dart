import 'dart:async';

import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_overview_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'clear and a new account session discard delayed overview responses',
    () async {
      final repository = _DelayedOverviewRepository();
      final container = ProviderContainer(
        overrides: [myOverviewRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(myOverviewControllerProvider.notifier);
      final pending = controller.refresh();
      controller.clear();
      container.read(authSessionRevisionProvider.notifier).advance();
      await container.pump();
      repository.completer.complete(
        await const _SuccessMyOverviewRepository().fetchOverview(),
      );
      await pending;
      expect(container.read(myOverviewControllerProvider).overview, isNull);
      expect(container.read(myOverviewControllerProvider).loading, isFalse);
    },
  );
  test('initialize should load my overview', () async {
    final container = ProviderContainer(
      overrides: [
        myOverviewRepositoryProvider.overrideWithValue(
          const _SuccessMyOverviewRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myOverviewControllerProvider.notifier).initialize();
    final state = container.read(myOverviewControllerProvider);

    expect(state.loading, false);
    expect(state.errorMessage, isNull);
    expect(state.overview, isNotNull);
    expect(state.overview!.profile.username, 'wangjian');
    expect(state.overview!.summary.favoriteSongCount, 26);
  });

  test('refresh should expose failure', () async {
    final container = ProviderContainer(
      overrides: [
        myOverviewRepositoryProvider.overrideWithValue(
          const _FailedMyOverviewRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myOverviewControllerProvider.notifier).refresh();
    final state = container.read(myOverviewControllerProvider);

    expect(state.loading, false);
    expect(state.overview, isNull);
    expect(state.errorMessage, contains('network down'));
  });
}

class _SuccessMyOverviewRepository implements MyOverviewRepository {
  const _SuccessMyOverviewRepository();

  @override
  Future<MyOverview> fetchOverview() async {
    return const MyOverview(
      profile: MyProfile(
        id: '1861667707968032768',
        username: 'wangjian',
        nickname: '认真的雪',
        email: '',
        status: 1,
        avatarUrl: '',
      ),
      summary: MySummary(
        favoriteSongCount: 26,
        favoritePlaylistCount: 1,
        favoriteArtistCount: 1,
        favoriteAlbumCount: 1,
        createdPlaylistCount: 1,
      ),
    );
  }
}

class _FailedMyOverviewRepository implements MyOverviewRepository {
  const _FailedMyOverviewRepository();

  @override
  Future<MyOverview> fetchOverview() async {
    throw StateError('network down');
  }
}

class _DelayedOverviewRepository implements MyOverviewRepository {
  final completer = Completer<MyOverview>();
  @override
  Future<MyOverview> fetchOverview() => completer.future;
}
