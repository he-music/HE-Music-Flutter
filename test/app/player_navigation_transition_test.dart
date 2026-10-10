import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_route_page.dart';

const _detailPaths = [
  AppRoutes.albumDetail,
  AppRoutes.artistDetail,
  AppRoutes.songDetail,
  AppRoutes.onlineComments,
  AppRoutes.onlineSearch,
];
const _headerKey = ValueKey('player-header');

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final skinId in [
      AppSkinRegistry.classicId,
      AppSkinRegistry.citySoundCreatorId,
    ]) {
      testWidgets(
        '$platform $skinId details never paint home during push or pop',
        (tester) async {
          final skin = AppSkinRegistry.builtIn(
            AppThemeAccent.forest,
          ).resolve(skinId);
          final captureKey = GlobalKey();
          final router = GoRouter(
            initialLocation: AppRoutes.home,
            routes: [
              ShellRoute(
                builder: (_, _, child) => child,
                routes: [
                  GoRoute(
                    path: AppRoutes.home,
                    builder: (_, _) => const Scaffold(
                      body: SizedBox.expand(
                        child: ColoredBox(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.player,
                pageBuilder: (_, state) => PlayerRoutePage(
                  key: state.pageKey,
                  child: Builder(
                    builder: (context) => Scaffold(
                      backgroundColor: Colors.green,
                      body: PlayerDismissRegion(
                        onDismiss: () async => context.pop(),
                        child: const SizedBox(
                          key: _headerKey,
                          height: 80,
                          width: double.infinity,
                          child: Center(child: Text('Player')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final path in _detailPaths)
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(body: Center(child: Text(path))),
                ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              theme: AppTheme.light(skin).copyWith(platform: platform),
              routerConfig: router,
              builder: (_, child) => RepaintBoundary(
                key: captureKey,
                // Models the root wallpaper, which sits outside Navigator.
                child: ColoredBox(color: Colors.blue, child: child),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(await _hasHomePixels(tester, captureKey), isTrue);
          unawaited(openFullPlayer(tester.element(find.byType(Scaffold))));
          await tester.pumpAndSettle();
          _expectOpaquePlayer(tester);

          Future<void> checkTransition(String description) async {
            await tester.pump();
            // Inspect every 16ms throughout the longest supported transition.
            for (var frame = 0; frame < 30; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(
                await _hasHomePixels(tester, captureKey),
                isFalse,
                reason: '$description frame $frame',
              );
            }
            await tester.pumpAndSettle();
          }

          for (final path in _detailPaths) {
            unawaited(router.push<void>(path));
            await checkTransition('$path push');
            expect(find.text(path), findsOneWidget);
            router.pop();
            await checkTransition('$path pop');
            expect(router.state.uri.path, AppRoutes.player);
          }

          // A canceled dismissal must restore the same opacity contract as entry.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(_headerKey)),
          );
          await gesture.moveBy(const Offset(0, 60));
          await tester.pump(const Duration(milliseconds: 300));
          await gesture.up();
          await tester.pumpAndSettle();
          _expectOpaquePlayer(tester);
          unawaited(router.push<void>(AppRoutes.albumDetail));
          await checkTransition('album after rebound');
          router.pop();
          await checkTransition('album back after rebound');
          expect(find.text('Player'), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
          expect(await _hasHomePixels(tester, captureKey), isTrue);
        },
      );
    }
  }
}

void _expectOpaquePlayer(WidgetTester tester) {
  final route = ModalRoute.of(tester.element(find.byKey(_headerKey)))!;
  expect(route.animation!.value, 1);
  expect(route.opaque, isTrue);
  expect(route.overlayEntries.first.opaque, isTrue);
}

Future<bool?> _hasHomePixels(WidgetTester tester, GlobalKey captureKey) {
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
        if (bytes.getUint8(offset) == 244 &&
            bytes.getUint8(offset + 1) == 67 &&
            bytes.getUint8(offset + 2) == 54) {
          return true;
        }
      }
      return false;
    } finally {
      image.dispose();
    }
  });
}
