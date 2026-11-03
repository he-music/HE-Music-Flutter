import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_message_service.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets(
    'Material snackbar clears persistent playback chrome and keyboard',
    (tester) async {
      await _pumpHost(tester);
      expect(
        MediaQuery.sizeOf(
          rootNavigatorKey.currentState!.overlay!.context,
        ).width,
        400,
      );
      expect(AppMessageService.messengerKey.currentState, isNotNull);
      AppMessageService.showError('Material error');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(ToastificationTheme), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(_chromeKey)).dy),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byType(SnackBar)).dy, lessThan(500));
      expect(tester.takeException(), isNull);
      await _dismiss(tester);
    },
  );

  testWidgets('wide layouts retain a top-right toast', (tester) async {
    await _pumpHost(tester, width: 1000, platform: TargetPlatform.macOS);
    AppMessageService.showError('Desktop error');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Desktop error'), findsOneWidget);
    final center = tester.getCenter(find.text('Desktop error'));
    expect(center.dx, greaterThan(700));
    expect(center.dy, lessThan(150));
    await _dismiss(tester);
  });

  testWidgets(
    'desktop actionable toast follows theme and invokes action once',
    (tester) async {
      final brightness = ValueNotifier(Brightness.light);
      addTearDown(brightness.dispose);
      await _pumpHost(
        tester,
        width: 1000,
        platform: TargetPlatform.macOS,
        brightness: brightness,
        accessibleNavigation: true,
      );
      var actions = 0;
      AppMessageService.showError(
        'Desktop retry',
        actionLabel: 'Try again',
        onAction: () => actions++,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Desktop retry'), findsOneWidget);
      final colors = tester
          .widgetList<Container>(find.byType(Container))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color?.toARGB32());
      expect(
        colors,
        contains(ThemeData.dark().colorScheme.surfaceContainerHigh.toARGB32()),
      );
      final callback = tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Try again'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(find.text('Desktop retry'), findsNothing);
    },
  );

  testWidgets(
    'empty messages are ignored and repeated messages are deduplicated',
    (tester) async {
      await _pumpHost(tester);
      AppMessageService.showError('  ');
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      AppMessageService.showError('Repeated error');
      AppMessageService.showError('Repeated error');
      await tester.pumpAndSettle();
      expect(find.text('Repeated error'), findsOneWidget);
      await _dismiss(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Repeated error'), findsNothing);
    },
  );

  testWidgets('fallback messenger host shows an actionable SDK message', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      configuredMessenger: false,
      accessibleNavigation: true,
    );
    expect(AppMessageService.messengerKey.currentState, isNull);
    var actions = 0;
    AppMessageService.showError(
      'Fallback host error',
      actionLabel: 'Retry fallback',
      onAction: () => actions++,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Fallback host error'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    await tester.tap(find.text('Retry fallback'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Fallback host error'), findsNothing);
  });

  testWidgets(
    'same message dedupes within one overlay and appears in a new host',
    (tester) async {
      await _pumpHost(tester, configuredMessenger: false);
      final firstOverlay = rootNavigatorKey.currentState!.overlay;
      AppMessageService.showInfo('Same host-independent message');
      await tester.pumpAndSettle();
      final firstSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      AppMessageService.showInfo('Same host-independent message');
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)),
        same(firstSnackBar),
      );
      await _dismiss(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpHost(tester, configuredMessenger: false);
      expect(rootNavigatorKey.currentState!.overlay, isNot(same(firstOverlay)));
      AppMessageService.showInfo('Same host-independent message');
      await tester.pumpAndSettle();
      expect(find.text('Same host-independent message'), findsOneWidget);
      await _dismiss(tester);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final style in AppUiStyle.values) {
      testWidgets('$platform $style wide mobile uses SDK feedback', (
        tester,
      ) async {
        await _pumpHost(tester, width: 1000, platform: platform, style: style);
        AppMessageService.showInfo('Wide mobile $platform $style');
        await tester.pumpAndSettle();
        expect(find.byType(ToastificationTheme), findsNothing);
        expect(
          find.byType(SnackBar),
          style == AppUiStyle.material ? findsOneWidget : findsNothing,
        );
        if (style == AppUiStyle.cupertino) {
          expect(
            find.byKey(const ValueKey('cupertino-app-message')),
            findsOneWidget,
          );
          await tester.tap(find.byIcon(CupertinoIcons.xmark));
        } else {
          await _dismiss(tester);
        }
        await tester.pumpAndSettle();
      });
    }
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$platform narrow desktop retains toast', (tester) async {
      await _pumpHost(
        tester,
        width: 400,
        platform: platform,
        style: AppUiStyle.cupertino,
      );
      expect(
        Theme.of(rootNavigatorKey.currentState!.overlay!.context).platform,
        platform,
      );
      AppMessageService.showInfo('Narrow desktop $platform');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(ToastificationTheme), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('cupertino-app-message')), findsNothing);
      await _dismiss(tester);
    });
  }

  testWidgets('platform changes keep accessible action alive and single-use', (
    tester,
  ) async {
    final platform = ValueNotifier(TargetPlatform.android);
    addTearDown(platform.dispose);
    await _pumpHost(
      tester,
      width: 1000,
      platformListenable: platform,
      style: AppUiStyle.cupertino,
      accessibleNavigation: true,
    );
    var actions = 0;
    AppMessageService.showError(
      'Platform lifecycle',
      actionLabel: 'Retry platform',
      onAction: () => actions++,
    );
    await tester.pumpAndSettle();
    for (final next in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      platform.value = next;
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Platform lifecycle'), findsOneWidget);
      expect(actions, 0);
      expect(
        find.byKey(const ValueKey('cupertino-app-message')),
        next == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
    }
    final callback = tester
        .widget<CupertinoButton>(
          find.ancestor(
            of: find.text('Retry platform'),
            matching: find.byType(CupertinoButton),
          ),
        )
        .onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Platform lifecycle'), findsNothing);
  });

  for (final style in AppUiStyle.values) {
    testWidgets('$style message expires and exposes a live region', (
      tester,
    ) async {
      await _pumpHost(tester, style: style);
      AppMessageService.showInfo('Transient $style');
      await tester.pumpAndSettle();
      final semantics = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.text('Transient $style'),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        semantics.any((widget) => widget.properties.liveRegion == true),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Transient $style'), findsNothing);
    });

    testWidgets('$style accessible action persists and executes at most once', (
      tester,
    ) async {
      await _pumpHost(tester, style: style, accessibleNavigation: true);
      var count = 0;
      AppMessageService.showError(
        'Action $style',
        actionLabel: 'Retry',
        onAction: () => count++,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Action $style'), findsOneWidget);
      // Invoke the same captured callback twice to cover stale/double actions.
      final VoidCallback callback;
      if (style == AppUiStyle.material) {
        callback = tester
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
      } else {
        callback = tester
            .widget<CupertinoButton>(
              find.ancestor(
                of: find.text('Retry'),
                matching: find.byType(CupertinoButton),
              ),
            )
            .onPressed!;
      }
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(count, 1);
      expect(find.text('Action $style'), findsNothing);
    });
  }

  testWidgets('Cupertino uses a dismissible SDK overlay', (tester) async {
    await _pumpHost(tester, style: AppUiStyle.cupertino);
    AppMessageService.showSuccess('Cupertino saved');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(ToastificationTheme), findsNothing);
    expect(find.byKey(const ValueKey('cupertino-app-message')), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(tester.getCenter(find.text('Cupertino saved')).dy, lessThan(150));
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();
    expect(find.text('Cupertino saved'), findsNothing);
  });

  testWidgets(
    'open message follows interface and brightness without repeating action',
    (tester) async {
      final style = ValueNotifier(AppUiStyle.material);
      final brightness = ValueNotifier(Brightness.light);
      addTearDown(style.dispose);
      addTearDown(brightness.dispose);
      await _pumpHost(tester, styleListenable: style, brightness: brightness);
      var actions = 0;
      AppMessageService.showError(
        'Style update',
        actionLabel: 'Retry',
        onAction: () => actions++,
      );
      await tester.pumpAndSettle();
      style.value = AppUiStyle.cupertino;
      brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final surface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('cupertino-app-message')),
      );
      expect(
        (surface.decoration as BoxDecoration).color?.toARGB32(),
        CupertinoColors.secondarySystemGroupedBackground.darkColor.toARGB32(),
      );
      style.value = AppUiStyle.material;
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Style update'), findsOneWidget);
      expect(actions, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(actions, 1);
    },
  );
}

