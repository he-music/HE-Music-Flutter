import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_comments_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

void main() {
  testWidgets('online comments page shows english texts for en locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _TestAppConfigController(localeCode: 'en'),
          ),
          onlineApiClientProvider.overrideWithValue(_FakeOnlineApiClient()),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
        ],
        child: _buildTestApp(
          localeCode: 'en',
          child: const OnlineCommentsPage(
            resourceId: 'song-1',
            resourceType: 'song',
            platform: 'qq',
            title: 'Test Song',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Song · Comments'), findsOneWidget);
  });

  testWidgets(
    'online comments page shows localized tab totals and empty state',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(
              () => _TestAppConfigController(localeCode: 'zh'),
            ),
            onlineApiClientProvider.overrideWithValue(_FakeOnlineApiClient()),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
          ],
          child: _buildTestApp(
            localeCode: 'zh',
            child: const OnlineCommentsPage(
              resourceId: 'song-1',
              resourceType: 'song',
              platform: 'qq',
              title: '测试歌曲',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('热门评论'), findsOneWidget);
      expect(find.text('1.2万'), findsOneWidget);
      expect(find.text('暂无热门评论'), findsOneWidget);

      await tester.tap(find.text('最新评论'));
      await tester.pumpAndSettle();

      expect(find.text('1200'), findsOneWidget);
      expect(find.text('测试用户'), findsOneWidget);
    },
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({this.localeCode = 'zh'});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: localeCode);
  }
}

Widget _buildTestApp({required String localeCode, required Widget child}) {
  return MaterialApp(
    locale: Locale(localeCode),
    supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());

  @override
  Future<OnlineCommentPageResult> fetchCommentPage({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) async {
    final list = isHot
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'comment_id': 'comment-1',
              'content': '测试评论',
              'time': DateTime.now().millisecondsSinceEpoch,
              'praise_count': 1,
              'reply_count': 2,
              'user': <String, dynamic>{'nickname': '测试用户', 'avatar': ''},
              'sub_comments': const <Map<String, dynamic>>[
                <String, dynamic>{
                  'comment_id': 'sub-1',
                  'content': '子评论',
                  'time': 0,
                  'praise_count': 0,
                  'reply_count': 0,
                  'user': <String, dynamic>{'nickname': '回复用户', 'avatar': ''},
                },
              ],
            },
          ];
    return OnlineCommentPageResult(
      list: list,
      hasMore: false,
      lastId: '',
      totalCount: isHot ? 12000 : 1200,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchComments({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'comment_id': 'comment-1',
        'content': '测试评论',
        'time': DateTime.now().millisecondsSinceEpoch,
        'praise_count': 1,
        'reply_count': 2,
        'user': <String, dynamic>{'nickname': '测试用户', 'avatar': ''},
        'sub_comments': const <Map<String, dynamic>>[
          <String, dynamic>{
            'comment_id': 'sub-1',
            'content': '子评论',
            'time': 0,
            'praise_count': 0,
            'reply_count': 0,
            'user': <String, dynamic>{'nickname': '回复用户', 'avatar': ''},
          },
        ],
      },
    ];
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'current-song',
        title: '正在播放',
        artist: '测试歌手',
        platform: 'qq',
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}
