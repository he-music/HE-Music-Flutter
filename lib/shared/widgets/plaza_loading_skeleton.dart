import 'package:flutter/material.dart';

import '../layout/adaptive_media_grid_spec.dart';
import '../layout/ranking_layout_spec.dart';
import 'animated_skeleton.dart';

class SectionTitleSkeleton extends StatelessWidget {
  const SectionTitleSkeleton({this.width = 88, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: SkeletonBox(width: width, height: 20, radius: 8),
    );
  }
}

class PlazaPlatformTabsSkeleton extends StatelessWidget {
  const PlazaPlatformTabsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            SkeletonBox(width: 48, height: 28, radius: 14),
            SizedBox(width: 8),
            SkeletonBox(width: 52, height: 28, radius: 14),
            SizedBox(width: 8),
            SkeletonBox(width: 44, height: 28, radius: 14),
            SizedBox(width: 8),
            SkeletonBox(width: 58, height: 28, radius: 14),
          ],
        ),
      ),
    );
  }
}

class UnderlineTabsSkeleton extends StatelessWidget {
  const UnderlineTabsSkeleton({
    this.itemWidths = const <double>[48, 64, 52, 60],
    super.key,
  });

  final List<double> itemWidths;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemWidths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          return Center(
            child: SkeletonBox(width: itemWidths[index], height: 16, radius: 8),
          );
        },
      ),
    );
  }
}

class PlazaFilterPanelSkeleton extends StatelessWidget {
  const PlazaFilterPanelSkeleton({
    this.rowCount = 2,
    this.trailingButton = false,
    super.key,
  });

  final int rowCount;
  final bool trailingButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(rowCount, (index) {
          final widths = index.isEven
              ? const <double>[72, 60, 68, 54]
              : const <double>[64, 76, 52, 58];
          return Padding(
            padding: EdgeInsets.only(bottom: index == rowCount - 1 ? 0 : 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widths
                          .map(
                            (width) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SkeletonBox(
                                width: width,
                                height: 28,
                                radius: 14,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                if (trailingButton) ...const <Widget>[
                  SizedBox(width: 8),
                  SkeletonBox(width: 38, height: 38, radius: 12),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

class PlazaGridSkeleton extends StatelessWidget {
  const PlazaGridSkeleton({
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 18),
    super.key,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final spec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth - resolvedPadding.horizontal,
        );
        return GridView.builder(
          padding: padding,
          gridDelegate: spec.sliverDelegate,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return const GridCardSkeleton();
          },
        );
      },
    );
  }
}

class PlazaArtistListSkeleton extends StatelessWidget {
  const PlazaArtistListSkeleton({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return const _ArtistCardSkeleton();
      },
    );
  }
}

class PlazaVideoListSkeleton extends StatelessWidget {
  const PlazaVideoListSkeleton({this.itemCount = 4, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        return const VideoCardSkeleton();
      },
    );
  }
}

class PlazaVideoGridSkeleton extends StatelessWidget {
  const PlazaVideoGridSkeleton({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        return const VideoGridCardSkeleton();
      },
    );
  }
}

class GridCardSkeleton extends StatelessWidget {
  const GridCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const textBlockHeight = 32.0;
        final coverSide = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - textBlockHeight)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble()
            : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: coverSide,
              height: coverSide,
              child: const SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: 18,
              ),
            ),
            const SizedBox(height: 4),
            const SkeletonBox(width: double.infinity, height: 14, radius: 7),
            const SizedBox(height: 2),
            const SkeletonBox(width: 120, height: 12, radius: 6),
          ],
        );
      },
    );
  }
}

class VideoGridCardSkeleton extends StatelessWidget {
  const VideoGridCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: <Widget>[
                SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  radius: 14,
                ),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: SkeletonBox(width: 44, height: 18, radius: 9),
                ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: SkeletonBox(width: 38, height: 18, radius: 9),
                ),
              ],
            ),
          ),
          SizedBox(height: 6),
          SkeletonBox(width: double.infinity, height: 15, radius: 7),
          SizedBox(height: 3),
          SkeletonBox(width: 96, height: 13, radius: 6),
        ],
      ),
    );
  }
}

class _ArtistCardSkeleton extends StatelessWidget {
  const _ArtistCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: <Widget>[
          SkeletonBox(width: 72, height: 72, radius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 132, height: 16, radius: 8),
                SizedBox(height: 10),
                SkeletonBox(width: 176, height: 12, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 148, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: <Widget>[
          Stack(
            children: <Widget>[
              SkeletonBox(width: 156, height: 88, radius: 14),
              Positioned(
                left: 8,
                bottom: 6,
                child: SkeletonBox(width: 44, height: 18, radius: 9),
              ),
              Positioned(
                right: 8,
                bottom: 6,
                child: SkeletonBox(width: 38, height: 18, radius: 9),
              ),
            ],
          ),
          SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SkeletonBox(width: double.infinity, height: 15, radius: 7),
                  SizedBox(height: 6),
                  SkeletonBox(width: 112, height: 15, radius: 7),
                  SizedBox(height: 10),
                  SkeletonBox(width: 96, height: 11, radius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeywordWrapSkeleton extends StatelessWidget {
  const KeywordWrapSkeleton({
    this.itemWidths = const <double>[74, 92, 68, 86, 72, 96],
    super.key,
  });

  final List<double> itemWidths;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: itemWidths
          .map((width) => SkeletonBox(width: width, height: 30, radius: 12))
          .toList(growable: false),
    );
  }
}

class HotKeywordListSkeleton extends StatelessWidget {
  const HotKeywordListSkeleton({this.itemCount = 8, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        itemCount,
        (index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: <Widget>[
              SkeletonBox(width: 18, height: 14, radius: 6),
              SizedBox(width: 10),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 14,
                  radius: 7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RankingGroupsSkeleton extends StatelessWidget {
  const RankingGroupsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: const <Widget>[
        SectionTitleSkeleton(width: 72),
        _RankingRowCardSkeleton(),
        SizedBox(height: 12),
        _RankingRowCardSkeleton(),
        SizedBox(height: 12),
        _RankingRowCardSkeleton(),
        SizedBox(height: 18),
        SectionTitleSkeleton(width: 84),
        _RankingRowCardSkeleton(),
        SizedBox(height: 12),
        _RankingGridSkeleton(),
      ],
    );
  }
}

class _RankingRowCardSkeleton extends StatelessWidget {
  const _RankingRowCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowSpec = resolveRankingRowLayoutSpec(
          maxWidth: constraints.maxWidth,
        );
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SkeletonBox(width: 120, height: 15, radius: 8),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SkeletonBox(
                    width: rowSpec.coverSide,
                    height: rowSpec.coverSide,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: rowSpec.coverSide,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SkeletonBox(
                            width: double.infinity,
                            height: 11,
                            radius: 6,
                          ),
                          SizedBox(height: 8),
                          SkeletonBox(
                            width: double.infinity,
                            height: 11,
                            radius: 6,
                          ),
                          SizedBox(height: 8),
                          SkeletonBox(width: 140, height: 11, radius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankingGridSkeleton extends StatelessWidget {
  const _RankingGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSpec = resolveRankingGridLayoutSpec(
          maxWidth: constraints.maxWidth,
        );
        return Wrap(
          spacing: gridSpec.spacing,
          runSpacing: gridSpec.spacing,
          children: List<Widget>.generate(
            gridSpec.crossAxisCount,
            (_) => SizedBox(
              width: gridSpec.itemWidth,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1,
                    child: SkeletonBox(
                      width: double.infinity,
                      height: double.infinity,
                      radius: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 12, radius: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
