import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';

/// Paint below lyric content so text and controls retain their original colors.
class LyricPhotoDimmer extends ConsumerWidget {
  const LyricPhotoDimmer({super.key, this.pageController});

  final PageController? pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(
      appConfigProvider.select((config) => config.lyricPhotoBrightness),
    );
    final controller = pageController;
    Widget mask(double visibility) => IgnorePointer(
      child: ColoredBox(
        key: const ValueKey('lyric-photo-dimmer'),
        color: Colors.black.withValues(
          alpha: (1 - brightness) * .75 * visibility,
        ),
      ),
    );
    if (controller == null) return mask(1);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => mask(
        controller.hasClients && controller.position.hasContentDimensions
            ? (controller.page ?? controller.initialPage.toDouble()).clamp(
                0.0,
                1.0,
              )
            : controller.initialPage.toDouble().clamp(0.0, 1.0),
      ),
    );
  }
}
