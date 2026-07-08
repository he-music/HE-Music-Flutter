import 'package:flutter/material.dart';

/// 带统一加载和失败兜底的网络图片。
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return fallback;
    }
    return Image.network(
      normalizedUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return fallback;
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

/// 带统一加载和失败兜底的圆形网络头像。
class AppNetworkAvatar extends StatelessWidget {
  const AppNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallbackIcon,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        fallbackIcon,
        size: iconSize ?? radius,
        color: iconColor ?? theme.hintColor,
      ),
    );
    return ClipOval(
      child: AppNetworkImage(
        url: imageUrl ?? '',
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}
