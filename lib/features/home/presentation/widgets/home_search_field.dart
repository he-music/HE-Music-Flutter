import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../app/theme/glass/app_glass_scope.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/widgets/app_search_field.dart';

class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    required this.placeholderPrimary,
    required this.onTap,
    this.placeholderSecondary,
    this.platformLabel,
    super.key,
  });

  static double heightFor(BuildContext context) =>
      AppSearchField.heightFor(context);

  final String placeholderPrimary;
  final String? placeholderSecondary;
  final VoidCallback onTap;
  final String? platformLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = platformLabel?.trim() ?? '';
    final radius = AppSearchField.radiusFor(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutTokens.controlHorizontalPadding,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: AppSkinIcon(
              role: AppSkinIconRole.search,
              color: theme.colorScheme.primary,
              size: LayoutTokens.searchIconSize,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppSearchField.placeholder(
              context,
              placeholderPrimary,
              placeholderSecondary,
            ),
          ),
          if (platform.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                platform,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      height: heightFor(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (AppGlassScope.controlsEnabled(context) &&
              !MediaQuery.highContrastOf(context)) {
            return GlassButton.custom(
              onTap: onTap,
              label: placeholderPrimary,
              width: constraints.maxWidth,
              height: heightFor(context),
              shape: LiquidRoundedRectangle(borderRadius: radius),
              useOwnLayer: true,
              quality: AppGlassScope.qualityOf(context),
              settings: AppSearchField.glassSettingsFor(context),
              child: content,
            );
          }
          return Material(
            color: AppSearchField.materialFillColorFor(context),
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: content,
            ),
          );
        },
      ),
    );
  }
}
