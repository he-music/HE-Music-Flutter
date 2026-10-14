import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_material.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_surface.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/music_control_surface.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'list playback bars share frosting and preserve mini optics in $brightness',
      (tester) async {
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: Column(
              children: [
                MusicDetailPlayAllHeaderBox(
                  countText: 'Play All 5',
                  onPlayAll: () {},
                ),
                const AppGlassSurface(
                  role: AppSkinSurfaceRole.miniPlayer,
                  child: SizedBox(height: 52, width: 200),
                ),
                const SongBatchActionBar(enabled: false),
                const Expanded(child: ArtistSongsLoadingView()),
              ],
            ),
          ),
        );
        await tester.pump();
        final surfaces = tester.widgetList<GlassContainer>(
          find.descendant(
            of: find.byType(MusicControlSurface),
            matching: find.byType(GlassContainer),
          ),
        );
        expect(surfaces, hasLength(3));
        final material = surfaces.first.settings!;
        for (final surface in surfaces) {
          expect(surface.settings, material);
          expect(surface.useOwnLayer, isTrue);
        }
        expect(material.blur, AppGlassMaterial.sheet.blur);
        expect(
          material.refractiveIndex,
          AppGlassMaterial.sheet.refractiveIndex,
        );
        expect(material.backerColor!.a, inExclusiveRange(0, 1));
        final mini = tester.widget<GlassContainer>(
          find.descendant(
            of: find.byType(AppGlassSurface),
            matching: find.byType(GlassContainer),
          ),
        );
        expect(mini.settings!.blur, 2);
        expect(mini.settings!.thickness, 30);
        expect(mini.settings!.backerColor, isNull);
        expect(mini.settings, isNot(material));
        expect(
          mini.shape,
          const LiquidVerticalRoundedRectangle(topRadius: 26, bottomRadius: 26),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in [AppGlassMode.powerSaving, AppGlassMode.off]) {
    testWidgets('batch controls become opaque in $mode and keep actions', (
      tester,
    ) async {
      var plays = 0;
      await tester.pumpWidget(
        _app(
          mode: mode,
          child: SongBatchActionBar(
            enabled: true,
            onPlayPressed: () => plays++,
          ),
        ),
      );
      expect(find.byType(GlassContainer), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MusicControlSurface),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color!.a, 1);
      expect(material.borderRadius, isNot(BorderRadius.zero));
      await tester.tap(find.text('Play'));
      expect(plays, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scroll updates frosting without rebuilding control content', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var builds = 0;
    await tester.pumpWidget(
      _app(
        child: Column(
          children: [
            MusicControlSurface(
              scrollController: controller,
              collapseExtent: 100,
              child: Builder(
                builder: (_) {
                  builds++;
                  return const SizedBox(height: 56, child: Text('Controls'));
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (_, index) =>
                    SizedBox(height: 64, child: Text('Song $index')),
              ),
            ),
          ],
        ),
      ),
    );
    final initialBuilds = builds;
    LiquidGlassSettings settings() =>
        tester.widget<GlassContainer>(find.byType(GlassContainer)).settings!;
    final expanded = settings();
    controller.jumpTo(50);
    await tester.pump();
    final halfway = settings();
    controller.jumpTo(160);
    await tester.pump();
    final collapsed = settings();
    expect(halfway.backerColor!.a, greaterThan(expanded.backerColor!.a));
    expect(collapsed.backerColor!.a, greaterThan(halfway.backerColor!.a));
    expect(collapsed.blur, expanded.blur);
    expect(collapsed.refractiveIndex, expanded.refractiveIndex);
    expect(builds, initialBuilds);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  AppGlassMode mode = AppGlassMode.low,
}) {
  final skin = citySoundCreatorSkin();
  return AppGlassScope(
    enabled: mode != AppGlassMode.off,
    mode: mode,
    child: GlassAdaptiveScope(
      minQuality: GlassQuality.minimal,
      maxQuality: GlassQuality.minimal,
      initialQuality: GlassQuality.minimal,
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light(skin)
            : AppTheme.dark(skin),
        home: DetailPageShell(child: child),
      ),
    ),
  );
}
