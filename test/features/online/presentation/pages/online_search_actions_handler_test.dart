import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_actions_handler.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';

void main() {
  testWidgets('audiobook opens album detail with fallback platform', (
    tester,
  ) async {
    Uri? detailUri;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => openSearchDetail(
                context: context,
                type: SearchType.audiobook,
                item: {'id': 'book-1', 'name': '故事'},
                fallbackPlatformId: 'qq',
                localeCode: 'zh-CN',
                onError: (message) => fail(message),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.albumDetail,
          builder: (context, state) {
            detailUri = state.uri;
            return const Scaffold(body: Text('Album detail'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Album detail'), findsOneWidget);
    expect(detailUri?.queryParameters, {
      'id': 'book-1',
      'platform': 'qq',
      'title': '故事',
    });
  });
}
