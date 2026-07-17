import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/skin/app_skin_surface.dart';
import 'adaptive_action_menu.dart';
import 'app_network_image.dart';
import '../constants/layout_tokens.dart';
import '../models/he_music_models.dart';

class SongListItemData {
  const SongListItemData({
    required this.title,
    required this.artistAlbumText,
    required this.subtitleText,
    this.coverUrl,
    this.coverBytes,
    this.tags = const <String>[],
    this.isCurrent = false,
    this.showMoreVersionButton = false,
  });

  factory SongListItemData.fromSongInfo({
    required SongInfo song,
    String? artistAlbumText,
    String subtitleText = '',
    String? coverUrl,
    Uint8List? coverBytes,
    List<String>? tags,
    bool isCurrent = false,
    bool showMoreVersionButton = false,
    String originalTagLabel = 'Original',
  }) {
    return SongListItemData(
      title: song.title,
      artistAlbumText: artistAlbumText ?? song.artist,
      subtitleText: subtitleText,
      coverUrl: coverUrl,
      coverBytes: coverBytes,
      tags: tags ?? _defaultSongTags(song, originalTagLabel),
      isCurrent: isCurrent,
      showMoreVersionButton: showMoreVersionButton,
    );
  }

  final String title;
  final String artistAlbumText;
  final String subtitleText;
  final String? coverUrl;
  final Uint8List? coverBytes;
  final List<String> tags;
  final bool isCurrent;
  final bool showMoreVersionButton;
}

List<String> _defaultSongTags(SongInfo song, String originalTagLabel) {
  final tags = <String>[];
  final quality = _songQualityLabel(song);
  if (quality.isNotEmpty) {
    tags.add(quality);
  }
  if (song.originalType == 1) {
    tags.add(originalTagLabel);
  }
  return tags;
}

String _songQualityLabel(SongInfo song) {
  final quality = (song.quality ?? '').trim().toUpperCase();
  final path = (song.path ?? '').trim();
  if (path.isNotEmpty) {
    switch (quality) {
      case 'MASTER':
      case 'HIRES':
      case 'SQ':
      case 'HQ':
        return quality;
      default:
        return '';
    }
  }

  if (song.links.isEmpty) {
    return '';
  }
  final link = song.links.last;
  final linkQuality = link.quality;
  if (linkQuality >= 2000) {
    final label = link.name.trim().toUpperCase();
    if (label.isNotEmpty) {
      return label;
    }
    return 'HIRES';
  }
  if (linkQuality >= 1000) {
    return 'SQ';
  }
  if (linkQuality >= 192) {
    return 'HQ';
  }
  return '';
}

class SongListItem extends StatelessWidget {
  const SongListItem({
    required this.data,
    this.isLiked = false,
    this.selectable = false,
    this.selected = false,
    this.showActions = true,
    this.onTap,
    this.onSelectTap,
    this.onLikeTap,
    this.onMoreTap,
    this.onMoreVersionTap,
    this.moreVersionLabel = 'More Versions',
    super.key,
  });

  final SongListItemData data;
  final bool isLiked;
  final bool selectable;
  final bool selected;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onMoreVersionTap;
  final String moreVersionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = data.isCurrent;
    final isSelected = selectable && selected;
    final effectiveOnTap = selectable ? (onSelectTap ?? onTap) : onTap;
    final backgroundColor = isCurrent || isSelected
        ? theme.colorScheme.primary.withValues(alpha: isCurrent ? 0.07 : 0.05)
        : Colors.transparent;
    return AppSkinContentSurface(
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutTokens.listItemInnerGutter,
              vertical: 11,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (selectable) ...<Widget>[
                  _SelectIndicator(selected: selected),
                  const SizedBox(width: 12),
                ],
                _SongCover(
                  url: data.coverUrl,
                  bytes: data.coverBytes,
                  isCurrent: isCurrent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.12,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.textTheme.titleSmall?.color,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _ArtistAlbumLine(
                        tags: data.tags,
                        artistAlbum: data.artistAlbumText,
                        isCurrent: isCurrent,
                      ),
                      if (data.subtitleText.trim().isNotEmpty ||
                          data.showMoreVersionButton) ...<Widget>[
                        const SizedBox(height: 3),
                        _BottomMetaLine(
                          subtitle: data.subtitleText,
                          showMoreVersionButton: data.showMoreVersionButton,
                          onMoreVersionTap: onMoreVersionTap,
                          moreVersionLabel: moreVersionLabel,
                          isCurrent: isCurrent,
                        ),
                      ],
                      if (data.subtitleText.trim().isEmpty &&
                          !data.showMoreVersionButton)
                        const SizedBox(height: 2),
                      if (data.subtitleText.trim().isNotEmpty ||
                          data.showMoreVersionButton)
                        const SizedBox(height: 1),
                    ],
                  ),
                ),
                if (showActions) ...<Widget>[
                  const SizedBox(width: 4),
                  _ActionButtons(
                    liked: isLiked,
                    onLikeTap: onLikeTap,
                    onMoreTap: onMoreTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectIndicator extends StatelessWidget {
  const _SelectIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final borderColor = selected
        ? primary
        : theme.colorScheme.outline.withValues(alpha: 0.72);
    final fillColor = selected
        ? primary
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(
        selected ? Icons.check_rounded : Icons.circle_outlined,
        size: selected ? 15 : 10,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.outline.withValues(alpha: 0.78),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.liked,
    required this.onLikeTap,
    required this.onMoreTap,
  });

  final bool liked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final hasLike = onLikeTap != null;
    final hasMore = onMoreTap != null;
    if (!hasLike && !hasMore) {
      return const SizedBox.shrink();
    }
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.78);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasLike)
          _ActionIcon(
            onPressed: onLikeTap,
            icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? Theme.of(context).colorScheme.error : iconColor,
            ),
            tooltip: 'Like',
          ),
        if (hasLike && hasMore) const SizedBox(width: 2),
        if (hasMore)
          _ActionIcon(
            onPressed: onMoreTap,
            icon: Icon(Icons.more_horiz_rounded, color: iconColor),
            tooltip: 'More',
          ),
      ],
    );
  }
}

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  Offset? _lastGlobalPosition;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _lastGlobalPosition = details.globalPosition,
      onSecondaryTapDown: (details) {
        _lastGlobalPosition = details.globalPosition;
      },
      child: IconButton(
        onPressed: widget.onPressed == null
            ? null
            : () {
                AdaptiveActionMenuAnchor.capture(
                  context,
                  globalPosition: _lastGlobalPosition,
                );
                widget.onPressed?.call();
              },
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: widget.icon,
        tooltip: widget.tooltip,
      ),
    );
  }
}

