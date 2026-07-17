import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config_controller.dart';
import '../../../app/i18n/app_i18n.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/skin/app_skin_icon.dart';
import '../../../app/theme/skin/app_skin_models.dart';
import '../../../app/theme/skin/app_skin_surface.dart';
import '../../../app/theme/skin/app_skin_theme.dart';
import '../../../features/player/presentation/widgets/mini_player_bar.dart';

/// 应用级 Shell：所有窗口尺寸统一使用手机端布局。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return _MobileLayout(navigationShell: navigationShell);
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int _homeIndex = 0;
  static const int _myIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: navigationShell),
          MiniPlayerBar(onOpenFullPlayer: () => context.push(AppRoutes.player)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: AppSkinSurface(
            role: AppSkinSurfaceRole.navigation,
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex == _myIndex ? 1 : 0,
              backgroundColor: Colors.transparent,
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
                  icon: const _NavigationIcon(
                    role: AppSkinIconRole.navigationHome,
                    selected: false,
                  ),
                  selectedIcon: const _NavigationIcon(
                    role: AppSkinIconRole.navigationHomeSelected,
                    selected: true,
                  ),
                  label: AppI18n.t(config, 'tab.home'),
                ),
                NavigationDestination(
                  icon: const _NavigationIcon(
                    role: AppSkinIconRole.navigationMy,
                    selected: false,
                  ),
                  selectedIcon: const _NavigationIcon(
                    role: AppSkinIconRole.navigationMySelected,
                    selected: true,
                  ),
                  label: AppI18n.t(config, 'tab.my'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.role, required this.selected});

  final AppSkinIconRole role;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    final showLine =
        selected &&
        skinTheme != null &&
        !skinTheme.config.geometry.showNavigationIndicatorPill;
    return SizedBox(
      width: 30,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AppSkinIcon(role: role),
          if (showLine)
            Positioned(
              left: 5,
              right: 5,
              bottom: 0,
              child: DecoratedBox(
                key: const ValueKey<String>(
                  'app-skin-navigation-selection-indicator',
                ),
                decoration: BoxDecoration(
                  color: skinTheme.config.colors.selectionIndicator,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(height: 2),
              ),
            ),
        ],
      ),
    );
  }
}
