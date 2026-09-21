import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_scope.dart';
import 'app_glass_material.dart';

const _sheetBottomMargin = 8.0;

/// A modal route whose glass and barrier resolve the live navigator theme.
/// The public scaffold retains the package's detents and drag mechanics.
Future<T?> showLiveGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool showDragHandle = true,
  double heightFactor = 0.45,
  // Fit shrink-wrapped content within heightFactor, keeping one detent.
  bool fitContent = false,
  ThemeData Function(ThemeData)? resolveTheme,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _LiveGlassSheetRoute<T>(
      builder: builder,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      heightFactor: heightFactor,
      fitContent: fitContent,
      resolveTheme: resolveTheme,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _LiveGlassSheetRoute<T> extends PopupRoute<T> {
  _LiveGlassSheetRoute({
    required this.builder,
    required this.useSafeArea,
    required this.showDragHandle,
    required this.heightFactor,
    required this.fitContent,
    required this.resolveTheme,
    required this.barrierLabel,
  });

  final WidgetBuilder builder;
  final bool useSafeArea;
  final bool showDragHandle;
  final double heightFactor;
  final bool fitContent;
  final ThemeData Function(ThemeData)? resolveTheme;
  final _controller = GlassModalSheetController();
  bool _closing = false;

  ThemeData _theme(BuildContext context) {
    final theme = Theme.of(context);
    return resolveTheme?.call(theme) ?? theme;
  }

  @override
  Color get barrierColor =>
      navigator != null &&
          _theme(navigator!.context).brightness == Brightness.light
      ? const Color(0x33000000)
      : GlassDefaults.barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ContentHeightScope(
      enabled: fitContent,
      maxHeightFactor: heightFactor,
      showDragHandle: showDragHandle,
      builder: (context, fittedHeightFactor, measure) => Builder(
        builder: (context) {
          final theme = _theme(context);
          return Theme(
            data: theme,
            child: Builder(
              builder: (context) {
                final settings = AppGlassMaterial.sheetFor(context);
                return GlassModalSheetScaffold(
                  controller: _controller,
                  quality: AppGlassScope.qualityOf(context),
                  // Menus rest at one height. Content scrolls immediately;
                  // upward gestures never expand the surface first.
                  initialState: GlassSheetState.half,
                  detents: const {GlassSheetDetent.medium},
                  halfSize: fittedHeightFactor,
                  bottomMargin: _sheetBottomMargin,
                  topBorderRadius: 56,
                  fullTopBorderRadius: 46,
                  settings: settings,
                  // The library still interpolates fill against its full-height
                  // threshold during overdrag, even without a large detent.
                  // Explicit identical materials keep the single surface glass.
                  halfSettings: settings,
                  fullSettings: settings,
                  maintainContentGlass: false,
                  expandedColor: theme.colorScheme.surface.withValues(alpha: 1),
                  showDragIndicator: showDragHandle,
                  dragIndicatorColor: theme.colorScheme.onSurfaceVariant,
                  onStateChanged: (state) {
                    if (state == GlassSheetState.hidden &&
                        !_closing &&
                        isCurrent) {
                      _closing = true;
                      navigator?.pop();
                    }
                  },
                  body: const SizedBox.shrink(),
                  sheet: measure(
                    Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: SafeArea(
                          top: useSafeArea,
                          bottom: useSafeArea,
                          left: useSafeArea,
                          right: useSafeArea,
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
      child: child,
    );
  }
}

/// Measure the existing subtree once at its maximum available height. Keeping
/// the measurement constraint independent of the current detent avoids a
/// shrink-only feedback loop and allows rotation/text scaling to grow it again.
class _ContentHeightScope extends StatefulWidget {
  const _ContentHeightScope({
    required this.enabled,
    required this.maxHeightFactor,
    required this.showDragHandle,
    required this.builder,
  });
  final bool enabled;
  final double maxHeightFactor;
  final bool showDragHandle;
  final Widget Function(BuildContext, double, Widget Function(Widget)) builder;

  @override
  State<_ContentHeightScope> createState() => _ContentHeightScopeState();
}

class _ContentHeightScopeState extends State<_ContentHeightScope> {
  double? _height;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final cap = screenHeight * widget.maxHeightFactor;
    // GlassModalSheetScaffold's floating bottom margin is 8 logical pixels.
    final factor = widget.enabled && _height != null
        ? ((_height! + _sheetBottomMargin) / screenHeight).clamp(
            0.01,
            widget.maxHeightFactor,
          )
        : widget.maxHeightFactor;
    return widget.builder(
      context,
      factor,
      (child) => widget.enabled
          ? _MeasureSheetHeight(
              maxHeight: (cap - _sheetBottomMargin).clamp(0, double.infinity),
              onHeight: (height) {
                if (mounted &&
                    (_height == null || (_height! - height).abs() > 0.5)) {
                  setState(() => _height = height);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(top: widget.showDragHandle ? 20 : 0),
                child: child,
              ),
            )
          : child,
    );
  }
}

class _MeasureSheetHeight extends SingleChildRenderObjectWidget {
  const _MeasureSheetHeight({
    required this.maxHeight,
    required this.onHeight,
    required super.child,
  });
  final double maxHeight;
  final ValueChanged<double> onHeight;

  @override
  _RenderSheetHeight createRenderObject(BuildContext context) =>
      _RenderSheetHeight(maxHeight, onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
    if (renderObject.maxHeight != maxHeight) {
      renderObject.maxHeight = maxHeight;
      renderObject.markNeedsLayout();
    }
  }
}

class _RenderSheetHeight extends RenderProxyBox {
  _RenderSheetHeight(this.maxHeight, this.onHeight);
  double maxHeight;
  ValueChanged<double> onHeight;
  double? _reportedHeight;

  @override
  void performLayout() {
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: maxHeight),
      parentUsesSize: true,
    );
    size = constraints.constrain(child!.size);
    final height = child!.size.height;
    if (_reportedHeight == height) return;
    _reportedHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
