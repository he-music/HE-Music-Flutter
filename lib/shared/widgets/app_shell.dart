import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config_controller.dart';
import '../../../app/i18n/app_i18n.dart';
import '../../../app/router/app_routes.dart';
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
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex == _myIndex ? 1 : 0,
              backgroundColor: Colors.transparent,
              indicatorColor: Theme.of(context).colorScheme.primaryContainer,
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
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: AppI18n.t(config, 'tab.home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_circle_outlined),
                  selectedIcon: const Icon(Icons.account_circle_rounded),
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
