import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/shared/widgets/music_control_surface.dart';

void main() {
  testWidgets('scrolling keeps opaque controls and their content mounted', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var builds = 0;
    final child = Builder(
      builder: (_) {
        builds++;
        return const Text('Play all');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(citySoundCreatorSkin()),
        home: Scaffold(
          body: Column(
            children: [
              MusicControlSurface(
                scrollController: controller,
                collapseExtent: 100,
                child: child,
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 60, child: Text('Song $i')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final before = builds;
    controller.jumpTo(200);
    await tester.pump();
    expect(builds, before);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(MusicControlSurface),
        matching: find.byType(Material),
      ),
    );
    expect(material.color!.a, 1);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
