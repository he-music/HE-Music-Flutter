import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/home_sections.dart';
import 'package:he_music_flutter/shared/layout/adaptive_media_grid_spec.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'home section heading and action fit narrow text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var actions = 0;
        const title = 'New music selected for your evening';
        const actionLabel = 'Explore the full collection';
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: CustomScrollView(
                  slivers: buildHomeSectionSlivers(
                    state: HomeContentState.initial.copyWith(
                      sections: const [
                        HomePageSection(
                          sectionTypeCode: 6,
                          sectionType: HomeSectionType.quickEntries,
                          resourceType: null,
                          title: title,
                          entries: [
                            HomePageEntry(
                              targetType: HomePageEntryTargetType.songList,
                              targetId: 'evening',
                              title: 'Evening',
                              subtitle: '',
                              cover: '',
                            ),
                          ],
                        ),
                      ],
                    ),
                    gridSpec: resolveAdaptiveMediaGridSpec(maxWidth: 288),
                    quickEntryGridSpec: resolveHomeQuickEntryGridSpec(
                      maxWidth: 288,
                    ),
                    loadingText: 'Loading',
                    emptyText: 'Empty',
                    retryText: 'Retry',
                    onRetry: () {},
                    sectionActionOf: (_) => HomeSectionAction(
                      label: actionLabel,
                      onTap: () => actions++,
                    ),
                    onTapSong: (_, _) {},
                    onTapAlbum: (_) {},
                    onTapPlaylist: (_) {},
                    onTapMv: (_) {},
                    onTapArtist: (_) {},
                    onTapRanking: (_) {},
                    onTapRadio: (_) {},
                    onTapEntry: (_) {},
                    onMoreSong: (_) {},
                    buildSongStatus: (_, _, builder) => builder(false, false),
                    onLikeSong: (_) async {},
                    buildRadioStatus: (_, _, builder) => builder(false),
                    buildEntryRadioStatus: (_, _, builder) => builder(false),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = tester.widget<Text>(find.text(title));
        expect(heading.maxLines, isNull);
        expect(
          tester.getTopLeft(find.text(actionLabel)).dy,
          greaterThan(tester.getBottomLeft(find.text(title)).dy),
        );
        await tester.tap(find.text(actionLabel));
        expect(actions, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
