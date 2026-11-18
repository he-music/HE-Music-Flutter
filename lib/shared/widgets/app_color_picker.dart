import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

/// An opaque HSV picker. Drag updates stay local; persistence belongs in
/// onChangeEnd so a pointer stream never rebuilds the whole application.
class AppColorPicker extends StatefulWidget {
  const AppColorPicker({
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
    required this.hueLabel,
    required this.saturationLabel,
    required this.brightnessLabel,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color> onChangeEnd;
  final String hueLabel;
  final String saturationLabel;
  final String brightnessLabel;

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  @override
  void didUpdateWidget(covariant AppColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color.toARGB32() != _hsv.toColor().toARGB32()) {
      final next = HSVColor.fromColor(widget.color);
      // Gray and black have no recoverable hue. Keep the last chromatic
      // coordinates so lifting brightness/saturation restores the chosen hue.
      _hsv = next
          .withHue(next.saturation == 0 ? _hsv.hue : next.hue)
          .withSaturation(next.value == 0 ? _hsv.saturation : next.saturation);
    }
  }

  void _change(HSVColor value) {
    setState(() => _hsv = value);
    widget.onChanged(value.toColor());
  }

  void _commit() => widget.onChangeEnd(_hsv.toColor());

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final saturation = '${(_hsv.saturation * 100).round()}%';
    final brightness = '${(_hsv.value * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text('${widget.saturationLabel} $saturation'),
            Text('${widget.brightnessLabel} $brightness'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 156,
            child: _ColorSurface(
              key: const ValueKey('color-picker-saturation-value'),
              label: '${widget.saturationLabel}, ${widget.brightnessLabel}',
              formatValue: (point) =>
                  '${widget.saturationLabel} ${(point.dx * 100).round()}%, ${widget.brightnessLabel} ${((1 - point.dy) * 100).round()}%',
              semanticValue:
                  '${widget.saturationLabel} $saturation, ${widget.brightnessLabel} $brightness',
              position: Offset(_hsv.saturation, 1 - _hsv.value),
              thumbColor: _hsv.toColor(),
              twoDimensional: true,
              horizontalIncreaseLabel: '${widget.saturationLabel} +',
              horizontalDecreaseLabel: '${widget.saturationLabel} −',
              onChanged: (point) => _change(
                _hsv.withSaturation(point.dx).withValue(1 - point.dy),
              ),
              onChangeEnd: _commit,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, hueColor]),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text('${widget.hueLabel} ${_hsv.hue.round()}°'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SizedBox(
            height: 32,
            child: _ColorSurface(
              key: const ValueKey('color-picker-hue'),
              label: widget.hueLabel,
              formatValue: (point) => '${(point.dx * 360).round()}°',
              semanticValue: '${_hsv.hue.round()}°',
              position: Offset(_hsv.hue / 360, .5),
              thumbColor: hueColor,
              onChanged: (point) => _change(_hsv.withHue(point.dx * 360)),
              onChangeEnd: _commit,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xffff0000),
                      Color(0xffffff00),
                      Color(0xff00ff00),
                      Color(0xff00ffff),
                      Color(0xff0000ff),
                      Color(0xffff00ff),
                      Color(0xffff0000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSurface extends StatefulWidget {
  const _ColorSurface({
    super.key,
    required this.label,
    required this.semanticValue,
    required this.formatValue,
    required this.position,
    required this.thumbColor,
    required this.onChanged,
    required this.onChangeEnd,
    required this.child,
    this.twoDimensional = false,
    this.horizontalIncreaseLabel = '',
    this.horizontalDecreaseLabel = '',
  });
  final String label;
  final String semanticValue;
  final String Function(Offset) formatValue;
  final Offset position;
  final Color thumbColor;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onChangeEnd;
  final Widget child;
  final bool twoDimensional;
  final String horizontalIncreaseLabel;
  final String horizontalDecreaseLabel;

  @override
  State<_ColorSurface> createState() => _ColorSurfaceState();
}

class _ColorSurfaceState extends State<_ColorSurface> {
  final _focus = FocusNode();
  bool _dragging = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _step(Offset delta) {
    widget.onChanged(
      Offset(
        (widget.position.dx + delta.dx).clamp(0, 1),
        (widget.position.dy + delta.dy).clamp(0, 1),
      ),
    );
    widget.onChangeEnd();
  }

  void _finish() {
    if (!_dragging) return;
    _dragging = false;
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    includeSemantics: false,
    onFocusChange: (_) => setState(() {}),
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final step = HardwareKeyboard.instance.isShiftPressed ? .1 : .01;
      final delta = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
        LogicalKeyboardKey.arrowRight => Offset(step, 0),
        LogicalKeyboardKey.arrowUp =>
          widget.twoDimensional ? Offset(0, -step) : Offset(step, 0),
        LogicalKeyboardKey.arrowDown =>
          widget.twoDimensional ? Offset(0, step) : Offset(-step, 0),
        _ => null,
      };
      if (delta == null) return KeyEventResult.ignored;
      _step(delta);
      return KeyEventResult.handled;
    },
    child: Semantics(
      label: widget.label,
      value: widget.semanticValue,
      increasedValue: widget.formatValue(
        widget.twoDimensional
            ? Offset(widget.position.dx, (widget.position.dy - .05).clamp(0, 1))
            : Offset((widget.position.dx + .05).clamp(0, 1), .5),
      ),
      decreasedValue: widget.formatValue(
        widget.twoDimensional
            ? Offset(widget.position.dx, (widget.position.dy + .05).clamp(0, 1))
            : Offset((widget.position.dx - .05).clamp(0, 1), .5),
      ),
      slider: true,
      focusable: true,
      focused: _focus.hasFocus,
      onIncrease: () => _step(
        widget.twoDimensional ? const Offset(0, -.05) : const Offset(.05, 0),
      ),
      onDecrease: () => _step(
        widget.twoDimensional ? const Offset(0, .05) : const Offset(-.05, 0),
      ),
      customSemanticsActions: widget.twoDimensional
          ? {
              CustomSemanticsAction(
                label: widget.horizontalIncreaseLabel,
              ): () =>
                  _step(const Offset(.05, 0)),
              CustomSemanticsAction(
                label: widget.horizontalDecreaseLabel,
              ): () =>
                  _step(const Offset(-.05, 0)),
            }
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void change(Offset local) {
            _focus.requestFocus();
            _dragging = true;
            widget.onChanged(
              Offset(
                (local.dx / constraints.maxWidth).clamp(0, 1),
                widget.twoDimensional
                    ? (local.dy / constraints.maxHeight).clamp(0, 1)
                    : .5,
              ),
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (details) => change(details.localPosition),
            onTapUp: (_) => _finish(),
            onPanStart: (details) => change(details.localPosition),
            onPanUpdate: (details) => change(details.localPosition),
            onPanEnd: (_) => _finish(),
            onPanCancel: _finish,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.child,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _focus.hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          width: _focus.hasFocus ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: widget.position.dx * constraints.maxWidth - 10,
                  top: widget.position.dy * constraints.maxHeight - 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.thumbColor,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
