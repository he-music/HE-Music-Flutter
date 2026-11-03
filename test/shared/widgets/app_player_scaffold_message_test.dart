import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_message_service.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_player_scaffold.dart';

void main() {
  for (final hasPlayback in [false, true]) {
    testWidgets('nested playback shell clears IME with playback=$hasPlayback', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 900);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final style = ValueNotifier(AppUiStyle.material);
      final playback = ValueNotifier(hasPlayback);
      final text = TextEditingController();
      final focus = FocusNode();
      addTearDown(style.dispose);
      addTearDown(playback.dispose);
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: Listenable.merge([style, playback]),
          builder: (context, _) => MaterialApp(
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: AppMessageService.messengerKey,
            theme: ThemeData(
              platform: TargetPlatform.android,
              extensions: [AppUiTheme(style: style.value)],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
              child: AppUiStyleScope(style: style.value, child: child!),
            ),
            home: AppPlayerScaffold(
              body: Scaffold(
                body: TextField(controller: text, focusNode: focus),
              ),
              miniPlayer: playback.value
                  ? SizedBox(
                      key: const ValueKey('playback'),
                      height: style.value == AppUiStyle.material ? 68 : 92,
                    )
                  : const SizedBox.shrink(),
              navigation: SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                child: SizedBox(
                  key: const ValueKey('navigation'),
                  height: style.value == AppUiStyle.material ? 80 : 50,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'search draft');
      focus.requestFocus();
      final navigationBefore = tester.getRect(
        find.byKey(const ValueKey('navigation')),
      );
      final playbackBefore = hasPlayback
          ? tester.getRect(find.byKey(const ValueKey('playback')))
          : null;
      var actions = 0;
      AppMessageService.showError(
        'Search failed $hasPlayback',
        actionLabel: 'Retry',
        onAction: () => actions++,
      );
      await tester.pumpAndSettle();

      double chromeTop() => playback.value
          ? tester.getTopLeft(find.byKey(const ValueKey('playback'))).dy
          : tester.getTopLeft(find.byKey(const ValueKey('navigation'))).dy;
      Rect messageSurface() => tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final restingBottom = messageSurface().bottom;
      for (final keyboard in [360.0, 120.0, 0.0, 360.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        final bottom = messageSurface().bottom;
        expect(bottom, lessThanOrEqualTo(900 - keyboard));
        expect(bottom, lessThanOrEqualTo(chromeTop()));
        // Only the excess keyboard height is added; chrome is not counted twice.
        final expectedShift = math.max(0.0, keyboard - (900 - chromeTop()));
        expect(bottom, closeTo(restingBottom - expectedShift, 0.1));
        expect(
          tester.getRect(find.byKey(const ValueKey('navigation'))),
          navigationBefore,
        );
        if (playbackBefore != null) {
          expect(
            tester.getRect(find.byKey(const ValueKey('playback'))),
            playbackBefore,
          );
        }
      }
      // Re-measure chrome changes while the keyboard and same message stay open.
      playback.value = !hasPlayback;
      await tester.pumpAndSettle();
      expect(messageSurface().bottom, lessThanOrEqualTo(540));
      expect(messageSurface().bottom, lessThanOrEqualTo(chromeTop()));
      style.value = AppUiStyle.cupertino;
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey('cupertino-app-message')),
        findsOneWidget,
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('cupertino-app-message')))
            .dy,
        lessThan(540),
      );
      expect(text.text, 'search draft');
      expect(focus.hasFocus, isTrue);
      style.value = AppUiStyle.material;
      await tester.pumpAndSettle();
      expect(messageSurface().bottom, lessThanOrEqualTo(540));
      expect(messageSurface().bottom, lessThanOrEqualTo(chromeTop()));
      expect(text.text, 'search draft');
      expect(focus.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Retry'), findsOneWidget);
      expect(actions, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
