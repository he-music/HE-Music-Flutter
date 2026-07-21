import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_state.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_discover_controller.dart';
import 'package:he_music_flutter/features/home/presentation/pages/home_page.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_discover_providers.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview_state.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_overview_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('home page uses page gutter only on mobile home tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    final titleTopLeft = tester.getTopLeft(
      find.text('What do you want to hear?'),
    );

    expect(titleTopLeft.dx, 12);
  });

  testWidgets('home page uses page gutter only on mobile my tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    // 骨架动画会持续运行，只推进页面切换动画所需的固定时长。
    await tester.pump(const Duration(milliseconds: 500));

    final listViewTopLeft = tester.getTopLeft(
      find.descendant(of: find.byType(MyPage), matching: find.byType(ListView)),
    );

    expect(listViewTopLeft.dx, 0);
  });

  testWidgets('home page quick entries allow multiline english labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    final playlistLabel = tester.widget<Text>(find.text('Playlist'));

    expect(playlistLabel.maxLines, 2);
    expect(playlistLabel.textAlign, TextAlign.center);
  });

  testWidgets('home page keeps mobile navigation on wide layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3840, 2700);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      homeDiscoverControllerProvider.overrideWith(
        _TestHomeDiscoverController.new,
      ),
      myOverviewControllerProvider.overrideWith(_TestMyOverviewController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      searchDefaultPlaceholderProvider.overrideWith(
        _TestSearchDefaultPlaceholderController.new,
      ),
      myCreatedPlaylistsProvider.overrideWith(
        (ref) async => const <MyFavoriteItem>[],
      ),
      myFavoritePlaylistsProvider.overrideWith(
        (ref) async => const <MyFavoriteItem>[],
      ),
      favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
      favoriteCollectionStatusProvider.overrideWith(
        _TestFavoriteCollectionStatus.new,
      ),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'en',
      authToken: 'token',
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}

class _TestHomeDiscoverController extends HomeDiscoverController {
  @override
  HomeDiscoverState build() {
    return HomeDiscoverState.initial;
  }

  @override
  Future<void> initialize() async {}
}

class _TestMyOverviewController extends MyOverviewController {
  @override
  MyOverviewState build() {
    return MyOverviewState.initial;
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return const <OnlinePlatform>[];
  }
}

class _TestSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

class _TestFavoriteSongStatus extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return FavoriteSongStatusState.initial;
  }
}

class _TestFavoriteCollectionStatus extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState.initial;
  }
}
