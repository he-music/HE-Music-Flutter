import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';
import '../../app/theme/skin/app_skin_surface.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({required this.child, super.key});

  final NavigationBar child;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return AppSkinSurface(
        role: AppSkinSurfaceRole.navigation,
        borderRadius: BorderRadius.zero,
        showDecoration: false,
        child: child,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return CupertinoTabBar(
      currentIndex: child.selectedIndex,
      onTap: child.onDestinationSelected,
      backgroundColor: CupertinoTheme.of(
        context,
      ).barBackgroundColor.withValues(alpha: 1),
      activeColor: colors.primary,
      inactiveColor: colors.onSurfaceVariant,
      items: [
        for (final destination
            in child.destinations.cast<NavigationDestination>())
          BottomNavigationBarItem(
            icon: destination.icon,
            activeIcon: destination.selectedIcon,
            label: destination.label,
          ),
      ],
    );
  }
}
