import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_scope.dart';
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
      Theme.of(
        context,
      ).extension<AppSkinTheme>()?.config.geometry.controlRadius ??
      LayoutTokens.defaultControlRadius;

  static Color materialFillColorFor(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHigh;
    final isDark = theme.brightness == Brightness.dark;
    final color = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.04),
      baseColor.withValues(alpha: 1),
    );
    return MediaQuery.highContrastOf(context) ||
            AppGlassScope.preferOpaqueSurfaces(context)
        ? color
        : color.withValues(alpha: math.max(baseColor.a, 0.92));
  }

  static LiquidGlassSettings glassSettingsFor(BuildContext context) {
    final baseSettings =
        InheritedLiquidGlass.of(context) ??
        LiquidGlassWidgets.globalSettings ??
        GlassThemeData.of(
          context,
        ).settingsFor(context)?.applyTo(const LiquidGlassSettings()) ??
        const LiquidGlassSettings();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Adaptive tint preserves backdrop luminance, making the search surface
    // disappear against bright wallpapers. Clear keeps optical glass effects
    // while blending the skin's fill directly over the backdrop.
    return baseSettings.copyWith(
      bodyMode: GlassBodyMode.clear,
      glassColor: materialFillColorFor(
        context,
      ).withValues(alpha: isDark ? 0.38 : 0.42),
    );
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

  @override
  void dispose() {
    _localFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
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
              : IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  constraints: const BoxConstraints.tightFor(
                    width: LayoutTokens.controlMinExtent,
                    height: LayoutTokens.controlMinExtent,
                  ),
                  visualDensity: VisualDensity.standard,
                  padding: EdgeInsets.zero,
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
          if (AppGlassScope.controlsEnabled(context) &&
              !MediaQuery.highContrastOf(context)) {
            input = GlassTextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              placeholder: hint,
              placeholderStyle: transparentHintStyle,
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textInputAction: TextInputAction.search,
              height: height,
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutTokens.controlHorizontalPadding,
              ),
              iconSpacing: 8,
              prefixIcon: SizedBox(width: 24, child: prefix),
              suffixIcon: suffix,
              shape: LiquidRoundedRectangle(borderRadius: radius),
              useOwnLayer: true,
              quality: AppGlassScope.qualityOf(context),
              settings: AppSearchField.glassSettingsFor(context),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
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
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.2,
                    ),
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
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            );
          }
          return Stack(
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
          );
        },
      );
}