const _chromeKey = ValueKey('persistent-playback-chrome');

Future<void> _pumpHost(
  WidgetTester tester, {
  double width = 400,
  TargetPlatform platform = TargetPlatform.android,
  ValueNotifier<TargetPlatform>? platformListenable,
  AppUiStyle style = AppUiStyle.material,
  bool accessibleNavigation = false,
  bool configuredMessenger = true,
  ValueNotifier<AppUiStyle>? styleListenable,
  ValueNotifier<Brightness>? brightness,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final styleValue = styleListenable ?? ValueNotifier(style);
  final brightnessValue = brightness ?? ValueNotifier(Brightness.light);
  final platformValue = platformListenable ?? ValueNotifier(platform);
  if (platformListenable == null) addTearDown(platformValue.dispose);
  if (styleListenable == null) addTearDown(styleValue.dispose);
  if (brightness == null) addTearDown(brightnessValue.dispose);
  await tester.pumpWidget(
    ListenableBuilder(
      listenable: Listenable.merge([
        styleValue,
        brightnessValue,
        platformValue,
      ]),
      builder: (context, _) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: configuredMessenger
            ? AppMessageService.messengerKey
            : null,
        theme: ThemeData(
          platform: platformValue.value,
          brightness: brightnessValue.value,
          extensions: [AppUiTheme(style: styleValue.value)],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: accessibleNavigation),
          child: AppUiStyleScope(style: styleValue.value, child: child!),
        ),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: const SizedBox(key: _chromeKey, height: 160),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dismiss(WidgetTester tester) async {
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
  }
  toastification.dismissAll(delayForAnimation: false);
  await tester.pumpAndSettle();
}
