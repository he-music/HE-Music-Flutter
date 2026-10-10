import 'package:flutter/material.dart';

/// 歌曲关联内容的轻量占位，动画只更新局部透明度。
class SongRelationsLoadingSkeleton extends StatefulWidget {
  const SongRelationsLoadingSkeleton({super.key});

  @override
  State<SongRelationsLoadingSkeleton> createState() =>
      _SongRelationsLoadingSkeletonState();
}

class _SongRelationsLoadingSkeletonState
    extends State<SongRelationsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _opacity = _controller.drive(
    Tween<double>(
      begin: 0.5,
      end: 0.85,
    ).chain(CurveTween(curve: Curves.easeInOut)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Placeholder(width: 104, height: 20),
              const SizedBox(height: 8),
              for (final titleWidth in const <double>[0.65, 0.5, 0.6])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: <Widget>[
                      const _Placeholder(width: 56, height: 56, radius: 9),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FractionallySizedBox(
                              widthFactor: titleWidth,
                              child: const _Placeholder(height: 14),
                            ),
                            const SizedBox(height: 8),
                            const FractionallySizedBox(
                              widthFactor: 0.4,
                              child: _Placeholder(height: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, required this.height, this.radius = 5});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
