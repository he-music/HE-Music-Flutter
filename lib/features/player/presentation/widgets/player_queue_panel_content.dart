import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/player_queue_source.dart';
import '../providers/player_providers.dart';
import 'player_queue_list.dart';

class PlayerQueuePanelContent extends ConsumerStatefulWidget {
  const PlayerQueuePanelContent({this.onRequestDismiss, super.key});

  final VoidCallback? onRequestDismiss;

  @override
  ConsumerState<PlayerQueuePanelContent> createState() =>
      _PlayerQueuePanelContentState();
}

class _PlayerQueuePanelContentState
    extends ConsumerState<PlayerQueuePanelContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0)
      ..addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final playbackState = ref.watch(playerControllerProvider);
    final queue = playbackState.queue;
    final currentIndex = playbackState.currentIndex;
    final previousSnapshot = playbackState.previousQueueSnapshot;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  labelStyle: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                  unselectedLabelStyle: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                  tabs: <Widget>[
                    _QueueTabLabel(
                      title: AppI18n.t(config, 'player.queue.current'),
                      count: queue.length,
                      source: playbackState.queueSource,
                      onOpenSource:
                          playbackState.queueSource == null ||
                              !playbackState.queueSource!.isValid
                          ? null
                          : () => _openSource(
                              context,
                              playbackState.queueSource!,
                            ),
                    ),
                    _QueueTabLabel(
                      title: AppI18n.t(config, 'player.queue.previous'),
                      count: previousSnapshot?.queue.length ?? 0,
                      source: previousSnapshot?.source,
                      onOpenSource:
                          previousSnapshot?.source == null ||
                              !previousSnapshot!.source!.isValid
                          ? null
                          : () =>
                                _openSource(context, previousSnapshot.source!),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: queue.isEmpty ? null : controller.clearQueue,
                tooltip: AppI18n.t(config, 'player.queue.clear'),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _activeTabIndex,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: PlayerQueueList(
                  config: config,
                  queue: queue,
                  currentIndex: currentIndex,
                  onPlayAt: controller.playAt,
                  onRemoveAt: controller.removeTrackAt,
                  onReorder: controller.reorderQueue,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: PlayerQueueList(
                  config: config,
                  queue: previousSnapshot?.queue ?? const [],
                  currentIndex: previousSnapshot?.currentIndex ?? 0,
                  editable: false,
                  highlightCurrent: false,
                  emptyText: AppI18n.t(config, 'player.queue.previous.empty'),
                  onPlayAt: (index) {
                    widget.onRequestDismiss?.call();
                    controller.swapToPreviousQueue(startIndex: index);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
      return;
    }
    if (_activeTabIndex != _tabController.index) {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    }
  }

  void _openSource(BuildContext context, PlayerQueueSource source) {
    widget.onRequestDismiss?.call();
    final uri = Uri(
      path: source.routePath,
      queryParameters: source.queryParameters,
    );
    context.push(uri.toString());
  }
}

class _QueueTabLabel extends StatelessWidget {
  const _QueueTabLabel({
    required this.title,
    required this.count,
    this.source,
    this.onOpenSource,
  });

  final String title;
  final int count;
  final PlayerQueueSource? source;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (source != null && source!.isValid) ...<Widget>[
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenSource,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
