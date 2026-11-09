import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'app_button.dart';
import 'app_adaptive_controls.dart';

import 'app_artwork_frame.dart';
import '../image/image_color_extractor.dart';
import 'app_network_image.dart';
import 'package:flutter/services.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
import 'app_back_button.dart';
import 'music_control_surface.dart';

class MusicDetailSliverAppBar extends StatelessWidget {
  const MusicDetailSliverAppBar({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.description,
    required this.onBack,
    required this.onShowDescription,
    this.onPreviewCover,
    this.metaItems = const <MusicDetailMetaItem>[],
    this.expandedHeight = _defaultExpandedHeight,
    this.actions,
    super.key,
  });

  final String title;
  final String subtitle;
  final String coverUrl;
  final String description;
  final VoidCallback onBack;
  final VoidCallback onShowDescription;
  final VoidCallback? onPreviewCover;
  final List<MusicDetailMetaItem> metaItems;
  final double expandedHeight;
  final List<Widget>? actions;

  static const double _defaultExpandedHeight = 290;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final resolvedExpandedHeight =
        expandedHeight + (textScale - 1).clamp(0.0, 3.0) * 160;
    return SliverAppBar(
      pinned: true,
      expandedHeight: resolvedExpandedHeight,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minH = kToolbarHeight + topPadding;
          final t =
              ((constraints.maxHeight - minH) / (resolvedExpandedHeight - minH))
                  .clamp(0.0, 1.0);
          // 0: expanded, 1: collapsed
          final fade = (1.0 - t).clamp(0.0, 1.0);

          // 展开标题完全淡出后再显示工具栏标题，避免折叠末段两行标题重叠。
          final collapsedTitleOpacity = ((fade - 0.62) / 0.28).clamp(0.0, 1.0);

          // 背景尽快不透明，避免列表内容在 AppBar 下方“穿模”。
          // 使用轻量的 easeOutQuad：1 - (1 - t)^2，避免 pow 带来的额外开销。
          final bgT = 1.0 - (1.0 - fade) * (1.0 - fade);
          final toolbarBg = Color.lerp(
            Colors.transparent,
            theme.scaffoldBackgroundColor,
            bgT,
          )!;

          final iconColor = Color.lerp(
            Colors.white,
            theme.iconTheme.color ?? Colors.black,
            fade,
          )!;
          final titleColor = Color.lerp(
            Colors.white,
            theme.textTheme.titleMedium?.color ?? Colors.black,
            fade,
          )!;
          final collapsedOverlayStyle =
              AppTheme.systemOverlayStyleForBrightness(theme.brightness);
          final overlayStyle =
              (fade > 0.58 ? collapsedOverlayStyle : SystemUiOverlayStyle.light)
                  .copyWith(statusBarColor: Colors.transparent);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRect(
                  child: RepaintBoundary(
                    child: _HeroBackground(
                      title: title,
                      subtitle: subtitle,
                      metaItems: metaItems,
                      description: description,
                      coverUrl: coverUrl,
                      onShowDescription: onShowDescription,
                      onPreviewCover: onPreviewCover,
                      fade: fade,
                      compactDescription: metaItems.isNotEmpty,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: toolbarBg,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: <Widget>[
                            AppBackButton(
                              onPressed: onBack,
                              iconColor: iconColor,
                            ),
                            Expanded(
                              child: IgnorePointer(
                                ignoring: collapsedTitleOpacity <= 0,
                                child: Opacity(
                                  opacity: collapsedTitleOpacity,
                                  child: Text(
                                    key: const ValueKey<String>(
                                      'music-detail-collapsed-title',
                                    ),
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: titleColor,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            if (actions != null)
                              IconTheme.merge(
                                data: IconThemeData(color: iconColor),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions!,
                                ),
                              ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Navigation controls follow the selected SDK design language.
class MusicDetailActionButton extends StatelessWidget {
  const MusicDetailActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(icon: icon, onPressed: onPressed, tooltip: tooltip);
  }
}

class MusicDetailMetaItem {
  const MusicDetailMetaItem({required this.label, this.icon, this.child});

  final String label;
  final IconData? icon;
  final Widget? child;
}

class MusicDetailPlayAllHeader extends SliverPersistentHeaderDelegate {
  static const double _headerHeight = 56;

  static double heightFor(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return math.max(
      _headerHeight,
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
              (style?.height ?? 1.5) +
          16,
    );
  }

  MusicDetailPlayAllHeader({
    required this.height,
    required this.countText,
    required this.onPlayAll,
    this.onBatchAction,
    this.onMore,
    this.enabled = true,
    this.batchMode = false,
    this.selectedCount = 0,
    this.allSelected = false,
    this.onSelectAll,
    this.onCancelBatch,
    this.trailing,
  });

  final String countText;
  final VoidCallback onPlayAll;
  final VoidCallback? onBatchAction;
  final VoidCallback? onMore;
  final bool enabled;
  final bool batchMode;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  final VoidCallback? onCancelBatch;
  final Widget? trailing;

  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // extent 与操作栏高度保持一致，避免 layoutExtent 超出 paintExtent。
    return MusicDetailPlayAllHeaderBox(
      collapseProgress: (shrinkOffset / height).clamp(0.0, 1.0),
      countText: countText,
      onPlayAll: onPlayAll,
      onBatchAction: onBatchAction,
      onMore: onMore,
      enabled: enabled,
      batchMode: batchMode,
      selectedCount: selectedCount,
      allSelected: allSelected,
      onSelectAll: onSelectAll,
      onCancelBatch: onCancelBatch,
      trailing: trailing,
    );
  }

  @override
  bool shouldRebuild(covariant MusicDetailPlayAllHeader oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.countText != countText ||
        oldDelegate.onBatchAction != onBatchAction ||
        oldDelegate.onMore != onMore ||
        oldDelegate.onPlayAll != onPlayAll ||
        oldDelegate.enabled != enabled ||
        oldDelegate.batchMode != batchMode ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.allSelected != allSelected ||
        oldDelegate.onSelectAll != onSelectAll ||
        oldDelegate.trailing != trailing ||
        oldDelegate.onCancelBatch != onCancelBatch;
  }
}

class MusicDetailPlayAllHeaderBox extends StatelessWidget {
  const MusicDetailPlayAllHeaderBox({
    required this.countText,
    required this.onPlayAll,
    this.onBatchAction,
    this.onMore,
    this.enabled = true,
    this.batchMode = false,
    this.selectedCount = 0,
    this.allSelected = false,
    this.onSelectAll,
    this.onCancelBatch,
    this.surfaceBuilder,
    this.collapseProgress = 1,
    this.trailing,
    super.key,
  });

  final String countText;
  final VoidCallback onPlayAll;
  final VoidCallback? onBatchAction;
  final VoidCallback? onMore;
  final bool enabled;
  final bool batchMode;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  final VoidCallback? onCancelBatch;

  /// 可替换固定操作栏的背景材质，默认使用统一的音乐控件材质。
  final Widget Function(BuildContext context, Widget child)? surfaceBuilder;
  final double collapseProgress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: MusicDetailPlayAllHeader.heightFor(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _MusicDetailPlayAllHeaderContent(
          countText: countText,
          onPlayAll: onPlayAll,
          onBatchAction: onBatchAction,
          onMore: onMore,
          enabled: enabled,
          batchMode: batchMode,
          selectedCount: selectedCount,
          allSelected: allSelected,
          onSelectAll: onSelectAll,
          onCancelBatch: onCancelBatch,
          trailing: trailing,
        ),
      ),
    );
    if (surfaceBuilder != null) {
      return surfaceBuilder!(context, child);
    }
    return MusicControlSurface(
      collapseProgress: collapseProgress,
      joinsCover: collapseProgress < 1,
      child: child,
    );
  }
}

class _MusicDetailPlayAllHeaderContent extends StatelessWidget {
  const _MusicDetailPlayAllHeaderContent({
    required this.countText,
    required this.onPlayAll,
    required this.onBatchAction,
    required this.onMore,
    required this.enabled,
    required this.batchMode,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onCancelBatch,
    this.trailing,
  });

  final String countText;
  final VoidCallback onPlayAll;
  final VoidCallback? onBatchAction;
  final VoidCallback? onMore;
  final bool enabled;
  final bool batchMode;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  final VoidCallback? onCancelBatch;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final effectivePrimary = enabled
        ? theme.colorScheme.primary
        : theme.hintColor.withValues(alpha: 0.55);
    if (batchMode) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppI18n.formatByLocaleCode(
                localeCode,
                'detail.batch.selected_count',
                <String, String>{'count': '$selectedCount'},
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onSelectAll,
            icon: AppSkinIcon(
              role: allSelected
                  ? AppSkinIconRole.batchDeselectAll
                  : AppSkinIconRole.batchSelectAll,
            ),
            color: allSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            tooltip: AppI18n.tByLocaleCode(
              localeCode,
              allSelected
                  ? 'detail.batch.deselect_all'
                  : 'detail.batch.select_all',
            ),
          ),
          IconButton(
            onPressed: onCancelBatch,
            icon: const AppSkinIcon(role: AppSkinIconRole.close),
            tooltip: AppI18n.tByLocaleCode(localeCode, 'detail.batch.cancel'),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactBatch =
            trailing != null &&
            constraints.maxWidth < 480 &&
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: enabled ? onPlayAll : null,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 22,
                        color: effectivePrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          countText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: enabled ? null : theme.hintColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onBatchAction != null)
              if (compactBatch)
                IconButton(
                  onPressed: onBatchAction,
                  tooltip: AppI18n.tByLocaleCode(
                    localeCode,
                    'detail.batch.action',
                  ),
                  icon: const AppSkinIcon(role: AppSkinIconRole.batchSelectAll),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: AppButton.text(
                    onPressed: onBatchAction,
                    child: Text(
                      AppI18n.tByLocaleCode(localeCode, 'detail.batch.action'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (trailing != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * (compactBatch ? 0.6 : 0.45),
                ),
                child: trailing!,
              ),
            if (onMore != null)
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: AppI18n.tByLocaleCode(localeCode, 'common.more'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
          ],
        );
      },
    );
  }
}

class _HeroBackground extends StatefulWidget {
  const _HeroBackground({
    required this.title,
    required this.subtitle,
    required this.metaItems,
    required this.description,
    required this.coverUrl,
    required this.onShowDescription,
    required this.onPreviewCover,
    required this.fade,
    required this.compactDescription,
  });

  final String title;
  final String subtitle;
  final List<MusicDetailMetaItem> metaItems;
  final String description;
  final String coverUrl;
  final VoidCallback onShowDescription;
  final VoidCallback? onPreviewCover;
  final double fade;
  final bool compactDescription;

  @override
  State<_HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends State<_HeroBackground> {
  Color? _artworkColor;
  Widget _atmosphere = const SizedBox.expand();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolveArtwork();
  }

  @override
  void didUpdateWidget(covariant _HeroBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl.trim() != widget.coverUrl.trim()) _resolveArtwork();
  }

  void _resolveArtwork() {
    final generation = ++_generation;
    final url = widget.coverUrl.trim();
    _artworkColor = null;
    if (url.isEmpty) {
      _atmosphere = const SizedBox.expand();
      return;
    }
    final provider = ResizeImage(
      NetworkImage(url),
      width: 256,
      policy: ResizeImagePolicy.fit,
    );
    // The filtered artwork is cached independently from scroll-driven metadata.
    // Decode and blur stay bounded; no list row or pinned control is filtered.
    _atmosphere = RepaintBoundary(
      key: const ValueKey('music-detail-atmosphere'),
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
          tileMode: TileMode.clamp,
        ),
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
    colorsFromImageProvider(provider, prioritizeSaturation: false).then((
      colors,
    ) {
      if (!mounted || generation != _generation || colors.isEmpty) return;
      setState(() => _artworkColor = colors.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fade = widget.fade.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = _artworkColor ?? colors.surfaceContainerHigh;
    final readingSurface = Color.lerp(
      colors.surface,
      accent,
      dark ? 0.14 : 0.08,
    )!;
    final foreground = Color.lerp(colors.onSurface, accent, 0.025)!;
    final secondary = Color.lerp(colors.onSurfaceVariant, accent, 0.035)!;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          key: const ValueKey('music-detail-reading-surface'),
          color: readingSurface.withValues(alpha: 0.50),
        ),
        Opacity(opacity: 0.55 * (1 - fade), child: _atmosphere),
        DecoratedBox(
          key: const ValueKey('music-detail-reading-gradient'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.lerp(
                  Colors.black.withValues(alpha: 0.62),
                  readingSurface,
                  fade,
                )!,
                readingSurface.withValues(alpha: 0.64),
                readingSurface.withValues(alpha: 0.96),
              ],
              stops: const <double>[0, 0.36, 1],
            ),
          ),
        ),
        if (widget.onPreviewCover != null && widget.coverUrl.trim().isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPreviewCover,
            ),
          ),
        OverflowBox(
          alignment: Alignment.bottomLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final coverSize = largeText
                    ? 80.0
                    : (constraints.maxWidth * 0.42).clamp(112.0, 176.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Opacity(
                      opacity: (1 - fade * 1.8).clamp(0.0, 1.0),
                      child: GestureDetector(
                        onTap: widget.onPreviewCover,
                        child: SizedBox.square(
                          key: const ValueKey('music-detail-artwork'),
                          dimension: coverSize,
                          child: AppArtworkFrame(
                            showShadow: true,
                            borderRadius: BorderRadius.circular(16),
                            child: _HeroImage(url: widget.coverUrl),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _HeroMeta(
                        title: widget.title,
                        subtitle: widget.subtitle,
                        metaItems: widget.metaItems,
                        description: widget.description,
                        onShowDescription: widget.onShowDescription,
                        compactDescription: widget.compactDescription,
                        fade: fade,
                        foreground: foreground,
                        secondaryForeground: secondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    required this.title,
    required this.subtitle,
    required this.metaItems,
    required this.description,
    required this.onShowDescription,
    required this.compactDescription,
    required this.fade,
    required this.foreground,
    required this.secondaryForeground,
  });

  final String title;
  final String subtitle;
  final List<MusicDetailMetaItem> metaItems;
  final String description;
  final VoidCallback onShowDescription;
  final bool compactDescription;
  final double fade;
  final Color foreground;
  final Color secondaryForeground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = foreground;
    final normalizedSubtitle = subtitle.trim();
    final normalizedMetaItems = metaItems
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
    final titleOpacity = ((0.58 - fade) / 0.20).clamp(0.0, 1.0);
    final subtitleOpacity = ((0.96 - fade) / 0.36).clamp(0.0, 1.0);
    final metaOpacity = ((0.86 - fade) / 0.40).clamp(0.0, 1.0);
    final descriptionOpacity = ((0.70 - fade) / 0.34).clamp(0.0, 1.0);
    final showSubtitle =
        normalizedSubtitle.isNotEmpty && subtitleOpacity > 0.001;
    final showMeta = normalizedMetaItems.isNotEmpty && metaOpacity > 0.001;
    final showDescription =
        description.trim().isNotEmpty && descriptionOpacity > 0.001;
    return DefaultTextStyle(
      style: theme.textTheme.bodySmall!.copyWith(color: textColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Opacity(
            opacity: titleOpacity,
            child: Text(
              key: const ValueKey<String>('music-detail-expanded-title'),
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: textColor,
              ),
            ),
          ),
          if (showSubtitle) ...<Widget>[
            const SizedBox(height: 4),
            Opacity(
              opacity: subtitleOpacity,
              child: Text(
                normalizedSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryForeground.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
          if (showMeta) ...<Widget>[
            const SizedBox(height: 8),
            Opacity(
              opacity: metaOpacity,
              child: Wrap(
                spacing: 14,
                runSpacing: 8,
                children: normalizedMetaItems
                    .map((item) {
                      final itemColor = secondaryForeground.withValues(
                        alpha: 0.90,
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (item.icon != null) ...<Widget>[
                            Icon(item.icon, size: 14, color: itemColor),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: DefaultTextStyle.merge(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: itemColor,
                              ),
                              child: item.child ?? Text(item.label.trim()),
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
          if (showDescription) ...<Widget>[
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: descriptionOpacity < 0.1,
              child: Opacity(
                opacity: descriptionOpacity,
                child: InkWell(
                  onTap: onShowDescription,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            description.trim(),
                            maxLines: compactDescription ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondaryForeground.withValues(
                                alpha: 0.92,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: secondaryForeground.withValues(alpha: 0.80),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.album_rounded,
        size: 42,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
      ),
    );
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: AppNetworkImage(
        url: url,
        fit: BoxFit.contain,
        cacheWidth: 512,
        fallback: fallback,
      ),
    );
  }
}
