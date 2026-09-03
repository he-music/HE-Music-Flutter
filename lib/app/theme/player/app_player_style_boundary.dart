import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config_controller.dart';
import 'app_player_style_models.dart';
import 'app_player_style_theme.dart';

class AppPlayerStyleBoundary extends ConsumerWidget {
  const AppPlayerStyleBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 播放器 body 只看封面/背景/歌词三轴，不由全局 skin/accent 着色。
    // 前景/强调/控件色固定，状态栏样式全局固定。
    ref.watch(
      appConfigProvider.select(
        (config) => (
          config.playerStageId,
          config.playerBackdropId,
          config.playerLyricsId,
        ),
      ),
    );
    final theme = buildAppPlayerStyleTheme(
      appPlayerForegroundColors,
      appPlayerSystemOverlayStyle,
      sheetBrightness: Theme.of(context).brightness,
    );
    return AnnotatedRegion(
      value: appPlayerSystemOverlayStyle,
      child: Theme(
        key: const ValueKey<String>('app-player-style-boundary'),
        data: theme,
        child: child,
      ),
    );
  }
}