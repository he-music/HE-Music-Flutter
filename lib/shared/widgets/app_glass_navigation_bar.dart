import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_material.dart';
import '../../app/theme/glass/app_glass_scope.dart';
import '../../app/theme/skin/app_skin_surface.dart';

/// Official glass tab control, retaining the application's destinations.
class AppGlassNavigationBar extends StatelessWidget {
  const AppGlassNavigationBar({
    required this.child,
    this.accessory,
    this.minimizeController,
    this.onExpandFromUser,
    super.key,
  });

  final NavigationBar child;
  final Widget? accessory;
  final GlassTabBarMinimizeController? minimizeController;

  /// Whether the current page should also return to its top.
  final ValueChanged<bool>? onExpandFromUser;

  @override
  Widget build(BuildContext context) {
    if (!AppGlassScope.isEnabled(context)) {
      return AppSkinSurface(role: AppSkinSurfaceRole.navigation, child: child);
    }
    if (MediaQuery.highContrastOf(context)) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accessory != null) ...[accessory!, const SizedBox(height: 8)],
            SizedBox(height: 60, child: child),
          ],
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return GlassTabBar.minimizable(
      minimizeController: minimizeController,
      onMinimizedTabTap: () {
        if (onExpandFromUser != null) {
          onExpandFromUser!(true);
        } else {
          minimizeController?.expand();
        }
      },
      bottomAccessory: accessory,
      bottomAccessoryHeight: accessory == null ? null : 52,
      bottomAccessorySpacing: 8,
      minimizedBarHeight: 60,
      quality: AppGlassScope.qualityOf(context),
      tabs: [
        for (final destination
            in child.destinations.cast<NavigationDestination>())
          GlassTab(
            icon: destination.icon,
            activeIcon: destination.selectedIcon,
            label: destination.label,
          ),
      ],
      selectedIndex: child.selectedIndex,
      onTabSelected: (index) {
        if (onExpandFromUser != null) {
          onExpandFromUser!(index == child.selectedIndex);
        } else {
          minimizeController?.expand();
        }
        child.onDestinationSelected?.call(index);
      },
      // Parent owns spacing and safe area; retain the existing compact height.
      horizontalPadding: 0,
      verticalPadding: 0,
      barHeight: 60,
      iconLabelSpacing: 2,
      settings: AppGlassMaterial.settings(context, navigation: true),
      selectedIconColor: colors.primary,
      selectedLabelColor: colors.primary,
      unselectedIconColor: colors.onSurfaceVariant,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary.withValues(alpha: 0.12),
    );
  }
}
