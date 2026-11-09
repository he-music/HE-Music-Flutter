import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_navigation_service.dart';
import '../../../app/config/app_config_controller.dart';
import '../../../app/i18n/app_i18n.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_ui_theme.dart';
import '../../../app/theme/skin/app_skin_icon.dart';
import '../../../app/theme/skin/app_skin_models.dart';
import '../../../features/player/presentation/widgets/mini_player_bar.dart';
import 'app_bottom_navigation_bar.dart';
import 'app_content_width.dart';
import 'app_player_scaffold.dart';

/// One stable playback surface surrounds the tab Navigators and browsing routes.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    this.child,
    this.location,
    this.initialBranchLocation,
    this.navigationShell,
    super.key,
  }) : assert(child != null || navigationShell != null);

  final Widget? child;
  final String? location;
  final String? initialBranchLocation;
  final StatefulNavigationShell? navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _locations = [
    AppRoutes.home,
    AppRoutes.collection,
    AppRoutes.my,
  ];

  int _lastBranch = 0;

  @override
  void initState() {
    super.initState();
    _updateBranch();
    final initial = _locations.indexOf(widget.initialBranchLocation ?? '');
    if (initial >= 0) _lastBranch = initial;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateBranch();
  }

  void _updateBranch() {
    final index = _locations.indexOf(widget.location ?? '');
    if (index >= 0) _lastBranch = index;
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    final navigationShell = widget.navigationShell;
    final index = navigationShell?.currentIndex ?? _lastBranch;
    final isTab =
        navigationShell != null || _locations.contains(widget.location);
    final showNavigation = isTab || AppUiTheme.usesCupertino(context);
    final navigation = AppBottomNavigationBar(
      child: NavigationBar(
        selectedIndex: index,
        backgroundColor: Colors.transparent,
        maintainBottomViewPadding: true,
        onDestinationSelected: (index) {
          dismissActiveInputFocus();
          if (navigationShell != null) {
            navigationShell.goBranch(index);
          } else {
            GoRouter.of(context).go(_locations[index]);
          }
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
            icon: Icon(
              AppUiTheme.usesCupertino(context)
                  ? CupertinoIcons.music_albums
                  : Icons.library_music_outlined,
            ),
            selectedIcon: Icon(
              AppUiTheme.usesCupertino(context)
                  ? CupertinoIcons.music_albums_fill
                  : Icons.library_music_rounded,
            ),
            label: AppI18n.tByLocaleCode(localeCode, 'tab.library'),
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
      body: AppContentWidth(child: widget.child ?? navigationShell!),
      miniPlayer: AppContentWidth(
        child: MiniPlayerBar(
          bottomSafeArea: !showNavigation,
          onOpenFullPlayer: () => openFullPlayer(context),
        ),
      ),
      navigation: showNavigation ? navigation : null,
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
