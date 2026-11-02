import 'package:flutter/cupertino.dart' hide RefreshCallback;
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';

/// A stable scroll view whose refresh affordance follows the chosen design.
class AppRefreshableScrollView extends StatelessWidget {
  const AppRefreshableScrollView({
    required this.onRefresh,
    required this.slivers,
    this.controller,
    this.physics,
    this.primary,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.cacheExtent,
    this.scrollViewKey,
    super.key,
  });

  final RefreshCallback onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final double? cacheExtent;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final cupertino = AppUiTheme.usesCupertino(context);
    // Keep both the wrapper and scroll view mounted across interface changes.
    return RefreshIndicator(
      onRefresh: onRefresh,
      elevation: 0,
      notificationPredicate: cupertino
          ? (_) => false
          : defaultScrollNotificationPredicate,
      child: CustomScrollView(
        key: scrollViewKey,
        controller: controller,
        primary: primary,
        physics: cupertino
            ? const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              )
            : physics ?? const AlwaysScrollableScrollPhysics(),
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        cacheExtent: cacheExtent,
        slivers: [
          _AppRefreshSliver(onRefresh: onRefresh),
          ...slivers,
        ],
      ),
    );
  }
}

class _AppRefreshSliver extends StatelessWidget {
  const _AppRefreshSliver({required this.onRefresh});
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) => AppUiTheme.usesCupertino(context)
      ? CupertinoSliverRefreshControl(onRefresh: onRefresh)
      : const SliverToBoxAdapter(child: SizedBox.shrink());
}
