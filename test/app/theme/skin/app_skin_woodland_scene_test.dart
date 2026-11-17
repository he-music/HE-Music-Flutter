import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_woodland_scene.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('ambient frames repaint without rebuilding the scene child', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      _host(
        child: Builder(
          builder: (_) {
            builds++;
            return const ColoredBox(color: Colors.teal);
          },
        ),
      ),
    );
    final motion = _motion(tester);
    final before = motion.value;
    final originalBuilds = builds;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, isNot(before));
    expect(builds, originalBuilds);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    '120 Hz frames do not drive more than 30 ambient updates per second',
    (tester) async {
      await tester.pumpWidget(_host());
      final motion = _motion(tester);
      var updates = 0;
      motion.addListener(() => updates++);
      for (var frame = 0; frame < 240; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      expect(updates, inInclusiveRange(58, 61));
      await tester.pumpWidget(_host(enabled: false));
      final pausedUpdates = updates;
      await tester.pump(const Duration(seconds: 1));
      expect(updates, pausedUpdates);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'skin switch freezes only the scene and preserves system preference',
    (tester) async {
      final systemValues = <bool>[];
      final child = Builder(
        builder: (context) {
          systemValues.add(MediaQuery.disableAnimationsOf(context));
          return const ColoredBox(color: Colors.teal);
        },
      );
      await tester.pumpWidget(_host(child: child));
      final motion = _motion(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_host(enabled: false, child: child));
      final paused = motion.value;
      await tester.pump(const Duration(seconds: 2));
      expect(motion.value, paused);
      expect(systemValues, everyElement(isFalse));
      expect(_motion(tester), same(motion));
      await tester.pumpWidget(_host(child: child));
      await tester.pump(const Duration(seconds: 1));
      expect(motion.value, isNot(paused));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system reduced motion pauses a running scene and resumes live', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final motion = _motion(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_host(reduceMotion: true));
    final paused = motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(motion.value, paused);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, isNot(paused));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden scene and background app stop their animation clocks', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final motion = _motion(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_host(tickerEnabled: false));
    final hidden = motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(motion.value, hidden);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, isNot(hidden));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final background = motion.value;
    await tester.pump(const Duration(seconds: 2));
    expect(motion.value, background);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, isNot(background));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

ValueListenable<double> _motion(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .singleWhere(
        (widget) => widget.foregroundPainter is WoodlandAtmospherePainter,
      );
  return (paint.foregroundPainter! as WoodlandAtmospherePainter).motion;
}

Widget _host({
  bool enabled = true,
  bool reduceMotion = false,
  bool tickerEnabled = true,
  Widget child = const ColoredBox(color: Colors.teal),
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: TickerMode(
      enabled: tickerEnabled,
      child: AppSkinWoodlandScene(enabled: enabled, child: child),
    ),
  ),
);
