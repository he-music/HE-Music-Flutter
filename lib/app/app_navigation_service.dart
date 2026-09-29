import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final _openingPlayer = Expando<bool>();

/// 播放器只占一个返回位置；再次打开时保留普通页面，将播放器放到栈顶。
Future<void> openFullPlayer(BuildContext context) async {
  final router = GoRouter.of(context);
  if (_openingPlayer[router] == true) return;
  final current = router.routerDelegate.currentConfiguration;
  bool isPlayer(RouteMatchBase match) =>
      match.route is GoRoute &&
      (match.route as GoRoute).path == AppRoutes.player;
  if (isPlayer(current.last)) return;

  _openingPlayer[router] = true;
  try {
    // 播放器在 root Navigator，故只处理顶层 match，不改动 Tab 的分支历史。
    final oldPlayers = current.matches.where(isPlayer).toList();
    if (oldPlayers.isEmpty) {
      unawaited(router.push<void>(AppRoutes.player));
    } else {
      final remaining = current.matches.where((match) => !isPlayer(match));
      // 从播放器深链进入详情时，用首页补齐移走播放器后的来源页。
      final fromDeepLink = oldPlayers.any(
        (match) => match is! ImperativeRouteMatch,
      );
      final source = fromDeepLink
          ? router.configuration.findMatch(Uri.parse(AppRoutes.home))
          : current;
      final base = RouteMatchList(
        matches: [if (fromDeepLink) ...source.matches, ...remaining],
        uri: source.uri,
        pathParameters: source.pathParameters,
        extra: source.extra,
      );
      // 一次恢复完整页面栈，避免先删后 push 期间 Router 的异步更新竞态。
      router.restore(
        base.push(
          ImperativeRouteMatch(
            pageKey: ValueKey<String>('player-${UniqueKey()}'),
            matches: router.configuration.findMatch(
              Uri.parse(AppRoutes.player),
            ),
            completer: Completer<Object?>(),
          ),
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      for (final match in oldPlayers.whereType<ImperativeRouteMatch>()) {
        if (!router.routerDelegate.currentConfiguration.matches.contains(
              match,
            ) &&
            !match.completer.isCompleted) {
          match.complete();
        }
      }
    }
    // 同一帧内的连续点击共用一次导航。
    await WidgetsBinding.instance.endOfFrame;
  } finally {
    _openingPlayer[router] = false;
  }
}

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
