import 'package:flutter/material.dart';

import 'app_network_image.dart';
import '../utils/compact_number_formatter.dart';

const _mediaGridCardRadius = 14.0;
const _mediaGridOverlayFontSize = 10.0;
const _mediaGridCardPadding = 4.0;

enum MediaGridCardKind { album, playlist }

class MediaGridCard extends StatelessWidget {
  const MediaGridCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.caption,
    this.playCount,
    this.selected = false,
    this.showCenterPlayIcon = false,
    required this.onTap,
    super.key,
  });

  final MediaGridCardKind kind;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String? caption;
  final String? playCount;
  final bool selected;
  final bool showCenterPlayIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final showSubtitle = subtitle.trim().isNotEmpty;
    final showCaption = (caption ?? '').trim().isNotEmpty;
    final selectedBackground = theme.colorScheme.primaryContainer.withValues(
      alpha: 0.3,
    );
    final selectedBorder = theme.colorScheme.primary.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? selectedBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(_mediaGridCardRadius + 6),
        border: selected
            ? Border.all(color: selectedBorder)
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_mediaGridCardRadius + 6),
          child: Padding(
            padding: const EdgeInsets.all(_mediaGridCardPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textHeight =
                    17.0 +
                    (showSubtitle ? 14.0 : 0.0) +
                    (showCaption ? 14.0 : 0.0);
                final coverSide = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight - textHeight).clamp(
                        0.0,
                        constraints.maxWidth,
                      )
                    : constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: coverSide,
                      height: coverSide,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                _mediaGridCardRadius,
                              ),
                              child: _MediaGridCover(url: coverUrl, kind: kind),
                            ),
                          ),
                          if (showCenterPlayIcon)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          if ((playCount ?? '').trim().isNotEmpty)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      formatCompactPlayCount(
                                        playCount!,
                                        locale,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: _mediaGridOverlayFontSize,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 14,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.0,
                          color: selected ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    if (showSubtitle) ...<Widget>[
                      const SizedBox(height: 1),
                      SizedBox(
                        height: 13,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                    if (showCaption) ...<Widget>[
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 12,
                        child: Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaGridCover extends StatelessWidget {
  const _MediaGridCover({required this.url, required this.kind});

  final String url;
  final MediaGridCardKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlbum = kind == MediaGridCardKind.album;
    final fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Icon(
        isAlbum ? Icons.album_rounded : Icons.queue_music_rounded,
        size: isAlbum ? 28 : 24,
        color: theme.hintColor,
      ),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AppNetworkImage(
          url: url,
          fit: BoxFit.cover,
          cacheWidth: 420,
          filterQuality: FilterQuality.low,
          fallback: fallback,
        ),
        if (!isAlbum)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
