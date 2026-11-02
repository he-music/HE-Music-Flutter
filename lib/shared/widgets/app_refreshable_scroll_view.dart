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
    this.cupertinoRefreshIndicatorTopPadding = 0,
    super.key,
  }) : assert(cupertinoRefreshIndicatorTopPadding >= 0);

  final RefreshCallback onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final double? cacheExtent;
  final Key? scrollViewKey;

  /// Keeps the Cupertino refresh icon below an overlaid top control.
  final double cupertinoRefreshIndicatorTopPadding;

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
          _AppRefreshSliver(
            onRefresh: onRefresh,
            topPadding: cupertinoRefreshIndicatorTopPadding,
          ),
          ...slivers,
        ],
      ),
    );
  }
}

class _AppRefreshSliver extends StatelessWidget {
  const _AppRefreshSliver({required this.onRefresh, required this.topPadding});

  final RefreshCallback onRefresh;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return CupertinoSliverRefreshControl(
      onRefresh: onRefresh,
      builder: topPadding == 0
          ? null
          : (
              context,
              refreshState,
              pulledExtent,
              refreshTriggerPullDistance,
              refreshIndicatorExtent,
            ) => Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: CupertinoSliverRefreshControl.buildRefreshIndicator(
                context,
                refreshState,
                pulledExtent,
                refreshTriggerPullDistance,
                refreshIndicatorExtent,
              ),
            ),
    );
  }
}
