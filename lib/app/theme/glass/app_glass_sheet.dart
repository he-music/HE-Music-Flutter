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
    return Builder(
      builder: (context) {
        final theme = _theme(context);
        return Theme(
          data: theme,
          child: _MeasuredGlassSheetPage(
            enabled: fitContent,
            maxHeightFactor: heightFactor,
            showDragHandle: showDragHandle,
            contentBuilder: (sheetContext) => Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
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
            pageBuilder: (sheetContext, fittedHeightFactor, sheet) {
              final settings = AppGlassMaterial.sheetFor(sheetContext);
              return GlassModalSheetScaffold(
                controller: _controller,
                quality: AppGlassScope.qualityOf(sheetContext),
                initialState: GlassSheetState.half,
                detents: const {GlassSheetDetent.medium},
                halfSize: fittedHeightFactor,
                bottomMargin: _sheetBottomMargin,
                topBorderRadius: 56,
                fullTopBorderRadius: 46,
                settings: settings,
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
                sheet: sheet,
              );
            },
          ),
        );
      },
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

/// Measures fit-content sheets before creating the glass scaffold. This keeps
/// the route entrance animation on the final content height instead of first
/// opening at the maximum and shrinking on the next frame.
class _MeasuredGlassSheetPage extends StatefulWidget {
  const _MeasuredGlassSheetPage({
    required this.enabled,
    required this.maxHeightFactor,
    required this.showDragHandle,
    required this.contentBuilder,
    required this.pageBuilder,
  });

  final bool enabled;
  final double maxHeightFactor;
  final bool showDragHandle;
  final WidgetBuilder contentBuilder;
  final Widget Function(BuildContext, double, Widget) pageBuilder;

  @override
  State<_MeasuredGlassSheetPage> createState() =>
      _MeasuredGlassSheetPageState();
}

class _MeasuredGlassSheetPageState extends State<_MeasuredGlassSheetPage> {
  double? _contentHeight;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.pageBuilder(
        context,
        widget.maxHeightFactor,
        widget.contentBuilder(context),
      );
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight =
        (screenHeight * widget.maxHeightFactor - _sheetBottomMargin).clamp(
          0.0,
          double.infinity,
        );
    if (_contentHeight == null) {
      return Offstage(
        child: _MeasureSheetHeight(
          maxHeight: maxHeight,
          onHeight: (height) {
            if (mounted &&
                (_contentHeight == null ||
                    (_contentHeight! - height).abs() > 0.5)) {
              setState(() => _contentHeight = height);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(top: widget.showDragHandle ? 20 : 0),
            child: widget.contentBuilder(context),
          ),
        ),
      );
    }

    final fittedHeightFactor =
        ((_contentHeight! + _sheetBottomMargin) / screenHeight).clamp(
          0.01,
          widget.maxHeightFactor,
        );
    return widget.pageBuilder(
      context,
      fittedHeightFactor,
      Padding(
        padding: EdgeInsets.only(top: widget.showDragHandle ? 20 : 0),
        child: widget.contentBuilder(context),
      ),
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
