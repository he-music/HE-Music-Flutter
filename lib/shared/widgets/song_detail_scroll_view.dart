import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/glass/app_glass_scope.dart';
import '../../app/theme/skin/app_skin_theme.dart';

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
            builder: (context, showButton, _) => _ScrollToTopButton(
              visible: showButton && !widget.batchMode,
              onPressed: _scrollToTop,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollToTopButton extends ConsumerWidget {
  const _ScrollToTopButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final label = AppI18n.tByLocaleCode(localeCode, 'common.back_to_top');
    final glass =
        AppGlassScope.controlsEnabled(context) &&
        !MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const icon = Icon(Icons.vertical_align_top_rounded);
    final Widget button;
    if (glass) {
      button = Tooltip(
        message: label,
        child: GlassIconButton(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: label,
          size: 48,
          useOwnLayer: true,
          quality: AppGlassScope.qualityOf(context),
        ),
      );
    } else {
      final theme = Theme.of(context);
      final surface =
          theme.extension<AppSkinTheme>()?.config.colors.fixedControlSurface ??
          theme.colorScheme.surfaceContainerHigh;
      button = Material(
        color: surface.withValues(alpha: 1),
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: icon,
          color: theme.colorScheme.onSurface,
        ),
      );
    }
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: SizedBox.square(
            dimension: 48,
            child: reduceMotion
                ? (visible ? button : const SizedBox.shrink())
                : glass
                ? GlassMaterialize(visible: visible, child: button)
                : AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: button,
                  ),
          ),
        ),
      ),
    );
  }
}
