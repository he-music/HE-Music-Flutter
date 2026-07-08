import 'package:flutter/material.dart';

import '../constants/layout_tokens.dart';
import 'animated_skeleton.dart';
import 'song_list_component.dart';

class GenericDetailLoadingBody extends StatelessWidget {
  const GenericDetailLoadingBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          SliverToBoxAdapter(child: _DetailHeroSkeleton(title: title)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedHeaderDelegate(
              child: const _PinnedPlayAllSkeleton(),
              height: 56,
            ),
          ),
        ];
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          LayoutTokens.listItemInnerGutter,
          0,
          LayoutTokens.listItemInnerGutter,
          0,
        ),
        child: const SongListComponent(
          itemCount: 0,
          itemBuilder: _emptyBuilder,
          initialLoading: true,
          enablePaging: false,
        ),
      ),
    );
  }
}

class ArtistDetailLoadingBody extends StatelessWidget {
  const ArtistDetailLoadingBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          SliverToBoxAdapter(child: _ArtistHeroSkeleton(title: title)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedHeaderDelegate(
              child: const _ArtistTabBarSkeleton(),
              height: 52,
            ),
          ),
        ];
      },
      body: const ArtistSongsLoadingView(),
    );
  }
}

class ArtistSongsLoadingView extends StatelessWidget {
  const ArtistSongsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(child: _InlinePlayAllSkeleton()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutTokens.listItemInnerGutter,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const _SongRowSkeleton(),
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }
}

class ArtistAlbumsLoadingView extends StatelessWidget {
  const ArtistAlbumsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const _ArtistAlbumSkeleton(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

class ArtistVideosLoadingView extends StatelessWidget {
  const ArtistVideosLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _ArtistVideoSkeleton(),
              );
            }, childCount: 4),
          ),
        ),
      ],
    );
  }
}

Widget _emptyBuilder(BuildContext context, int index) =>
    const SizedBox.shrink();

class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FixedHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _FixedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _DetailHeroSkeleton extends StatelessWidget {
  const _DetailHeroSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LayoutTokens.compactPageGutter,
        MediaQuery.paddingOf(context).top + 10,
        LayoutTokens.compactPageGutter,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SkeletonBox(width: 36, height: 36, radius: 18),
              const Spacer(),
              const SkeletonBox(width: 28, height: 28, radius: 14),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SkeletonBox(width: 124, height: 124, radius: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkeletonBox(
                        width: title.trim().isEmpty ? 140 : 176,
                        height: 24,
                        radius: 10,
                      ),
                      const SizedBox(height: 12),
                      const SkeletonBox(width: 112, height: 14, radius: 7),
                      const SizedBox(height: 16),
                      Row(
                        children: const <Widget>[
                          SkeletonBox(width: 62, height: 22, radius: 11),
                          SizedBox(width: 8),
                          SkeletonBox(width: 74, height: 22, radius: 11),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(width: double.infinity, height: 13, radius: 7),
          const SizedBox(height: 8),
          SkeletonBox(
            width: MediaQuery.sizeOf(context).width * 0.55,
            height: 13,
            radius: 7,
          ),
          const SizedBox(height: 10),
          Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),
        ],
      ),
    );
  }
}

class _ArtistHeroSkeleton extends StatelessWidget {
  const _ArtistHeroSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LayoutTokens.compactPageGutter,
        MediaQuery.paddingOf(context).top + 10,
        LayoutTokens.compactPageGutter,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SkeletonBox(width: 36, height: 36, radius: 18),
              const Spacer(),
              const SkeletonBox(width: 28, height: 28, radius: 14),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const SkeletonBox(width: 108, height: 108, radius: 54),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(
                      width: title.trim().isEmpty ? 132 : 164,
                      height: 24,
                      radius: 10,
                    ),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: 96, height: 14, radius: 7),
                    const SizedBox(height: 18),
                    const Row(
                      children: <Widget>[
                        SkeletonBox(width: 52, height: 24, radius: 12),
                        SizedBox(width: 8),
                        SkeletonBox(width: 52, height: 24, radius: 12),
                        SizedBox(width: 8),
                        SkeletonBox(width: 52, height: 24, radius: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(width: double.infinity, height: 13, radius: 7),
        ],
      ),
    );
  }
}

class _PinnedPlayAllSkeleton extends StatelessWidget {
  const _PinnedPlayAllSkeleton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: const <Widget>[
            SkeletonBox(width: 24, height: 24, radius: 12),
            SizedBox(width: 10),
            SkeletonBox(width: 106, height: 16, radius: 8),
          ],
        ),
      ),
    );
  }
}

class _InlinePlayAllSkeleton extends StatelessWidget {
  const _InlinePlayAllSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 22, height: 22, radius: 11),
          SizedBox(width: 8),
          SkeletonBox(width: 92, height: 16, radius: 8),
        ],
      ),
    );
  }
}

class _ArtistTabBarSkeleton extends StatelessWidget {
  const _ArtistTabBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SkeletonBox(width: double.infinity, height: 16, radius: 8),
            ),
            SizedBox(width: 16),
            Expanded(
              child: SkeletonBox(width: double.infinity, height: 16, radius: 8),
            ),
            SizedBox(width: 16),
            Expanded(
              child: SkeletonBox(width: double.infinity, height: 16, radius: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongRowSkeleton extends StatelessWidget {
  const _SongRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(width: 52, height: 52, radius: 10),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: double.infinity, height: 13, radius: 6),
                SizedBox(height: 7),
                SkeletonBox(width: 180, height: 11, radius: 5),
                SizedBox(height: 7),
                SkeletonBox(width: 120, height: 10, radius: 5),
              ],
            ),
          ),
          SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SkeletonBox(width: 18, height: 18, radius: 9),
              SizedBox(width: 6),
              SkeletonBox(width: 18, height: 18, radius: 9),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistAlbumSkeleton extends StatelessWidget {
  const _ArtistAlbumSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 64, height: 64, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 168, height: 16, radius: 8),
                SizedBox(height: 8),
                SkeletonBox(width: 132, height: 12, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 116, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistVideoSkeleton extends StatelessWidget {
  const _ArtistVideoSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          children: <Widget>[
            SkeletonBox(width: 112, height: 64, radius: 10),
            Positioned(
              right: 6,
              bottom: 6,
              child: SkeletonBox(width: 36, height: 14, radius: 999),
            ),
          ],
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBox(width: double.infinity, height: 14, radius: 7),
              SizedBox(height: 8),
              SkeletonBox(width: 92, height: 12, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 108, height: 12, radius: 6),
            ],
          ),
        ),
      ],
    );
  }
}
