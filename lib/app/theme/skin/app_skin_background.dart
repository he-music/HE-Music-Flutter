import 'package:flutter/material.dart';

import 'app_skin_asset_resolver.dart';
import 'app_skin_models.dart';
import 'app_skin_rive_animation.dart';
import 'app_skin_theme.dart';

/// 保留 classic 的页面装饰；透明页面由根背景层统一承载视觉。
class AppSkinLegacyPageBackground extends StatelessWidget {
  const AppSkinLegacyPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    final scaffoldBackground = skinTheme?.config.colors.scaffoldBackground;
    if (scaffoldBackground != null && scaffoldBackground.a == 0) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class AppSkinBackgroundLayer extends StatefulWidget {
  const AppSkinBackgroundLayer({
    required this.skin,
    required this.enableAnimation,
    this.assetResolver,
    super.key,
  });

  final AppSkinPackage skin;
  final bool enableAnimation;
  final AppSkinAssetResolver? assetResolver;

  @override
  State<AppSkinBackgroundLayer> createState() => _AppSkinBackgroundLayerState();
}

class _AppSkinBackgroundLayerState extends State<AppSkinBackgroundLayer> {
  late AppSkinAssetResolver _assetResolver;
  AppSkinAssetDescriptor? _activeWallpaper;
  Future<MemoryImage?>? _wallpaperLoad;

  @override
  void initState() {
    super.initState();
    _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
  }

  @override
  void didUpdateWidget(covariant AppSkinBackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetResolver != widget.assetResolver) {
      _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
      _activeWallpaper = null;
      _wallpaperLoad = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.skin.configFor(Theme.of(context).brightness);
    final descriptor = config.background.wallpaper.descriptor;
    final animation = config.background.animation;
    _synchronizeWallpaper(descriptor);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            key: const ValueKey<String>('app-skin-background'),
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                key: const ValueKey<String>('app-skin-background-fallback'),
                color: config.colors.wallpaperFallback,
              ),
              if (_wallpaperLoad != null)
                FutureBuilder<MemoryImage?>(
                  future: _wallpaperLoad,
                  builder: (context, snapshot) {
                    final imageProvider = snapshot.data;
                    if (imageProvider == null) {
                      return const SizedBox.shrink();
                    }
                    return Image(
                      image: imageProvider,
                      key: const ValueKey<String>('app-skin-wallpaper'),
                      fit: config.background.fit,
                      alignment: config.background.alignment,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    );
                  },
                ),
              if (config.background.overlayColor.a > 0)
                ColoredBox(
                  key: const ValueKey<String>('app-skin-background-overlay'),
                  color: config.background.overlayColor,
                ),
              if (animation case AppSkinRiveAnimationDescriptor())
                AppSkinRiveAnimation(
                  descriptor: animation,
                  assetResolver: _assetResolver,
                  enabled: widget.enableAnimation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _synchronizeWallpaper(AppSkinAssetDescriptor? descriptor) {
    if (_activeWallpaper == descriptor) {
      return;
    }
    _activeWallpaper = descriptor;
    _wallpaperLoad = descriptor == null ? null : _loadWallpaper(descriptor);
  }

  Future<MemoryImage?> _loadWallpaper(AppSkinAssetDescriptor descriptor) async {
    final result = await _assetResolver.load(descriptor);
    if (result is! AppSkinAssetLoadSuccess) {
      return null;
    }
    final bytes = result.bytes;
    return MemoryImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
}
