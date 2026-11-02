import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/app_bottom_navigation_bar.dart';

void main() {
  final registry = AppSkinRegistry.builtIn(AppThemeAccent.appleBlue);
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino headers follow page transparency in $brightness', (
      tester,
    ) async {
      for (final skinId in [
        AppSkinRegistry.classicId,
        AppSkinRegistry.starlitMelodyId,
        AppSkinRegistry.citySoundCreatorId,
      ]) {
        for (final enabled in [false, true]) {
          final skin = registry.resolve(skinId);
          final theme = brightness == Brightness.light
              ? AppTheme.light(
                  skin,
                  uiStyle: AppUiStyle.cupertino,
                  showContentBackground: enabled,
                )
              : AppTheme.dark(
                  skin,
                  uiStyle: AppUiStyle.cupertino,
                  showContentBackground: enabled,
                );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                appBar: const AppNavigationBar(title: Text('Page')),
                body: const AppSkinSurface(
                  role: AppSkinSurfaceRole.miniPlayer,
                  child: SizedBox(height: 50, child: Text('Playback controls')),
                ),
                bottomNavigationBar: AppBottomNavigationBar(
                  child: NavigationBar(
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person),
                        label: 'My',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final bar = tester.widget<CupertinoNavigationBar>(
            find.byType(CupertinoNavigationBar),
          );
          expect(
            bar.backgroundColor!.a,
            skinId == AppSkinRegistry.classicId ? 1 : 0,
          );
          expect(bar.brightness, brightness);
          if (skinId != AppSkinRegistry.classicId) {
            expect(bar.border, isNull);
          }
          final overlays = tester
              .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
                find.descendant(
                  of: find.byType(CupertinoNavigationBar),
                  matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                ),
              );
          expect(overlays, isNotEmpty);
          for (final overlay in overlays) {
            expect(
              overlay.value.statusBarIconBrightness,
              brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
            );
          }
          expect(
            tester
                .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
                .backgroundColor!
                .a,
            1,
          );
          final mini =
              tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byType(AppSkinSurface),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect(mini.color!.a, 1);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is BackdropFilter && widget.enabled,
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('Cupertino header honors an explicit opaque page background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(
          registry.resolve(AppSkinRegistry.starlitMelodyId),
          uiStyle: AppUiStyle.cupertino,
        ),
        home: const Scaffold(
          backgroundColor: Colors.white,
          appBar: AppNavigationBar(title: Text('Opaque page')),
        ),
      ),
    );
    final bar = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(bar.backgroundColor!.a, 1);
  });
}
