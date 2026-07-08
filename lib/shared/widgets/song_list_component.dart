import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import 'animated_skeleton.dart';

class SongListComponent extends ConsumerStatefulWidget {
  const SongListComponent({
    required this.itemCount,
    required this.itemBuilder,
    this.initialLoading = false,
    this.enablePaging = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
    this.skeletonCount = 8,
    this.empty,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool initialLoading;
  final bool enablePaging;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function()? onLoadMore;
  final int skeletonCount;
  final Widget? empty;

  @override
  ConsumerState<SongListComponent> createState() => _SongListComponentState();
}

class _SongListComponentState extends ConsumerState<SongListComponent> {
  bool _loadingMoreTriggered = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SongListComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingMore && !widget.loadingMore) {
      _loadingMoreTriggered = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    if (widget.initialLoading) {
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: widget.skeletonCount,
        separatorBuilder: (context, index) => const SizedBox(height: 2),
        itemBuilder: (context, index) => const _SongSkeletonItem(),
      );
    }
    if (widget.itemCount == 0) {
      return widget.empty ??
          Center(child: Text(AppI18n.t(config, 'search.result.empty')));
    }
    final showFooter =
        widget.enablePaging && (widget.loadingMore || !widget.hasMore);
    final list = ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: widget.itemCount + (showFooter ? 1 : 0),
      separatorBuilder: (context, index) {
        if (showFooter && index == widget.itemCount - 1) {
          return const SizedBox(height: 8);
        }
        return const SizedBox(height: 2);
      },
      itemBuilder: (context, index) {
        if (index >= widget.itemCount) {
          return _buildFooter(context);
        }
        return widget.itemBuilder(context, index);
      },
    );
    if (!widget.enablePaging) {
      return list;
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _maybeLoadMore(notification.metrics);
        return false;
      },
      child: list,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    if (widget.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SkeletonBox(width: 96, height: 12, radius: 999)),
      );
    }
    if (!widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            AppI18n.t(config, 'search.result.no_more'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (!widget.enablePaging ||
        widget.onLoadMore == null ||
        widget.loadingMore ||
        !widget.hasMore ||
        _loadingMoreTriggered) {
      return;
    }
    if (metrics.pixels < metrics.maxScrollExtent - 120) {
      return;
    }
    _loadingMoreTriggered = true;
    widget.onLoadMore?.call();
  }
}

class _SongSkeletonItem extends StatelessWidget {
  const _SongSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SkeletonBox(width: 52, height: 52, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(
                  width: double.infinity,
                  height: 13,
                  radius: 4,
                ),
                const SizedBox(height: 6),
                const SkeletonBox(width: 180, height: 11, radius: 4),
                const SizedBox(height: 6),
                const SkeletonBox(width: 120, height: 10, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SkeletonBox(width: 18, height: 18, radius: 999),
              const SizedBox(width: 6),
              const SkeletonBox(width: 18, height: 18, radius: 999),
              const SizedBox(width: 6),
              const SkeletonBox(width: 18, height: 18, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}
