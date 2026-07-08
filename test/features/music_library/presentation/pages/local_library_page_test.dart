import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:he_music_flutter/features/music_library/presentation/pages/local_library_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('local library page uses standard app bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LocalLibraryPage())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('本地歌曲'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.folder_open_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.clear_all_rounded),
      ),
      findsOneWidget,
    );

    // 销毁 widget 树，触发 drift 流取消，再 pump 掉残留 timer
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
