import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/skin/app_skin_surface.dart';
import 'app_network_image.dart';
import '../utils/compact_number_formatter.dart';

const _videoCardRadius = 14.0;
const _videoOverlayFontSize = 10.0;
const videoGridItemChildAspectRatio = 1.2;

class VideoListItem extends ConsumerWidget {
  const VideoListItem({
    required this.title,
    this.creator,
    this.duration,
    required this.coverUrl,
    this.playCount,
    required this.onTap,
    super.key,
  });

  final String title;
  final String? creator;
  final String? duration;
  final String coverUrl;
  final String? playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(_videoCardRadius + 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_videoCardRadius + 2),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 156,
                height: 88,
                child: _VideoCover(
                  url: coverUrl,
                  duration: duration,
                  playCount: playCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (creator ?? '').trim().isEmpty
                            ? AppI18n.t(config, 'common.unknown_author')
                            : creator!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoGridItem extends ConsumerWidget {
  const VideoGridItem({
    required this.title,
    this.creator,
    this.duration,
    required this.coverUrl,
    this.playCount,
    required this.onTap,
    super.key,
  });

  final String title;
  final String? creator;
  final String? duration;
  final String coverUrl;
  final String? playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final author = (creator ?? '').trim().isEmpty
        ? AppI18n.t(config, 'common.unknown_author')
        : creator!;
    return AppSkinContentSurface(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _VideoCover(
                    url: coverUrl,
                    duration: duration,
                    playCount: playCount,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.url, this.duration, this.playCount});

  final String url;
  final String? duration;
  final String? playCount;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final fallback = Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_videoCardRadius),
      ),
      child: Icon(
        Icons.play_circle_fill_rounded,
        color: Theme.of(context).hintColor,
        size: 28,
      ),
    );
    if (url.isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(_videoCardRadius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppNetworkImage(
            url: url,
            fit: BoxFit.cover,
            cacheWidth: 360,
            filterQuality: FilterQuality.low,
            fallback: fallback,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          if ((playCount ?? '').trim().isNotEmpty)
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatCompactPlayCount(playCount!, locale),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: _videoOverlayFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if ((duration ?? '').trim().isNotEmpty)
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatDurationSecondsLabel(duration!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: _videoOverlayFontSize,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
