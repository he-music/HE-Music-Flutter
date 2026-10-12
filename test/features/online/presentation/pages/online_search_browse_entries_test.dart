import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_browse_entries.dart';

void main() {
  testWidgets('browse entries open their pages with the current platform', (
    tester,
  ) async {
    const destinations = <String, String>{
      'Ranking': '/ranking-list',
      'Playlist': '/playlist/plaza',
      'Artist': '/artist/plaza',
      'Video': '/video/plaza',
      'Radio': '/radio/plaza',
    };
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Column(
              children: [
                TextField(autofocus: true),
                OnlineSearchBrowseEntries(localeCode: 'en', platform: 'qq'),
              ],
            ),
          ),
        ),
        for (final route in destinations.values)
          GoRoute(
            path: route,
            builder: (context, state) =>
                Scaffold(body: Text(state.uri.toString())),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    for (final entry in destinations.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text('${entry.value}?platform=qq'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      router.pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['zh', 'en']) {
    testWidgets(
      'browse entries support narrow screens and large text in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OnlineSearchBrowseEntries(
                    localeCode: locale,
                    platform: 'qq',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entries = find.byType(OnlineSearchBrowseEntries);
        final radio = find.text(locale == 'zh' ? '电台' : 'Radio');
        expect(
          find.descendant(of: entries, matching: find.byType(Text)),
          findsNWidgets(5),
        );
        await tester.drag(entries, const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(radio.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
