import 'dart:async';

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
  testWidgets('online comments first load shows comment row skeletons', (
    tester,
  ) async {
    final initialCompleter = Completer<OnlineCommentPageResult>();
    final client = _ControllableOnlineApiClient(initialCompleter.future);

    await tester.pumpWidget(_buildCommentsApp(client));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('comments-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    initialCompleter.complete(_commentResult(const <Map<String, dynamic>>[]));
    await tester.pumpAndSettle();
  });

  testWidgets('comment refresh replaces on success and preserves on failure', (
    tester,
  ) async {
    final client = _ControllableOnlineApiClient(
      Future.value(_commentResult(<Map<String, dynamic>>[_comment('旧评论')])),
    );
    await tester.pumpWidget(_buildCommentsApp(client));
    await tester.pumpAndSettle();

    final firstRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pump();

    expect(find.text('旧评论', findRichText: true), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('comments-loading-skeleton')),
      findsNothing,
    );

    client.refreshRequests.single.complete(
      _commentResult(<Map<String, dynamic>>[_comment('新评论')]),
    );
    await firstRefresh;
    await tester.pump();

    expect(find.text('旧评论', findRichText: true), findsNothing);
    expect(find.text('新评论', findRichText: true), findsOneWidget);

    final secondRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pump();
    client.refreshRequests.last.completeError(Exception('刷新失败'));
    await secondRefresh;
    await tester.pump();

    expect(find.text('新评论', findRichText: true), findsOneWidget);
  });

  testWidgets('reply sheet first load shows compact reply skeletons', (
    tester,
  ) async {
    final parent = _comment('父评论', replyCount: 2);
    final client = _ControllableOnlineApiClient(
      Future.value(_commentResult(<Map<String, dynamic>>[parent])),
    );
    await tester.pumpWidget(_buildCommentsApp(client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部回复（2）'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('comment-replies-loading-skeleton')),
      findsOneWidget,
    );

    client.subCommentRequest.complete(
      _commentResult(const <Map<String, dynamic>>[]),
    );
    await tester.pumpAndSettle();
  });

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

Widget _buildCommentsApp(OnlineApiClient client) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(localeCode: 'zh'),
      ),
      onlineApiClientProvider.overrideWithValue(client),
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
  );
}

OnlineCommentPageResult _commentResult(List<Map<String, dynamic>> list) {
  return OnlineCommentPageResult(
    list: list,
    hasMore: false,
    lastId: '',
    totalCount: list.length,
  );
}

Map<String, dynamic> _comment(String content, {int replyCount = 0}) {
  return <String, dynamic>{
    'id': 'comment-$content',
    'comment_id': 'comment-$content',
    'content': content,
    'time': 0,
    'praise_count': 0,
    'reply_count': replyCount,
    'user': const <String, dynamic>{'nickname': '测试用户', 'avatar': ''},
    'sub_comments': const <Map<String, dynamic>>[],
  };
}

class _ControllableOnlineApiClient extends OnlineApiClient {
  _ControllableOnlineApiClient(this.initialResponse) : super(Dio());

  final Future<OnlineCommentPageResult> initialResponse;
  final List<Completer<OnlineCommentPageResult>> refreshRequests =
      <Completer<OnlineCommentPageResult>>[];
  final Completer<OnlineCommentPageResult> subCommentRequest =
      Completer<OnlineCommentPageResult>();
  int _commentCallCount = 0;

  @override
  Future<OnlineCommentPageResult> fetchCommentPage({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) {
    if (_commentCallCount++ == 0) {
      return initialResponse;
    }
    final request = Completer<OnlineCommentPageResult>();
    refreshRequests.add(request);
    return request.future;
  }

  @override
  Future<OnlineCommentPageResult> fetchSubCommentPage({
    required String resourceId,
    required String parentId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 15,
    String? lastId,
  }) {
    return subCommentRequest.future;
  }
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
