import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/providers/song_sort_providers.dart';
import 'package:he_music_flutter/shared/utils/song_sort.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:flutter/rendering.dart';
import 'package:he_music_flutter/shared/widgets/song_sort_button.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('ToolbarTest');
    for (final weight in ['Regular', 'Medium']) {
      loader.addFont(
        File(
          'test/assets/fonts/Roboto-$weight.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'restoring a preference updates the control without a queue callback',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SongSortPreferenceController.storageKey: jsonEncode({
          'field': 'title',
          'ascending': false,
        }),
      });
      var calls = 0;
      await tester.pumpWidget(_wrap(SongSortButton(onChanged: (_) => calls++)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.byTooltip('Sort songs: Title · Descending'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sort songs: Title · Descending'),
        findsOneWidget,
      );
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('confirming a new order persists it and notifies exactly once', (
    tester,
  ) async {
    final changes = <SongSortPreference>[];
    await tester.pumpWidget(_wrap(SongSortButton(onChanged: changes.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descending'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(changes, [
      const SongSortPreference(field: SongSortField.title, ascending: false),
    ]);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString(SongSortPreferenceController.storageKey)!),
      {'field': 'title', 'ascending': false},
    );
  });

  testWidgets(
    'incomplete lists disable sorting and unavailable fields are hidden',
    (tester) async {
      await tester.pumpWidget(_wrap(const SongSortButton(enabled: false)));
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
        find.byKey(const Key('song-sort-button')),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(
        _wrap(const SongSortButton(allowDuration: false)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-sort-button')));
      await tester.pumpAndSettle();
      expect(find.text('Duration'), findsNothing);
      expect(find.text('Size'), findsNothing);
      expect(find.text('Recently added'), findsNothing);
      expect(find.text('Title'), findsOneWidget);
    },
  );
  testWidgets('closing the sheet discards draft choices', (tester) async {
    final changes = <SongSortPreference>[];
    await tester.pumpWidget(_wrap(SongSortButton(onChanged: changes.add)));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongSortButton)),
    );
    await tester.tap(find.byKey(const Key('song-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(
      container.read(songSortPreferenceProvider),
      const SongSortPreference(),
    );
    await tester.tap(find.byKey(const Key('song-sort-close')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(
      container.read(songSortPreferenceProvider),
      const SongSortPreference(),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SongSortPreferenceController.storageKey), isNull);
  });

  testWidgets(
    'default order disables direction without changing sheet height',
    (tester) async {
      await tester.pumpWidget(_wrap(const SongSortButton(allowSize: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('song-sort-button')));
      await tester.pumpAndSettle();
      final directionFinder = find.byKey(const Key('song-sort-direction'));
      expect(
        tester
            .widget<SegmentedButton<bool>>(directionFinder)
            .onSelectionChanged,
        isNull,
      );
      final before = tester.getSize(find.byKey(const Key('song-sort-sheet')));
      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<bool>>(directionFinder)
            .onSelectionChanged,
        isNotNull,
      );
      expect(tester.getSize(find.byKey(const Key('song-sort-sheet'))), before);
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('song-sort-field-title')),
      );
      expect(
        semantics,
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          label: 'Title',
        ),
      );
    },
  );

  for (final glass in [false, true]) {
    testWidgets(
      'small screen and large text keep confirm visible with glass=$glass',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _wrap(
            const SongSortButton(allowSize: true),
            textScale: 2,
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('song-sort-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final confirm = find.byKey(const Key('song-sort-confirm'));
        expect(confirm.hitTestable(), findsOneWidget);
        final before = tester.getTopLeft(confirm);
        await tester.drag(
          find.byKey(const Key('song-sort-options')),
          const Offset(0, -800),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(confirm), before);
        expect(confirm.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('song-sort-sheet')), findsNothing);
      },
    );
  }
  testWidgets(
    'unsupported or inactive sorting shows default without changing the saved preference',
    (tester) async {
      for (final scenario in [
        (
          field: SongSortField.title,
          button: const SongSortButton(enabled: false),
        ),
        (
          field: SongSortField.duration,
          button: const SongSortButton(allowDuration: false),
        ),
        (field: SongSortField.size, button: const SongSortButton()),
      ]) {
        SharedPreferences.setMockInitialValues({
          SongSortPreferenceController.storageKey: jsonEncode({
            'field': scenario.field.name,
            'ascending': false,
          }),
        });
        await tester.pumpWidget(_wrap(scenario.button));
        await tester.pumpAndSettle();
        expect(find.text('Default'), findsOneWidget);
        expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SongSortButton)),
        );
        expect(
          container.read(songSortPreferenceProvider).field,
          scenario.field,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  for (final field in [
    SongSortField.title,
    SongSortField.artist,
    SongSortField.album,
    SongSortField.duration,
    SongSortField.size,
  ]) {
    testWidgets(
      'toolbar keeps ${field.name} visible beside play and batch with large text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({
          SongSortPreferenceController.storageKey: jsonEncode({
            'field': field.name,
            'ascending': true,
          }),
        });
        var played = 0;
        var batched = 0;
        await tester.pumpWidget(
          _wrap(
            MusicDetailPlayAllHeaderBox(
              countText: 'Play All 1000',
              onPlayAll: () => played++,
              onBatchAction: () => batched++,
              trailing: const SongSortButton(allowSize: true),
            ),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('song-sort-button')).hitTestable(),
          findsOneWidget,
        );
        final label = tester.renderObject<RenderParagraph>(
          find.byKey(const Key('song-sort-label')),
        );
        expect(label.didExceedMaxLines, isFalse);
        await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
        await tester.tap(find.byTooltip('Batch'));
        expect(played, 1);
        expect(batched, 1);
        await tester.tap(find.byKey(const Key('song-sort-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('song-sort-sheet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('song-sort-close')));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('changing fields uses consistent default directions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SongSortButton(
          preference: const SongSortPreference(field: SongSortField.title),
          fields: const [
            SongSortField.title,
            SongSortField.duration,
            SongSortField.size,
            SongSortField.createdAt,
          ],
          allowSize: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-sort-button')));
    await tester.pumpAndSettle();
    for (final label in ['Duration', 'Size', 'Recently added', 'Title']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('song-sort-sheet')),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<bool>>(
              find.byKey(const Key('song-sort-direction')),
            )
            .selected,
        {label == 'Title'},
      );
    }
  });

  testWidgets('controlled sorting only reports confirmation to its owner', (
    tester,
  ) async {
    final changes = <SongSortPreference>[];
    final button = SongSortButton(
      preference: const SongSortPreference(field: SongSortField.title),
      fields: const [SongSortField.title, SongSortField.createdAt],
      onChanged: changes.add,
    );
    await tester.pumpWidget(_wrap(button));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongSortButton)),
    );
    final global = container.read(songSortPreferenceProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('song-sort-button')));
    await tester.pumpAndSettle();
    expect(find.text('Default order'), findsNothing);
    expect(find.text('Artist'), findsNothing);
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.byKey(const Key('song-sort-confirm')));
    await tester.pumpAndSettle();
    expect(changes, [
      const SongSortPreference(
        field: SongSortField.createdAt,
        ascending: false,
      ),
    ]);
    expect(container.read(songSortPreferenceProvider), global);
    expect(find.byTooltip('Sort songs: Title · Ascending'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SongSortPreferenceController.storageKey), isNull);
  });
}

Widget _wrap(Widget child, {double textScale = 1, bool glass = false}) =>
    ProviderScope(
      overrides: [appConfigProvider.overrideWith(_TestAppConfig.new)],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'ToolbarTest'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: AppGlassScope(
            enabled: glass,
            child: GlassAdaptiveScope(
              minQuality: GlassQuality.minimal,
              maxQuality: GlassQuality.minimal,
              child: child!,
            ),
          ),
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );

class _TestAppConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'en');
}
