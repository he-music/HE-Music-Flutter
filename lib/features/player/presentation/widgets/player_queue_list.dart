import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../domain/entities/player_track.dart';

class PlayerQueueList extends StatefulWidget {
  const PlayerQueueList({
    required this.config,
    required this.queue,
    required this.currentIndex,
    required this.onPlayAt,
    this.onRemoveAt,
    this.onReorder,
    this.editable = true,
    this.highlightCurrent = true,
    this.emptyText,
    super.key,
  });

  final AppConfigState config;
  final List<PlayerTrack> queue;
  final int currentIndex;
  final ValueChanged<int> onPlayAt;
  final ValueChanged<int>? onRemoveAt;
  final Future<void> Function(int oldIndex, int newIndex)? onReorder;
  final bool editable;
  final bool highlightCurrent;
  final String? emptyText;

  @override
  State<PlayerQueueList> createState() => _PlayerQueueListState();
}

class _PlayerQueueListState extends State<PlayerQueueList> {
  static const double _currentTrackAlignment = 0.32;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _prototypeItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant PlayerQueueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.highlightCurrent && widget.highlightCurrent) ||
        oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.queue.length != widget.queue.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent({bool animated = true}) {
    if (!mounted ||
        !widget.highlightCurrent ||
        widget.queue.isEmpty ||
        !_scrollController.hasClients) {
      return;
    }
    final safeIndex = widget.currentIndex.clamp(0, widget.queue.length - 1);
    final itemExtent = _prototypeItemKey.currentContext?.size?.height;
    final position = _scrollController.position;
    if (itemExtent == null ||
        itemExtent <= 0 ||
        !position.hasContentDimensions) {
      return;
    }
    // prototypeItem 让 Sliver 可按索引直达目标区间，无需先构建前面的歌曲行。
    final targetOffset =
        (safeIndex * itemExtent -
                (position.viewportDimension - itemExtent) *
                    _currentTrackAlignment)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if (animated) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _scrollController.jumpTo(targetOffset);
  }

  Widget _buildPrototypeItem(BuildContext context) {
    return IgnorePointer(
      child: _buildItem(context, 0, itemKey: _prototypeItemKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.queue.isEmpty) {
      return Center(
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tintColor: theme.colorScheme.surface.withValues(alpha: 0.52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Text(
            widget.emptyText ?? AppI18n.t(widget.config, 'player.queue.empty'),
          ),
        ),
      );
    }
    if (!widget.editable) {
      return ListView.builder(
        controller: _scrollController,
        prototypeItem: _buildPrototypeItem(context),
        itemCount: widget.queue.length,
        itemBuilder: (context, index) => _buildItem(context, index),
      );
    }
    return ReorderableListView.builder(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      prototypeItem: _buildPrototypeItem(context),
      itemCount: widget.queue.length,
      onReorder: (oldIndex, newIndex) => widget.onReorder!(oldIndex, newIndex),
      itemBuilder: _buildItem,
    );
  }

  Widget _buildItem(BuildContext context, int index, {Key? itemKey}) {
    final theme = Theme.of(context);
    final track = widget.queue[index];
    final artist = track.artist;
    final isCurrent = widget.highlightCurrent && index == widget.currentIndex;
    final itemIdentity =
        '${track.platform ?? ''}|${track.id}|${track.path ?? ''}|$index';
    return Padding(
      key: itemKey ?? ValueKey<String>(itemIdentity),
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onPlayAt(index),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: EdgeInsets.fromLTRB(8, 6, widget.editable ? 4 : 8, 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                _QueueIndexBadge(index: index, isCurrent: isCurrent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist == null || artist.trim().isEmpty
                            ? 'Unknown Artist'
                            : artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCurrent
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.82,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.editable && widget.onRemoveAt != null)
                  IconButton(
                    onPressed: () => widget.onRemoveAt!(index),
                    tooltip: AppI18n.t(widget.config, 'player.queue.remove'),
                    iconSize: 18,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
                    icon: const Icon(Icons.close_rounded),
                  ),
                if (widget.editable)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.78,
                        ),
                      ),
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

class _QueueIndexBadge extends StatelessWidget {
  const _QueueIndexBadge({required this.index, required this.isCurrent});

  final int index;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 28,
      child: Center(
        child: isCurrent
            ? Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              )
            : Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
