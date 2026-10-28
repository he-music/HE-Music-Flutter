import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scroll_to_top_overlay.dart';

/// Shared nested scrolling for song detail pages. The page shell owns the
/// scaffold; only the floating control rebuilds when its visibility changes.
class SongDetailScrollView extends StatefulWidget {
  const SongDetailScrollView({
    required this.headerSliverBuilder,
    required this.body,
    this.batchMode = false,
    super.key,
  });

  final NestedScrollViewHeaderSliversBuilder headerSliverBuilder;
  final Widget body;
  final bool batchMode;

  @override
  State<SongDetailScrollView> createState() => _SongDetailScrollViewState();
}

class _SongDetailScrollViewState extends State<SongDetailScrollView> {
  final _scrollKey = GlobalKey<NestedScrollViewState>();
  final _showButton = ValueNotifier(false);
  bool _visibilityUpdateQueued = false;

  // Notifications can arrive during layout (including viewport resizing).
  // Coalesce them after layout and notify only when crossing the threshold.
  void _queueVisibilityUpdate() {
    if (_visibilityUpdateQueued) return;
    _visibilityUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visibilityUpdateQueued = false;
      final scroll = _scrollKey.currentState;
      if (scroll == null || !scroll.outerController.hasClients) {
        _showButton.value = false;
        return;
      }
      final outer = scroll.outerController.position;
      if (!outer.hasContentDimensions || outer.viewportDimension <= 0) return;
      var innerDistance = 0.0;
      for (final position in scroll.innerController.positions) {
        if (position.hasContentDimensions) {
          innerDistance = math.max(
            innerDistance,
            position.pixels - position.minScrollExtent,
          );
        }
      }
      final distance =
          math.max(0.0, outer.pixels - outer.minScrollExtent) + innerDistance;
      _showButton.value = distance > outer.viewportDimension * 2;
    });
  }

  void _scrollToTop() {
    final controller = _scrollKey.currentState?.outerController;
    if (controller == null || !controller.hasClients) return;
    final top = controller.position.minScrollExtent;
    // The nested coordinator returns both the inner list and the hero header.
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(top);
    } else {
      unawaited(
        controller.animateTo(
          top,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _showButton.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              _queueVisibilityUpdate();
            }
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                _queueVisibilityUpdate();
              }
              return false;
            },
            child: NestedScrollView(
              key: _scrollKey,
              headerSliverBuilder: widget.headerSliverBuilder,
              body: widget.body,
            ),
          ),
        ),
        Positioned(
          right: padding.right + 16,
          // Glass player chrome overlays the body and supplies its clearance
          // through MediaQuery. Skin player chrome is already outside the body.
          bottom: padding.bottom + 16,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showButton,
            builder: (context, showButton, _) => ScrollToTopButton(
              visible: showButton && !widget.batchMode,
              onPressed: _scrollToTop,
            ),
          ),
        ),
      ],
    );
  }
}
