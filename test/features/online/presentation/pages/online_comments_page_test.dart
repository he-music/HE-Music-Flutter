import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_comments_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';

void main() {
  testWidgets('online comments first load shows comment row skeletons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final initialCompleter = Completer<OnlineCommentPageResult>();
    final client = _ControllableOnlineApiClient(initialCompleter.future);

    await tester.pumpWidget(_buildCommentsApp(client));
    await tester.pump();

    final loadingSkeleton = find.byKey(
      const ValueKey<String>('comments-loading-skeleton'),
    );
    expect(loadingSkeleton, findsOneWidget);
    expect(
      find.descendant(
        of: loadingSkeleton,
        matching: find.byType(AppSkinContentSurface),
      ),
      findsNWidgets(5),
    );
    final skeletonBoxes = tester.widgetList<SkeletonBox>(
      find.descendant(of: loadingSkeleton, matching: find.byType(SkeletonBox)),
    );
    expect(skeletonBoxes.where((box) => box.height == 48), isEmpty);
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
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('comment-replies-loading-skeleton'),
        ),
        matching: find.byType(AppSkinContentSurface),
      ),
      findsNWidgets(4),
    );

    client.subCommentRequests.single.complete(
      _commentResult(<Map<String, dynamic>>[_comment('子回复')]),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('子回复', findRichText: true),
        matching: find.byType(AppSkinContentSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reply sheet loads more replies near list bottom', (
    tester,
  ) async {
    final parent = _comment('父评论', replyCount: 16);
    final client = _ControllableOnlineApiClient(
      Future.value(_commentResult(<Map<String, dynamic>>[parent])),
    );
    await tester.pumpWidget(_buildCommentsApp(client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部回复（16）'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(client.subCommentRequests, hasLength(1));
    expect(client.subCommentPageIndexes, <int>[1]);
    client.subCommentRequests.single.complete(
      _commentResult(
        List<Map<String, dynamic>>.generate(
          15,
          (index) => _comment('子回复 $index'),
        ),
        hasMore: true,
        lastId: 'reply-cursor-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载更多回复'), findsNothing);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump();

    expect(client.subCommentRequests, hasLength(2));
    expect(client.subCommentPageIndexes, <int>[1, 2]);

    client.subCommentRequests.last.complete(
      _commentResult(<Map<String, dynamic>>[_comment('最后一条回复')]),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('comment rows and reply preview follow content background', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.classicId);
    final client = _ControllableOnlineApiClient(
      Future.value(
        _commentResult(<Map<String, dynamic>>[_comment('父评论', replyCount: 2)]),
      ),
    );

    await tester.pumpWidget(
      _buildCommentsApp(client, theme: AppTheme.light(skin)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSkinContentSurface), findsOneWidget);
    expect(find.byType(AppSkinSurface), findsNothing);
    var preview = tester.widget<Container>(
      find.byKey(const ValueKey<String>('comment-reply-preview')),
    );
    expect((preview.decoration! as BoxDecoration).color?.a, 0);

    await tester.pumpWidget(
      _buildCommentsApp(
        client,
        theme: AppTheme.light(skin, showContentBackground: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSkinSurface), findsOneWidget);
    preview = tester.widget<Container>(
      find.byKey(const ValueKey<String>('comment-reply-preview')),
    );
    expect(
      (preview.decoration! as BoxDecoration).color,
      skin.light.colors.cardBackground,
    );
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

Widget _buildCommentsApp(OnlineApiClient client, {ThemeData? theme}) {
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
      theme: theme,
      child: const OnlineCommentsPage(
        resourceId: 'song-1',
        resourceType: 'song',
        platform: 'qq',
        title: '测试歌曲',
      ),
    ),
  );
}

OnlineCommentPageResult _commentResult(
  List<Map<String, dynamic>> list, {
  bool hasMore = false,
  String lastId = '',
}) {
  return OnlineCommentPageResult(
    list: list,
    hasMore: hasMore,
    lastId: lastId,
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
  final List<Completer<OnlineCommentPageResult>> subCommentRequests =
      <Completer<OnlineCommentPageResult>>[];
  final List<int> subCommentPageIndexes = <int>[];
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
    final request = Completer<OnlineCommentPageResult>();
    subCommentRequests.add(request);
    subCommentPageIndexes.add(pageIndex);
    return request.future;
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

Widget _buildTestApp({
  required String localeCode,
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: Locale(localeCode),
    theme: theme,
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
