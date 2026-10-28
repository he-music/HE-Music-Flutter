import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/glass/app_glass_scope.dart';
import '../../app/theme/skin/app_skin_theme.dart';

/// Adds a floating back-to-top control to a scrollable child.
///
/// The control listens to the supplied controller so the surrounding content
/// does not rebuild while the user scrolls.
class ScrollToTopOverlay extends StatefulWidget {
  const ScrollToTopOverlay({
    required this.controller,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final bool enabled;

  @override
  State<ScrollToTopOverlay> createState() => _ScrollToTopOverlayState();
}

class _ScrollToTopOverlayState extends State<ScrollToTopOverlay> {
  final _showButton = ValueNotifier<bool>(false);
  bool _visibilityUpdateQueued = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_queueVisibilityUpdate);
    _queueVisibilityUpdate();
  }

  @override
  void didUpdateWidget(covariant ScrollToTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_queueVisibilityUpdate);
      widget.controller.addListener(_queueVisibilityUpdate);
      _queueVisibilityUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_queueVisibilityUpdate);
    _showButton.dispose();
    super.dispose();
  }

  void _queueVisibilityUpdate() {
    if (_visibilityUpdateQueued) return;
    _visibilityUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visibilityUpdateQueued = false;
      final controller = widget.controller;
      if (!controller.hasClients) {
        _showButton.value = false;
        return;
      }

      var shouldShow = false;
      for (final position in controller.positions) {
        if (!position.hasContentDimensions || position.viewportDimension <= 0) {
          continue;
        }
        final distance = math.max(
          0.0,
          position.pixels - position.minScrollExtent,
        );
        shouldShow = shouldShow || distance > position.viewportDimension * 2;
      }
      _showButton.value = shouldShow;
    });
  }

  void _scrollToTop() {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final top = controller.position.minScrollExtent;
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
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              _queueVisibilityUpdate();
            }
            return false;
          },
          child: widget.child,
        ),
        Positioned(
          right: padding.right + 16,
          bottom: padding.bottom + 16,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showButton,
            builder: (context, showButton, _) => ScrollToTopButton(
              visible: showButton && widget.enabled,
              onPressed: _scrollToTop,
            ),
          ),
        ),
      ],
    );
  }
}

class ScrollToTopButton extends ConsumerWidget {
  const ScrollToTopButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

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
