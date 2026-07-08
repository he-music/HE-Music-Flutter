import 'package:flutter/material.dart';

import 'app_network_image.dart';
import 'package:flutter/services.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/app_theme.dart';
import 'app_back_button.dart';

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
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minH = kToolbarHeight + topPadding;
          final t = ((constraints.maxHeight - minH) / (expandedHeight - minH))
              .clamp(0.0, 1.0);
          // 0: expanded, 1: collapsed
          final fade = (1.0 - t).clamp(0.0, 1.0);

          // 标题只做淡入，不做“从底部滑上来”的位移动画。
          final titleOpacity = ((fade - 0.35) / 0.65).clamp(0.0, 1.0);

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
                                ignoring: titleOpacity <= 0,
                                child: Opacity(
                                  opacity: titleOpacity,
                                  child: Text(
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

class MusicDetailMetaItem {
  const MusicDetailMetaItem({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

class MusicDetailPlayAllHeader extends SliverPersistentHeaderDelegate {
  static const double _headerHeight = 56;

  MusicDetailPlayAllHeader({
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

  @override
  double get minExtent => _headerHeight;

  @override
  double get maxExtent => _headerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    // 重要：SliverPersistentHeader 的 extent 必须与 child 的真实高度一致，
    // 否则会触发 “layoutExtent exceeds paintExtent” 的断言并导致页面崩溃。
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: MusicDetailPlayAllHeaderBox(
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
      ),
    );
  }

  @override
  bool shouldRebuild(covariant MusicDetailPlayAllHeader oldDelegate) {
    return oldDelegate.countText != countText ||
        oldDelegate.onBatchAction != onBatchAction ||
        oldDelegate.onMore != onMore ||
        oldDelegate.onPlayAll != onPlayAll ||
        oldDelegate.enabled != enabled ||
        oldDelegate.batchMode != batchMode ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.allSelected != allSelected ||
        oldDelegate.onSelectAll != onSelectAll ||
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MusicDetailPlayAllHeader._headerHeight,
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
        ),
      ),
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
          Text(
            AppI18n.formatByLocaleCode(
              localeCode,
              'detail.batch.selected_count',
              <String, String>{'count': '$selectedCount'},
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: allSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'detail.batch.select_all'),
            ),
          ),
          TextButton(
            onPressed: onCancelBatch,
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'detail.batch.cancel'),
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        InkWell(
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
                Text(
                  countText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (onBatchAction != null)
          TextButton(
            onPressed: onBatchAction,
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'detail.batch.action'),
            ),
          ),
        if (onMore != null)
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: AppI18n.tByLocaleCode(localeCode, 'common.more'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }
}

class _HeroBackground extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final normalizedFade = fade.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final bottomPanelColor = theme.colorScheme.surface.withValues(
      alpha: 0.94 - 0.18 * normalizedFade,
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _HeroImage(url: coverUrl),
        // 顶部保持轻量暗色遮罩，保证返回按钮与折叠标题可读。
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.18 + 0.14 * normalizedFade),
                Colors.black.withValues(alpha: 0.04 + 0.06 * normalizedFade),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.32, 0.62],
            ),
          ),
        ),
        // 底部使用浅色渐变承载文字，避免浅色封面下白字丢失对比。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 166,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    bottomPanelColor.withValues(alpha: 0.0),
                    bottomPanelColor.withValues(alpha: 0.42),
                    bottomPanelColor,
                  ],
                  stops: const <double>[0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (onPreviewCover != null && coverUrl.trim().isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPreviewCover,
            ),
          ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: _HeroMeta(
              title: title,
              subtitle: subtitle,
              metaItems: metaItems,
              description: description,
              onShowDescription: onShowDescription,
              compactDescription: compactDescription,
              fade: normalizedFade,
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
  });

  final String title;
  final String subtitle;
  final List<MusicDetailMetaItem> metaItems;
  final String description;
  final VoidCallback onShowDescription;
  final bool compactDescription;
  final double fade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final normalizedSubtitle = subtitle.trim();
    final normalizedMetaItems = metaItems
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
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
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: textColor,
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
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.92,
                  ),
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
                      final itemColor = theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.90);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (item.icon != null) ...<Widget>[
                            Icon(item.icon, size: 14, color: itemColor),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            item.label.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: itemColor,
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
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.80,
                          ),
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
    if (url.trim().isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      );
    }
    return AppNetworkImage(
      url: url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      fallback: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    );
  }
}
