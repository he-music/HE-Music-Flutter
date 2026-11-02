import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

import '../../app/theme/app_ui_theme.dart';
import 'app_adaptive_controls.dart';
import '../../app/theme/skin/app_skin_icon.dart';
import '../../app/theme/skin/app_skin_models.dart';
import '../../app/theme/skin/app_skin_theme.dart';
import '../constants/layout_tokens.dart';

/// Shared input geometry, focus feedback and clear action across search pages.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    required this.controller,
    required this.placeholderPrimary,
    this.placeholderSecondary,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String placeholderPrimary;
  final String? placeholderSecondary;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static double heightFor(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return math.max(
      LayoutTokens.controlMinExtent,
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
              (style?.height ?? 1.35) +
          24,
    );
  }

  static double radiusFor(BuildContext context) =>
      AppUiTheme.usesCupertino(context)
      ? 10
      : Theme.of(
              context,
            ).extension<AppSkinTheme>()?.config.geometry.controlRadius ??
            LayoutTokens.defaultControlRadius;

  static Color materialFillColorFor(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHigh;
    final isDark = theme.brightness == Brightness.dark;
    // Cupertino fill colors are translucent overlays. Resolve them against the
    // control surface before making the search background opaque.
    final controlSurface =
        theme.extension<AppSkinTheme>()?.config.colors.fixedControlSurface ??
        theme.colorScheme.surface;
    final opaqueBase = AppUiTheme.usesCupertino(context)
        ? Color.alphaBlend(
            baseColor,
            Color.alphaBlend(
              controlSurface,
              theme.colorScheme.surface.withValues(alpha: 1),
            ),
          )
        : baseColor.withValues(alpha: 1);
    final color = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.04),
      opaqueBase,
    );
    return color;
  }

  static Widget placeholder(
    BuildContext context,
    String primary,
    String? secondary,
  ) {
    final theme = Theme.of(context);
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: primary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (secondary?.trim().isNotEmpty == true)
            TextSpan(
              text: ' ${secondary!.trim()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _localFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _localFocus;
  bool _tabNavigation = false;
  bool _showFocusRing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_handleFocusChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocus = oldWidget.focusNode ?? _localFocus;
    if (oldFocus != _focus) {
      oldFocus.removeListener(_handleFocusChanged);
      _focus.addListener(_handleFocusChanged);
      _tabNavigation = false;
      _showFocusRing = false;
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    // Modifier presses alone must not dismiss a Tab navigation indicator.
    if (const [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    ].contains(event.logicalKey)) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    _tabNavigation =
        event.logicalKey == LogicalKeyboardKey.tab &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed;
    _updateFocusFeedback();
    // Observe navigation without consuming editing keys or shortcuts.
    return false;
  }

  void _handleFocusChanged() {
    if (!_focus.hasFocus) _tabNavigation = false;
    _updateFocusFeedback();
  }

  void _updateFocusFeedback() {
    final show = _focus.hasFocus && _tabNavigation;
    if (show != _showFocusRing) setState(() => _showFocusRing = show);
  }

  void _hideFocusFeedback() {
    _tabNavigation = false;
    _updateFocusFeedback();
  }

  void _handleChanged(String value) {
    _hideFocusFeedback();
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focus.removeListener(_handleFocusChanged);
    _localFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: widget.controller,
    builder: (context, value, child) {
      final theme = Theme.of(context);
      final radius = AppSearchField.radiusFor(context);
      final height = AppSearchField.heightFor(context);
      final hint = [
        widget.placeholderPrimary,
        widget.placeholderSecondary?.trim(),
      ].whereType<String>().where((text) => text.isNotEmpty).join(' ');
      final prefix = AppSkinIcon(
        role: AppSkinIconRole.search,
        size: LayoutTokens.searchIconSize,
        color: theme.colorScheme.primary,
      );
      final suffix = value.text.isEmpty
          ? null
          : AppIconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: AppSkinIcon(
                role: AppSkinIconRole.close,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                widget.controller.clear();
                widget.onChanged?.call('');
                _focus.requestFocus();
              },
            );
      final transparentHintStyle = theme.textTheme.bodyMedium?.copyWith(
        color: Colors.transparent,
      );
      final Widget input;
      if (AppUiTheme.usesCupertino(context)) {
        input = SizedBox(
          height: height,
          child: CupertinoTextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            placeholder: hint,
            placeholderStyle: transparentHintStyle,
            style: theme.textTheme.bodyMedium,
            textInputAction: TextInputAction.search,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: prefix,
            ),
            suffix: suffix,
            decoration: BoxDecoration(
              color: AppSearchField.materialFillColorFor(context),
              borderRadius: BorderRadius.circular(radius),
              border: _showFocusRing || MediaQuery.highContrastOf(context)
                  ? Border.all(color: theme.colorScheme.primary, width: 1.2)
                  : null,
            ),
            onChanged: _handleChanged,
            onSubmitted: widget.onSubmitted,
          ),
        );
      } else {
        input = SizedBox(
          height: height,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            style: theme.textTheme.bodyMedium,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppSearchField.materialFillColorFor(context),
              hintText: hint,
              hintStyle: transparentHintStyle,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: LayoutTokens.controlHorizontalPadding,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: _showFocusRing || MediaQuery.highContrastOf(context)
                    ? BorderSide(color: theme.colorScheme.primary, width: 1.2)
                    : BorderSide.none,
              ),
              prefixIcon: prefix,
              prefixIconConstraints: const BoxConstraints(
                minWidth: LayoutTokens.searchIconSlot - 4,
                minHeight: LayoutTokens.controlMinExtent,
              ),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: LayoutTokens.controlMinExtent,
                minHeight: LayoutTokens.controlMinExtent,
              ),
            ),
            onChanged: _handleChanged,
            onSubmitted: widget.onSubmitted,
          ),
        );
      }
      return Listener(
        onPointerDown: (_) => _hideFocusFeedback(),
        child: Stack(
          children: [
            input,
            if (value.text.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: LayoutTokens.searchIconSlot,
                        end: 12,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppSearchField.placeholder(
                          context,
                          widget.placeholderPrimary,
                          widget.placeholderSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
