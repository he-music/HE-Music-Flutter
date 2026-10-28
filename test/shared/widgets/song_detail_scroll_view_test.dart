import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/shared/widgets/song_detail_scroll_view.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('long list reveals control and returns both list and cover', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map(
        (node) => node.getSemanticsData().tooltip,
      ),
      isNot(contains('回到顶部')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_button.hitTestable(), findsNothing);

    await _scrollDown(tester);
    expect(_button.hitTestable(), findsOneWidget);
    expect(tester.getSemantics(_button).getSemanticsData().tooltip, '回到顶部');
    final scroll = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    expect(scroll.outerController.offset, greaterThan(0));
    expect(scroll.innerController.offset, greaterThan(0));
    await tester.tap(_button);
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.innerController.offset, greaterThan(0));
    await tester.pumpAndSettle();
    expect(scroll.outerController.offset, 0);
    expect(scroll.innerController.offset, 0);
    expect(find.text('封面').hitTestable(), findsOneWidget);
    expect(find.text('歌曲 0').hitTestable(), findsOneWidget);
    expect(_button.hitTestable(), findsNothing);
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map(
        (node) => node.getSemanticsData().tooltip,
      ),
      isNot(contains('回到顶部')),
    );
    semantics.dispose();
  });

  testWidgets('short list never reveals control', (tester) async {
    await tester.pumpWidget(_app(itemCount: 3));
    await tester.pumpAndSettle();
    await _scrollDown(tester);
    expect(_button.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance follows glass modes without losing scroll position', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_app(harnessKey: key));
    await tester.pumpAndSettle();
    await _scrollDown(tester);
    final scroll = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    final offset = scroll.innerController.offset;
    for (final mode in AppGlassMode.values) {
      key.currentState!.update(mode: mode);
      await tester.pumpAndSettle();
      expect(_button.hitTestable(), findsOneWidget);
      expect(scroll.innerController.offset, offset);
      if (mode.usesGlass) {
        final button = tester.widget<GlassIconButton>(
          find.byType(GlassIconButton),
        );
        expect(
          button.quality,
          mode == AppGlassMode.low
              ? GlassQuality.minimal
              : GlassQuality.standard,
        );
        expect(button.useOwnLayer, isTrue);
      } else {
        expect(find.byType(GlassIconButton), findsNothing);
        expect(find.byTooltip('回到顶部').hitTestable(), findsOneWidget);
      }
    }
    key.currentState!.update(mode: AppGlassMode.standard);
    await tester.pumpAndSettle();
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(scroll.innerController.offset, 0);
    expect(scroll.outerController.offset, 0);
    await _scrollDown(tester);
    key.currentState!.update(mode: AppGlassMode.standard, highContrast: true);
    await tester.pumpAndSettle();
    expect(find.byType(GlassIconButton), findsNothing);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(scroll.innerController.offset, 0);
    expect(scroll.outerController.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch mode hides control and restores it on exit', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_app(harnessKey: key));
    await tester.pumpAndSettle();
    await _scrollDown(tester);
    key.currentState!.update(batchMode: true);
    await tester.pumpAndSettle();
    expect(_button.hitTestable(), findsNothing);
    key.currentState!.update(batchMode: false);
    await tester.pumpAndSettle();
    expect(_button.hitTestable(), findsOneWidget);
  });

  testWidgets(
    'system reduce motion updates live and skin animation is independent',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_app(harnessKey: key));
      await tester.pumpAndSettle();
      await _scrollDown(tester);
      final context = tester.element(find.byType(SongDetailScrollView));
      final container = ProviderScope.containerOf(context);
      final config = container.read(appConfigProvider.notifier) as _TestConfig;
      config.disableSkinAnimation();
      await tester.pump();
      expect(MediaQuery.disableAnimationsOf(context), isFalse);
      final scroll = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      await tester.tap(_button);
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.innerController.offset, greaterThan(0));
      await tester.pumpAndSettle();

      await _scrollDown(tester);
      key.currentState!.update(reduceMotion: true);
      await tester.pumpAndSettle();
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      await tester.tap(_button);
      // A single pump must complete the jump rather than start a scroll animation.
      await tester.pump();
      expect(scroll.innerController.offset, 0);
      expect(scroll.outerController.offset, 0);
      await tester.pump();
      expect(_button.hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('control stays above changing player clearance', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_app(harnessKey: key));
    await tester.pumpAndSettle();
    await _scrollDown(tester);
    final initialBottom = tester.getBottomRight(_button).dy;
    key.currentState!.update(mode: AppGlassMode.standard, bottomInset: 104);
    await tester.pumpAndSettle();
    expect(tester.getSize(_button), const Size(48, 48));
    expect(tester.getBottomRight(_button).dy, initialBottom - 104);
    key.currentState!.update(bottomInset: 24);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(_button).dy, initialBottom - 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling and visibility changes do not rebuild list content', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(_app(onListBuild: () => builds++));
    await tester.pumpAndSettle();
    final initialBuilds = builds;
    await _scrollDown(tester);
    expect(_button.hitTestable(), findsOneWidget);
    expect(builds, initialBuilds);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(builds, initialBuilds);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(builds, initialBuilds);
  });
}

Finder get _button => find.byWidgetPredicate(
  (widget) =>
      widget is GlassIconButton ||
      widget is IconButton && widget.tooltip == '回到顶部',
);

Future<void> _scrollDown(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
  }
}

Widget _app({
  GlobalKey<_HarnessState>? harnessKey,
  int itemCount = 100,
  VoidCallback? onListBuild,
}) => ProviderScope(
  overrides: [appConfigProvider.overrideWith(_TestConfig.new)],
  child: MaterialApp(
    home: _Harness(
      key: harnessKey,
      itemCount: itemCount,
      onListBuild: onListBuild,
    ),
  ),
);

class _TestConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');

  void disableSkinAnimation() {
    state = state.copyWith(enableSkinAnimation: false);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.itemCount, this.onListBuild, super.key});

  final int itemCount;
  final VoidCallback? onListBuild;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  AppGlassMode mode = AppGlassMode.off;
  bool batchMode = false;
  bool reduceMotion = false;
  bool highContrast = false;
  double bottomInset = 0;

  void update({
    AppGlassMode? mode,
    bool? batchMode,
    bool? reduceMotion,
    bool? highContrast,
    double? bottomInset,
  }) {
    setState(() {
      this.mode = mode ?? this.mode;
      this.batchMode = batchMode ?? this.batchMode;
      this.reduceMotion = reduceMotion ?? this.reduceMotion;
      this.highContrast = highContrast ?? this.highContrast;
      this.bottomInset = bottomInset ?? this.bottomInset;
    });
  }

  @override
  Widget build(BuildContext context) => AppGlassScope(
    enabled: mode != AppGlassMode.off,
    mode: mode,
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: EdgeInsets.only(bottom: bottomInset),
        disableAnimations: reduceMotion,
        highContrast: highContrast,
      ),
      // Keep the shell mounted while exercising the control's live preferences.
      child: GlassScaffold(
        edgeToEdge: true,
        body: SongDetailScrollView(
          batchMode: batchMode,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            const SliverAppBar(
              pinned: true,
              expandedHeight: 240,
              flexibleSpace: FlexibleSpaceBar(title: Text('封面')),
            ),
          ],
          body: Builder(
            builder: (context) {
              widget.onListBuild?.call();
              return ListView.builder(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: widget.itemCount,
                itemExtent: 64,
                itemBuilder: (context, index) => Text('歌曲 $index'),
              );
            },
          ),
        ),
      ),
    ),
  );
}
