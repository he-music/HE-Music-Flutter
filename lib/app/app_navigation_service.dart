import 'package:flutter/material.dart';

import 'router/app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 构造登录路由，并统一保留登录后的返回目标。
String buildLoginLocation(String redirectLocation) {
  final normalizedRedirect = redirectLocation.trim();
  // 全屏播放器是临时页面，登录后回首页可避免恢复一个没有来源栈的孤立路由。
  final effectiveRedirect =
      Uri.tryParse(normalizedRedirect)?.path == AppRoutes.player
      ? AppRoutes.home
      : normalizedRedirect;
  return Uri(
    path: AppRoutes.login,
    queryParameters:
        effectiveRedirect.isEmpty ||
            effectiveRedirect.startsWith(AppRoutes.login)
        ? null
        : <String, String>{'redirect': effectiveRedirect},
  ).toString();
}
