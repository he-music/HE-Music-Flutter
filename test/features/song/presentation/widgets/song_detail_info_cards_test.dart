import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_field.dart';
import 'package:he_music_flutter/features/song/presentation/widgets/song_detail_info_cards.dart';

void main() {
  testWidgets('source and duration remain when backend fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(_app(fields: const []));
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('QQ音乐'), findsOneWidget);
    expect(find.text('时长'), findsOneWidget);
    expect(find.text('03:35'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('song-detail-fields')),
      findsNothing,
    );
  });

  testWidgets(
    'each field has its own card and repeated labels retain order and text',
    (tester) async {
      await tester.pumpWidget(
        _app(
          fields: const [
            SongDetailField(label: '时间', value: ' 1704067200 '),
            SongDetailField(label: '时间', value: '2024/1/1（首发）'),
            SongDetailField(label: '语言', value: '国语'),
          ],
        ),
      );
      expect(find.byType(Card), findsNWidgets(5));
      expect(find.text('时间'), findsNWidgets(2));
      expect(find.text(' 1704067200 '), findsOneWidget);
      expect(find.text('2024/1/1（首发）'), findsOneWidget);
      for (var index = 0; index < 3; index++) {
        final field = find.byKey(ValueKey<String>('song-detail-field-$index'));
        expect(
          find.descendant(of: field, matching: find.byType(Card)),
          findsOneWidget,
        );
      }
      expect(
        tester.getTopLeft(_field(0)).dx,
        lessThan(tester.getTopLeft(_field(1)).dx),
      );
      expect(
        tester.getTopLeft(_field(1)).dx,
        lessThan(tester.getTopLeft(_field(2)).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final skinId in [
    AppSkinRegistry.classicId,
    AppSkinRegistry.citySoundCreatorId,
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'all information cards follow content background toggle for $skinId/$brightness',
        (tester) async {
          final skin = AppSkinRegistry.builtIn(
            AppThemeAccent.forest,
          ).resolve(skinId);
          const cards = SongDetailInfoCards(
            source: 'QQ音乐',
            duration: '03:35',
            sourceLabel: '来源',
            durationLabel: '时长',
            fields: [
              SongDetailField(label: '语言', value: '国语'),
              SongDetailField(label: '发行时间', value: '2024-01-01'),
            ],
          );
          final keys = [
            'song-detail-source-card',
            'song-detail-duration-card',
            'song-detail-field-0',
            'song-detail-field-1',
          ];
          List<Rect>? initialRects;
          for (final enabled in [false, true, false]) {
            final theme = brightness == Brightness.light
                ? AppTheme.light(skin, showContentBackground: enabled)
                : AppTheme.dark(skin, showContentBackground: enabled);
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: const Scaffold(body: cards),
              ),
            );
            await tester.pumpAndSettle();
            for (final key in keys) {
              final card = find.byKey(ValueKey<String>(key));
              final surface = tester.widget<Material>(
                find.descendant(of: card, matching: find.byType(Material)),
              );
              expect(surface.color, theme.cardTheme.color);
              expect(surface.color!.a, enabled ? isPositive : isZero);
            }
            final rects = [
              for (final key in keys)
                tester.getRect(find.byKey(ValueKey<String>(key))),
            ];
            initialRects ??= rects;
            expect(rects, initialRects);
            expect(
              tester.widget<SongDetailInfoCards>(
                find.byType(SongDetailInfoCards),
              ),
              same(cards),
            );
            expect(find.text('QQ音乐'), findsOneWidget);
            expect(find.text('03:35'), findsOneWidget);
            expect(find.text('国语'), findsOneWidget);
            expect(find.text('2024-01-01'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final scenario in [
    (width: 390.0, scale: 1.0, columns: 2),
    (width: 240.0, scale: 1.0, columns: 1),
    (width: 390.0, scale: 2.0, columns: 1),
    (width: 1000.0, scale: 1.0, columns: 4),
  ]) {
    testWidgets(
      'cards adapt to width ${scenario.width} and scale ${scenario.scale}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final longValue = List.filled(12, '保留完整的较长展示内容').join();
        await tester.pumpWidget(
          _app(
            scale: scenario.scale,
            fields: [
              SongDetailField(label: '说明', value: longValue),
              const SongDetailField(label: '语言', value: '国语'),
              const SongDetailField(label: '发行时间', value: '2024-01-01'),
              const SongDetailField(label: '唱片公司', value: '某某音乐'),
            ],
          ),
        );
        final first = tester.getRect(_field(0));
        final second = tester.getRect(_field(1));
        if (scenario.columns == 1) {
          expect(second.top, greaterThan(first.bottom));
          expect(second.left, first.left);
        } else {
          expect(second.top, first.top);
          expect(second.left, greaterThan(first.right));
          expect(second.height, first.height);
        }
        if (scenario.columns == 2) {
          expect(tester.getTopLeft(_field(2)).dy, greaterThan(first.bottom));
        }
        if (scenario.columns == 4) {
          expect(tester.getTopLeft(_field(3)).dy, first.top);
        }
        final text = tester.widget<Text>(find.text(longValue));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Finder _field(int index) =>
    find.byKey(ValueKey<String>('song-detail-field-$index'));

Widget _app({required List<SongDetailField> fields, double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SongDetailInfoCards(
                source: 'QQ音乐',
                duration: '03:35',
                sourceLabel: '来源',
                durationLabel: '时长',
                fields: fields,
              ),
            ),
          ),
        ),
      ),
    );