class _ArtistAlbumLine extends StatelessWidget {
  const _ArtistAlbumLine({
    required this.tags,
    required this.artistAlbum,
    required this.isCurrent,
  });

  final List<String> tags;
  final String artistAlbum;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ...tags.map(
          (tag) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _TagChip(label: tag),
          ),
        ),
        Expanded(
          child: Text(
            artistAlbum,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.12,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomMetaLine extends StatelessWidget {
  const _BottomMetaLine({
    required this.subtitle,
    required this.showMoreVersionButton,
    required this.onMoreVersionTap,
    required this.moreVersionLabel,
    required this.isCurrent,
  });

  final String subtitle;
  final bool showMoreVersionButton;
  final VoidCallback? onMoreVersionTap;
  final String moreVersionLabel;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSubtitle = subtitle.trim().isNotEmpty;
    if (!showSubtitle && !showMoreVersionButton) {
      return const SizedBox(height: 0);
    }
    return Row(
      children: <Widget>[
        if (showSubtitle)
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCurrent
                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                    : theme.hintColor,
                height: 1.1,
                fontSize: 11.5,
              ),
            ),
          ),
        if (showSubtitle && showMoreVersionButton) const SizedBox(width: 8),
        if (showMoreVersionButton)
          InkWell(
            onTap: onMoreVersionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                moreVersionLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SongCover extends StatelessWidget {
  const _SongCover({
    required this.url,
    required this.bytes,
    required this.isCurrent,
  });

  final String? url;
  final Uint8List? bytes;
  final bool isCurrent;

  static const double _coverSize = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: _coverSize,
      height: _coverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: const Icon(Icons.music_note_rounded, size: 20),
    );
    Widget child;
    if (bytes != null && bytes!.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.memory(
          bytes!,
          width: _coverSize,
          height: _coverSize,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: AppNetworkImage(
          url: url ?? '',
          width: _coverSize,
          height: _coverSize,
          fit: BoxFit.cover,
          cacheWidth: 128,
          fallback: fallback,
        ),
      );
    }
    return Stack(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(isCurrent ? 1.5 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _tagStyle(label);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: style.$1.withValues(alpha: 0.10),
        border: Border.all(color: style.$1.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 8.2,
          height: 1.0,
          color: style.$2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (Color, Color) _tagStyle(String value) {
    final normalized = value.toUpperCase();
    if (value == '原唱' || normalized == 'ORIGINAL') {
      return (const Color(0xFF64748B), const Color(0xFF475569));
    }
    if (normalized == 'HQ') {
      return (const Color(0xFF16A34A), const Color(0xFF16A34A));
    }
    if (normalized == 'SQ') {
      return (const Color(0xFFD97706), const Color(0xFFD97706));
    }
    if (normalized == 'MASTER' ||
        normalized == 'HIRES' ||
        normalized == 'HI-RES' ||
        normalized.contains('FLAC') ||
        normalized.contains('LOSS') ||
        normalized.contains('HIRES')) {
      return (const Color(0xFFBE123C), const Color(0xFFBE123C));
    }
    return (const Color(0xFF6B7280), const Color(0xFF6B7280));
  }
}
