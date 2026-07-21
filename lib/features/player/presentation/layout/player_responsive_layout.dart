import 'package:flutter/material.dart';

import 'player_layout_spec.dart';

typedef PlayerLayoutChildBuilder =
    Widget Function(BuildContext context, PlayerLayoutSpec spec);

class PlayerResponsiveLayout extends StatelessWidget {
  const PlayerResponsiveLayout({
    required this.pageController,
    required this.onPageChanged,
    required this.topBarBuilder,
    required this.mainPlayerBuilder,
    required this.lyricsBuilder,
    super.key,
  });

  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final PlayerLayoutChildBuilder topBarBuilder;
  final PlayerLayoutChildBuilder mainPlayerBuilder;
  final PlayerLayoutChildBuilder lyricsBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = PlayerLayoutSpec.resolve(constraints);
        final topBar = topBarBuilder(context, spec);
        final mainPlayer = mainPlayerBuilder(context, spec);
        final lyrics = lyricsBuilder(context, spec);
        if (spec.isDesktop) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              spec.pageGutter,
              6,
              spec.pageGutter,
              16,
            ),
            child: Column(
              children: <Widget>[
                topBar,
                SizedBox(height: spec.verticalGap),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        key: const ValueKey<String>(
                          'player-desktop-primary-pane',
                        ),
                        flex: spec.primaryPaneFlex,
                        child: mainPlayer,
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        key: const ValueKey<String>(
                          'player-desktop-lyrics-pane',
                        ),
                        flex: spec.lyricsPaneFlex,
                        child: lyrics,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(spec.pageGutter, 6, spec.pageGutter, 12),
          child: Column(
            children: <Widget>[
              topBar,
              SizedBox(height: spec.verticalGap),
              Expanded(
                child: PageView(
                  key: const ValueKey<String>('player-mobile-pager'),
                  controller: pageController,
                  onPageChanged: onPageChanged,
                  children: <Widget>[
                    KeyedSubtree(
                      key: const ValueKey<String>('player-mobile-primary-pane'),
                      child: mainPlayer,
                    ),
                    lyrics,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
