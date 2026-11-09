import 'package:flutter/material.dart';

import '../app_navigation_service.dart';

class AppPageRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissActiveInputFocus();
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    dismissActiveInputFocus();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

// Each Navigator needs its own observer instance.
final appPageRouteObserver = AppPageRouteObserver();
final appContentRouteObserver = AppPageRouteObserver();
final appHomeRouteObserver = AppPageRouteObserver();
final appLibraryRouteObserver = AppPageRouteObserver();
final appMyRouteObserver = AppPageRouteObserver();
