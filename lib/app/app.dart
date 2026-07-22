import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import 'app_navigation_service.dart';
import 'app_scroll_behavior.dart';
import 'config/app_config_controller.dart';
import 'config/app_config_state.dart';
import 'config/app_theme_mode.dart';
import '../features/lyrics/presentation/providers/lyrics_providers.dart';
import '../features/lyrics_overlay/presentation/providers/overlay_lyrics_provider.dart';
import '../features/online/presentation/providers/online_providers.dart';
import 'i18n/app_i18n.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'startup/app_startup_provider.dart';
import 'startup/app_auto_update_gate.dart';
import 'theme/app_theme.dart';
import 'theme/skin/app_skin_background.dart';
import 'theme/skin/app_skin_registry.dart';

class HeMusicApp extends ConsumerWidget {
  const HeMusicApp({super.key, this.enableStartupGateInTests = false});

  final bool enableStartupGateInTests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isTestBinding = bindingName.contains('TestWidgetsFlutterBinding');
    if (!isTestBinding) ref.watch(lyricsPrefetchBindingProvider);
    if (!isTestBinding) ref.watch(overlayLyricsBindingProvider);
    final appRouter = ref.watch(appRouterProvider);
    final appConfig = ref.watch(appConfigProvider);
    final skin = AppSkinRegistry.builtIn(
      appConfig.themeAccent,
    ).resolve(appConfig.skinId);
    return MaterialApp.router(
      title: AppI18n.t(appConfig, 'app.title'),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      themeMode: _toThemeMode(appConfig.themeMode),
      theme: AppTheme.light(skin),
      darkTheme: AppTheme.dark(skin),
      locale: _resolveLocale(appConfig.localeCode),
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final enableStartupGates = !isTestBinding || enableStartupGateInTests;
        final startupChild = enableStartupGates
            ? AppAutoUpdateGate(child: content)
            : content;
        final startupGated = _AppStartupGate(
          appConfig: appConfig,
          child: startupChild,
        );
        final gated = enableStartupGates ? startupGated : content;
        final skinned = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AppSkinBackgroundLayer(
              skin: skin,
              enableAnimation: appConfig.enableSkinAnimation,
            ),
            gated,
          ],
        );
        final overlayChild = AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemOverlayStyleForBrightness(
            Theme.of(context).brightness,
          ),
          child: skinned,
        );
        if (!appConfig.isMonochrome) return overlayChild;
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: overlayChild,
        );
      },
    );
  }

  ThemeMode _toThemeMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  Locale? _resolveLocale(String localeCode) {
    if (localeCode == 'system') {
      return null;
    }
    return Locale(localeCode);
  }
}

class _AppStartupGate extends ConsumerWidget {
  const _AppStartupGate({required this.child, required this.appConfig});

  final Widget child;
  final AppConfigState appConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final currentLocation = _currentLocation(context);
    final bypassStartupGate =
        currentLocation.startsWith(AppRoutes.login) ||
        currentLocation.startsWith(AppRoutes.captcha);
    final config = ref.watch(appConfigProvider);
    return startup.when(
      data: (_) => child,
      loading: () {
        if (bypassStartupGate) return child;
        return _StartupScaffold(
          title: 'HE-Music',
          subtitle: AppI18n.t(config, 'startup.loading'),
          body: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        );
      },
      error: (error, _) {
        if (bypassStartupGate) {
          return child;
        }
        if (_isUnauthorizedError(error)) {
          return _StartupUnauthorizedHandoff(child: child);
        }
        return _StartupScaffold(
          title: AppI18n.t(config, 'startup.failed'),
          subtitle: _describeStartupError(error, config),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(onlinePlatformsProvider.notifier).refresh();
                    ref.invalidate(appStartupProvider);
                  } catch (_) {
                    // 平台 Provider 已保存最新错误，失败页保持可重试状态。
                  }
                },
                child: Text(AppI18n.t(config, 'common.retry')),
              ),
            ],
          ),
        );
      },
    );
  }

  String _currentLocation(BuildContext context) {
    try {
      return GoRouter.of(context).state.uri.toString();
    } catch (_) {
      return '';
    }
  }

  bool _isUnauthorizedError(Object error) {
    return error is DioException && error.response?.statusCode == 401;
  }

  String _describeStartupError(Object error, AppConfigState config) {
    if (error is StateError) {
      final message = error.message.toString().trim();
      return message.isEmpty
          ? AppI18n.t(config, 'startup.init_failed')
          : message;
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => AppI18n.t(
          config,
          'startup.network_timeout',
        ),
        DioExceptionType.connectionError => AppI18n.t(
          config,
          'startup.network_failed',
        ),
        DioExceptionType.badCertificate => AppI18n.t(
          config,
          'startup.certificate_failed',
        ),
        DioExceptionType.badResponse => AppI18n.format(
          config,
          'startup.response_error',
          {'code': '${error.response?.statusCode ?? '-'}'},
        ),
        DioExceptionType.cancel => AppI18n.t(
          config,
          'startup.request_cancelled',
        ),
        DioExceptionType.unknown => AppI18n.t(config, 'startup.network_error'),
      };
    }
    return AppI18n.t(config, 'startup.init_failed');
  }
}

class _StartupUnauthorizedHandoff extends ConsumerStatefulWidget {
  const _StartupUnauthorizedHandoff({required this.child});

  final Widget child;

  @override
  ConsumerState<_StartupUnauthorizedHandoff> createState() =>
      _StartupUnauthorizedHandoffState();
}

class _StartupUnauthorizedHandoffState
    extends ConsumerState<_StartupUnauthorizedHandoff> {
  bool _loginPushed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushLoginWhenReady());
  }

  void _pushLoginWhenReady() {
    if (!mounted || _loginPushed) {
      return;
    }
    if (rootNavigatorKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pushLoginWhenReady(),
      );
      return;
    }
    final router = ref.read(appRouterProvider);
    final currentLocation = _safeRouterLocation(router);
    if (_isAuthRelatedLocation(currentLocation)) {
      return;
    }
    _loginPushed = true;
    router.push(buildLoginLocation(AppRoutes.home));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _isAuthRelatedLocation(String location) {
  return location.startsWith(AppRoutes.login) ||
      location.startsWith(AppRoutes.captcha);
}

String _safeRouterLocation(GoRouter router) {
  try {
    return router.state.uri.toString();
  } catch (_) {
    return AppRoutes.home;
  }
}

class _StartupScaffold extends StatelessWidget {
  const _StartupScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.24),
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/icons/favicon-512x512.png',
                    width: 104,
                    height: 104,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.92,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
