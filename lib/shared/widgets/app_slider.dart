import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_ui_theme.dart';

/// Platform-independent design choice with identical editing and commit callbacks.
class AppSlider extends StatefulWidget {
  const AppSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
    this.semanticFormatterCallback,
    this.activeColor,
    this.thumbColor,
    this.secondaryTrackValue,
    super.key,
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? semanticFormatterCallback;
  final Color? activeColor;
  final Color? thumbColor;
  final double? secondaryTrackValue;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double get _step => (widget.max - widget.min) / (widget.divisions ?? 20);

  double _next(double direction) => (widget.value + direction * _step)
      .clamp(widget.min, widget.max)
      .toDouble();

  String _format(double value) =>
      widget.semanticFormatterCallback?.call(value) ??
      (widget.max == widget.min
          ? '0%'
          : '${((value - widget.min) / (widget.max - widget.min) * 100).round()}%');

  void _commit(double value) {
    if (widget.onChanged == null || value == widget.value) {
      return;
    }
    widget.onChangeStart?.call(widget.value);
    widget.onChanged!(value);
    widget.onChangeEnd?.call(value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (widget.onChanged == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => _next(rtl ? -1 : 1),
      LogicalKeyboardKey.arrowLeft => _next(rtl ? 1 : -1),
      LogicalKeyboardKey.arrowUp => _next(1),
      LogicalKeyboardKey.arrowDown => _next(-1),
      LogicalKeyboardKey.home => widget.min,
      LogicalKeyboardKey.end => widget.max,
      _ => null,
    };
    if (target == null) {
      return KeyEventResult.ignored;
    }
    _commit(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return Slider(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: widget.label,
        onChanged: widget.onChanged,
        onChangeStart: widget.onChangeStart,
        onChangeEnd: widget.onChangeEnd,
        semanticFormatterCallback: widget.semanticFormatterCallback,
        activeColor: widget.activeColor,
        thumbColor: widget.thumbColor ?? Theme.of(context).colorScheme.primary,
        secondaryTrackValue: widget.secondaryTrackValue,
      );
    }
    final enabled = widget.onChanged != null && widget.max > widget.min;
    final highlight =
        _focus.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final secondaryTrackValue = widget.secondaryTrackValue?.clamp(
      widget.min,
      widget.max,
    );
    return Focus(
      focusNode: _focus,
      canRequestFocus: enabled,
      includeSemantics: false,
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: _handleKey,
      child: Semantics(
        slider: true,
        enabled: enabled,
        focusable: enabled,
        focused: _focus.hasFocus,
        value: _format(widget.value),
        increasedValue: _format(_next(1)),
        decreasedValue: _format(_next(-1)),
        onIncrease: enabled && widget.value < widget.max
            ? () => _commit(_next(1))
            : null,
        onDecrease: enabled && widget.value > widget.min
            ? () => _commit(_next(-1))
            : null,
        excludeSemantics: true,
        child: Listener(
          onPointerDown: enabled ? (_) => _focus.requestFocus() : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: highlight
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[
                  if (secondaryTrackValue != null)
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey<String>(
                          'app-slider-secondary-track',
                        ),
                        painter: _CupertinoSecondaryTrackPainter(
                          value: secondaryTrackValue,
                          textDirection: Directionality.of(context),
                          min: widget.min,
                          max: widget.max,
                          color:
                              (widget.activeColor ??
                                      Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.32),
                        ),
                      ),
                    ),
                  CupertinoSlider(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions,
                    onChanged: enabled ? widget.onChanged : null,
                    onChangeStart: widget.onChangeStart == null
                        ? null
                        : (_) => widget.onChangeStart!(widget.value),
                    onChangeEnd: widget.onChangeEnd,
                    activeColor:
                        widget.activeColor ??
                        Theme.of(context).colorScheme.primary,
                    thumbColor:
                        widget.thumbColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoSecondaryTrackPainter extends CustomPainter {
  const _CupertinoSecondaryTrackPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.textDirection,
  });

  final double value;
  final double min;
  final double max;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final denominator = max - min;
    if (denominator <= 0) return;
    // Match the SDK CupertinoSlider track padding and thumb travel.
    const padding = 8.0;
    final trackWidth = size.width - padding * 2;
    if (trackWidth <= 0) return;
    final fraction = ((value - min) / denominator).clamp(0.0, 1.0);
    final rtl = textDirection == TextDirection.rtl;
    final travel = (trackWidth - CupertinoThumbPainter.radius * 2).clamp(
      0.0,
      double.infinity,
    );
    final thumbCenter =
        padding +
        CupertinoThumbPainter.radius +
        travel * (rtl ? 1 - fraction : fraction);
    final start = rtl ? thumbCenter : padding;
    final end = rtl ? size.width - padding : thumbCenter;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(start, size.height / 2 - 1.0, end, size.height / 2 + 1.0),
        const Radius.circular(1),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CupertinoSecondaryTrackPainter oldDelegate) =>
      value != oldDelegate.value ||
      min != oldDelegate.min ||
      max != oldDelegate.max ||
      color != oldDelegate.color ||
      textDirection != oldDelegate.textDirection;
}
