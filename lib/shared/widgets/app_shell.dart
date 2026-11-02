import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_navigation_service.dart';
import '../../../app/config/app_config_controller.dart';
import '../../../app/i18n/app_i18n.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/skin/app_skin_icon.dart';
import '../../../app/theme/skin/app_skin_models.dart';
import 'app_bottom_navigation_bar.dart';
import 'app_player_scaffold.dart';
import '../../../features/player/presentation/widgets/mini_player_bar.dart';

/// Keep bottom navigation consistent across phone, tablet, and desktop sizes.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const int _homeIndex = 0;
  static const int _myIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    final miniPlayer = MiniPlayerBar(
      onOpenFullPlayer: () => openFullPlayer(context),
    );
    Widget buildNavigation() => AppBottomNavigationBar(
      child: NavigationBar(
        selectedIndex: navigationShell.currentIndex == _myIndex ? 1 : 0,
        backgroundColor: Colors.transparent,
        maintainBottomViewPadding: true,
        onDestinationSelected: (index) {
          final branchIndex = index == 0 ? _homeIndex : _myIndex;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
          GoRouter.of(
            context,
          ).go(branchIndex == _homeIndex ? AppRoutes.home : AppRoutes.my);
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const _NavigationIcon(role: AppSkinIconRole.navigationHome),
            selectedIcon: const _NavigationIcon(
              role: AppSkinIconRole.navigationHomeSelected,
            ),
            label: AppI18n.tByLocaleCode(localeCode, 'tab.home'),
          ),
          NavigationDestination(
            icon: const _NavigationIcon(role: AppSkinIconRole.navigationMy),
            selectedIcon: const _NavigationIcon(
              role: AppSkinIconRole.navigationMySelected,
            ),
            label: AppI18n.tByLocaleCode(localeCode, 'tab.my'),
          ),
        ],
      ),
    );
    return AppPlayerScaffold(
      body: navigationShell,
      miniPlayer: miniPlayer,
      navigation: buildNavigation(),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.role});

  final AppSkinIconRole role;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 30, height: 32, child: AppSkinIcon(role: role));
}
