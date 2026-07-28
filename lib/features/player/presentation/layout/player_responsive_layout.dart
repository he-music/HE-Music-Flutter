import 'package:flutter/material.dart';

import 'player_layout_spec.dart';

typedef PlayerLayoutChildBuilder =
    Widget Function(BuildContext context, PlayerLayoutSpec spec);

class PlayerResponsiveLayout extends StatelessWidget {
  const PlayerResponsiveLayout({
    required this.pageController,
    required this.onPageChanged,
    required this.onLayoutModeResolved,
    required this.topBarBuilder,
    required this.mainPlayerBuilder,
    required this.mobileLandscapeBuilder,
    required this.lyricsBuilder,
    super.key,
  });

  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<PlayerLayoutMode> onLayoutModeResolved;
  final PlayerLayoutChildBuilder topBarBuilder;
  final PlayerLayoutChildBuilder mainPlayerBuilder;
  final PlayerLayoutChildBuilder mobileLandscapeBuilder;
  final PlayerLayoutChildBuilder lyricsBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = PlayerLayoutSpec.resolve(constraints);
        onLayoutModeResolved(spec.mode);
        return switch (spec.mode) {
          PlayerLayoutMode.mobilePortrait => _buildMobilePortrait(
            context,
            spec,
          ),
          PlayerLayoutMode.mobileLandscape => _buildMobileLandscape(
            context,
            spec,
          ),
          PlayerLayoutMode.desktop => _buildDesktop(context, spec),
        };
      },
    );
  }

  Widget _buildMobilePortrait(BuildContext context, PlayerLayoutSpec spec) {
    return Padding(
      padding: EdgeInsets.fromLTRB(spec.pageGutter, 6, spec.pageGutter, 12),
      child: Column(
        children: <Widget>[
          topBarBuilder(context, spec),
          SizedBox(height: spec.verticalGap),
          Expanded(
            child: PageView(
              key: const ValueKey<String>('player-mobile-pager'),
              controller: pageController,
              allowImplicitScrolling: true,
              onPageChanged: onPageChanged,
              children: <Widget>[
                KeyedSubtree(
                  key: const ValueKey<String>('player-mobile-primary-pane'),
                  child: mainPlayerBuilder(context, spec),
                ),
                lyricsBuilder(context, spec),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLandscape(BuildContext context, PlayerLayoutSpec spec) {
    return Padding(
      padding: EdgeInsets.fromLTRB(spec.pageGutter, 0, spec.pageGutter, 8),
      child: mobileLandscapeBuilder(context, spec),
    );
  }

  Widget _buildDesktop(BuildContext context, PlayerLayoutSpec spec) {
    return Padding(
      padding: EdgeInsets.fromLTRB(spec.pageGutter, 6, spec.pageGutter, 16),
      child: Column(
        children: <Widget>[
          topBarBuilder(context, spec),
          SizedBox(height: spec.verticalGap),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  key: const ValueKey<String>('player-desktop-primary-pane'),
                  flex: spec.primaryPaneFlex,
                  child: mainPlayerBuilder(context, spec),
                ),
                const SizedBox(width: 28),
                Expanded(
                  key: const ValueKey<String>('player-desktop-lyrics-pane'),
                  flex: spec.lyricsPaneFlex,
                  child: lyricsBuilder(context, spec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
