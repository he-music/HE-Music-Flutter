import 'package:flutter/material.dart';

import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/widgets/animated_skeleton.dart';

class SheetMusicListSkeleton extends StatelessWidget {
  const SheetMusicListSkeleton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => _SheetSkeleton(
    label: label,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (_, _) => const AppSkinContentSurface(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              SkeletonBox(width: 56, height: 72),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: double.infinity, height: 16),
                    SizedBox(height: 10),
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      child: SkeletonBox(width: double.infinity, height: 12),
                    ),
                    SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.46,
                      child: SkeletonBox(width: double.infinity, height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SheetMusicDetailSkeleton extends StatelessWidget {
  const SheetMusicDetailSkeleton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => _SheetSkeleton(
    label: label,
    child: const Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                SkeletonBox(width: 120, height: 14),
                SkeletonBox(width: 64, height: 14),
                SkeletonBox(width: 88, height: 14),
              ],
            ),
          ),
        ),
        Expanded(child: _ScorePlaceholder()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 48, height: 32),
              SkeletonBox(width: 96, height: 32),
              SkeletonBox(width: 88, height: 32),
            ],
          ),
        ),
      ],
    ),
  );
}

class SheetMusicImageSkeleton extends StatelessWidget {
  const SheetMusicImageSkeleton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      _SheetSkeleton(label: label, child: const _ScorePlaceholder());
}

class _ScorePlaceholder extends StatelessWidget {
  const _ScorePlaceholder();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: AspectRatio(
        aspectRatio: 0.7,
        child: SkeletonBox(width: double.infinity, height: double.infinity),
      ),
    ),
  );
}

class _SheetSkeleton extends StatelessWidget {
  const _SheetSkeleton({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: TickerMode(
          enabled: !MediaQuery.disableAnimationsOf(context),
          child: IgnorePointer(child: child),
        ),
      ),
    ),
  );
}
