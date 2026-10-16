import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_info.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/widgets/sheet_music_metadata.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    for (final originalKey in ['C', 'C调', '', '  ']) {
      testWidgets('formats key "$originalKey" consistently in $locale', (
        tester,
      ) async {
        final hasKey = originalKey.trim().isNotEmpty;
        final key = locale == 'zh' ? 'C调' : 'C';
        final pages = locale == 'zh' ? '3页' : '3 pages';
        final keyField = locale == 'zh' ? '原调：$key' : 'Original key: $key';
        final sheet = SheetMusicInfo(originalKey: originalKey, pageCount: 3);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SheetMusicMetadata(sheet: sheet, locale: locale),
                  SheetMusicMetadata(
                    sheet: sheet,
                    locale: locale,
                    showDetail: true,
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.text(hasKey ? '$key · $pages' : pages), findsOneWidget);
        expect(find.text(keyField), hasKey ? findsOneWidget : findsNothing);
        expect(find.textContaining('调调'), findsNothing);
        expect(find.textContaining('Key '), findsNothing);
        expect(
          find.text(locale == 'zh' ? '总页数：3' : 'Pages: 3'),
          findsOneWidget,
        );
      });
    }
  }
}
