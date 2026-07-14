import 'package:flutter/material.dart';

import 'router/app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 构造登录路由，并统一保留登录后的返回目标。
String buildLoginLocation(String redirectLocation) {
  final normalizedRedirect = redirectLocation.trim();
  return Uri(
    path: AppRoutes.login,
    queryParameters:
        normalizedRedirect.isEmpty ||
            normalizedRedirect.startsWith(AppRoutes.login)
        ? null
        : <String, String>{'redirect': normalizedRedirect},
  ).toString();
}
