import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets(
    'online search defaults to comprehensive when platform supports it',
    (tester) async {
      await tester.pumpWidget(
        _buildOnlineSearchApp(initialKeyword: 'Taylor Swift'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('All'), findsOneWidget);
    },
  );

  testWidgets(
    'online search does not refetch comprehensive result for same key',
    (tester) async {
      final client = _SearchPageOnlineApiClient();
      await tester.pumpWidget(
        _buildOnlineSearchApp(
          initialKeyword: 'Taylor Swift',
          initialType: 'all',
          client: client,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(client.comprehensiveSearchCallCount, 1);

      await tester.tap(find.text('Songs'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump();

      expect(client.comprehensiveSearchCallCount, 1);
    },
  );

  testWidgets('online search reloads hot keywords when platforms load later', (
    tester,
  ) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();
    final client = _SearchPageOnlineApiClient();

    await tester.pumpWidget(
      _buildOnlineSearchApp(
        client: client,
        platformsFuture: platformsCompleter.future,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Taylor Swift'), findsOneWidget);
    expect(find.text('平台热词'), findsNothing);

    platformsCompleter.complete(_searchPlatforms);
    await tester.pump();
    await tester.pump();

    expect(find.text('平台热词'), findsOneWidget);
  });
}

Widget _buildOnlineSearchApp({
  String? initialKeyword,
  String? initialType,
  OnlineApiClient? client,
  Future<List<OnlinePlatform>>? platformsFuture,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_MiniPlayerTestController.new),
      onlinePlatformsProvider.overrideWith(
        () => _SearchPlatformsController(platformsFuture),
      ),
      onlineApiClientProvider.overrideWithValue(
        client ?? _SearchPageOnlineApiClient(),
      ),
      searchHistoryDataSourceProvider.overrideWithValue(
        const _SearchHistoryDataSourceStub(),
      ),
      searchDefaultPlaceholderProvider.overrideWith(
        _StaticSearchDefaultPlaceholderController.new,
      ),
    ],
    child: MaterialApp(
      home: OnlineSearchPage(
        platform: 'qq',
        initialKeyword: initialKeyword,
        initialType: initialType,
      ),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _MiniPlayerTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/song-1.mp3',
          ),
        ],
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _SearchPlatformsController extends OnlinePlatformsController {
  _SearchPlatformsController([this.platformsFuture]);

  final Future<List<OnlinePlatform>>? platformsFuture;

  @override
  Future<List<OnlinePlatform>> build() async {
    return platformsFuture ?? _searchPlatforms;
  }
}

final _searchPlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag:
        PlatformFeatureSupportFlag.getSearchHotkey |
        PlatformFeatureSupportFlag.comprehensiveSearch |
        PlatformFeatureSupportFlag.searchSong |
        PlatformFeatureSupportFlag.searchSinger |
        PlatformFeatureSupportFlag.searchPlaylist,
  ),
];

class _SearchPageOnlineApiClient extends OnlineApiClient {
  _SearchPageOnlineApiClient() : super(Dio());

  int comprehensiveSearchCallCount = 0;

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) async {
    return const <String>['平台热词'];
  }

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
  }) async {
    return const <SearchDefaultEntry>[
      SearchDefaultEntry(key: '周杰伦', description: '稻香'),
    ];
  }

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) async {
    comprehensiveSearchCallCount += 1;
    return OnlineComprehensiveSearchResult(
      keyword: keyword,
      artist: OnlineComprehensiveSearchSection(
        items: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'artist-1',
            'platform': 'qq',
            'name': 'Taylor Swift',
            'cover': '',
            'song_count': 10,
            'album_count': 5,
            'mv_count': 1,
          },
        ],
      ),
      song: OnlineComprehensiveSearchSection(
        items: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'song-1',
            'platform': 'qq',
            'name': 'Love Story',
            'artist': 'Taylor Swift',
            'artists': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'artist-1', 'name': 'Taylor Swift'},
            ],
            'album': <String, dynamic>{'id': 'album-1', 'name': 'Fearless'},
            'cover': '',
            'duration': 235,
            'links': <Map<String, dynamic>>[],
          },
        ],
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    if (type == 'song') {
      return const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'song-1',
          'platform': 'qq',
          'name': 'Love Story',
          'artist': 'Taylor Swift',
          'artists': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'artist-1', 'name': 'Taylor Swift'},
          ],
          'album': <String, dynamic>{'id': 'album-1', 'name': 'Fearless'},
          'cover': '',
          'duration': 235,
          'links': <Map<String, dynamic>>[],
        },
      ];
    }
    return const <Map<String, dynamic>>[];
  }
}

class _SearchHistoryDataSourceStub extends SearchHistoryDataSource {
  const _SearchHistoryDataSourceStub();

  @override
  Future<List<String>> listKeywords() async {
    return const <String>['周杰伦'];
  }
}

class _StaticSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState(
      entries: <SearchDefaultEntry>[
        SearchDefaultEntry(key: '周杰伦', description: '稻香'),
      ],
      currentIndex: 0,
    );
  }
}
