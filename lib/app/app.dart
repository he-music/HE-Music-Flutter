import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import 'app_navigation_service.dart';
import 'app_scroll_behavior.dart';
import 'config/app_config_controller.dart';
import 'config/app_theme_mode.dart';
import '../features/lyrics/presentation/providers/lyrics_providers.dart';
import '../core/network/unauthorized_redirect_interceptor.dart';
import '../features/lyrics_overlay/presentation/providers/overlay_lyrics_provider.dart';
import '../features/online/presentation/providers/online_providers.dart';
import 'i18n/app_i18n.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'router/platform_route_policy.dart';
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
    final appConfig = ref.watch(
      appConfigProvider.select(
        (state) => (
          themeMode: state.themeMode,
          themeAccent: state.themeAccent,
          skinId: state.skinId,
          customSkinConfig: state.customSkinConfig,
          enableSkinAnimation: state.enableSkinAnimation,
          showContentBackground: state.showContentBackground,
          isMonochrome: state.isMonochrome,
          localeCode: state.localeCode,
        ),
      ),
    );
    final skin = AppSkinRegistry.withCustom(
      appConfig.themeAccent,
      appConfig.customSkinConfig,
    ).resolve(appConfig.skinId);
    return MaterialApp.router(
      title: AppI18n.tByLocaleCode(appConfig.localeCode, 'app.title'),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      themeMode: _toThemeMode(appConfig.themeMode),
      theme: AppTheme.light(
        skin,
        showContentBackground: appConfig.showContentBackground,
      ),
      darkTheme: AppTheme.dark(
        skin,
        showContentBackground: appConfig.showContentBackground,
      ),
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
        final startupGated = _AppStartupGate(child: startupChild);
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
  const _AppStartupGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) => _StartupUnauthorizedHandoff(
          unauthorized:
              startup.hasError && _isUnauthorizedError(startup.error!),
          startupReady:
              startup.hasValue && !startup.isLoading && !startup.hasError,
          child: _buildGate(
            context,
            ref,
            startup,
            router.routeInformationProvider.value.uri,
          ),
        ),
      ),
    );
  }

  Widget _buildGate(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<void> startup,
    Uri location,
  ) {
    final bypassStartupGate =
        location.path.startsWith(AppRoutes.login) ||
        location.path.startsWith(AppRoutes.captcha);
    if (canOpenWithoutPlatforms(location)) {
      final local = ref.watch(appLocalStartupProvider);
      if (local.hasValue) return child;
      startup = local;
    }
    // A valid snapshot remains usable while startup observes refreshed metadata.
    if (startup.isLoading && startup.hasValue) {
      final platforms = ref.watch(onlinePlatformsProvider);
      if (!platforms.isLoading && (platforms.value?.isNotEmpty ?? false)) {
        return child;
      }
    }
    final localeCode = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    return startup.when(
      skipLoadingOnRefresh: false,
      data: (_) => child,
      loading: () {
        if (bypassStartupGate) return child;
        return _StartupScaffold(
          title: 'HE-Music',
          subtitle: AppI18n.tByLocaleCode(localeCode, 'startup.loading'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 20),
              _OfflineStartupActions(localeCode: localeCode),
            ],
          ),
        );
      },
      error: (error, _) {
        if (bypassStartupGate) {
          return child;
        }
        if (_isUnauthorizedError(error)) {
          return child;
        }
        return _StartupScaffold(
          title: AppI18n.tByLocaleCode(localeCode, 'startup.failed'),
          subtitle: _describeStartupError(error, localeCode),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton(
                onPressed: () {
                  ref.invalidate(onlinePlatformsProvider);
                  ref.invalidate(appStartupProvider);
                },
                child: Text(AppI18n.tByLocaleCode(localeCode, 'common.retry')),
              ),
              const SizedBox(height: 12),
              _OfflineStartupActions(localeCode: localeCode),
            ],
          ),
        );
      },
    );
  }

  bool _isUnauthorizedError(Object error) {
    return error is DioException && shouldRedirectUnauthorized(error);
  }

  String _describeStartupError(Object error, String localeCode) {
    if (error is StateError) {
      final message = error.message.toString().trim();
      return message.isEmpty
          ? AppI18n.tByLocaleCode(localeCode, 'startup.init_failed')
          : message;
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.transformTimeout => AppI18n.tByLocaleCode(
          localeCode,
          'startup.network_timeout',
        ),
        DioExceptionType.connectionError => AppI18n.tByLocaleCode(
          localeCode,
          'startup.network_failed',
        ),
        DioExceptionType.badCertificate => AppI18n.tByLocaleCode(
          localeCode,
          'startup.certificate_failed',
        ),
        DioExceptionType.badResponse => AppI18n.formatByLocaleCode(
          localeCode,
          'startup.response_error',
          {'code': '${error.response?.statusCode ?? '-'}'},
        ),
        DioExceptionType.cancel => AppI18n.tByLocaleCode(
          localeCode,
          'startup.request_cancelled',
        ),
        DioExceptionType.unknown => AppI18n.tByLocaleCode(
          localeCode,
          'startup.network_error',
        ),
      };
    }
    return AppI18n.tByLocaleCode(localeCode, 'startup.init_failed');
  }
}

// Keep this state mounted across login and home so returning does not replay 401.
class _StartupUnauthorizedHandoff extends ConsumerStatefulWidget {
  const _StartupUnauthorizedHandoff({
    required this.child,
    required this.unauthorized,
    required this.startupReady,
  });

  final Widget child;
  final bool unauthorized;
  final bool startupReady;

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
    _scheduleLoginIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _StartupUnauthorizedHandoff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startupReady) _loginPushed = false;
    _scheduleLoginIfNeeded();
  }

  void _scheduleLoginIfNeeded() {
    if (!widget.unauthorized || _loginPushed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushLoginWhenReady());
  }

  void _pushLoginWhenReady() {
    if (!mounted || !widget.unauthorized || _loginPushed) {
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
      _loginPushed = true;
      return;
    }
    if (canOpenWithoutPlatforms(Uri.parse(currentLocation))) return;
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

class _OfflineStartupActions extends ConsumerWidget {
  const _OfflineStartupActions({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        AppI18n.tByLocaleCode(localeCode, 'startup.offline_hint'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => ref.read(appRouterProvider).go(AppRoutes.library),
            icon: const Icon(Icons.library_music_outlined),
            label: Text(AppI18n.tByLocaleCode(localeCode, 'local.title')),
          ),
          TextButton.icon(
            onPressed: () =>
                ref.read(appRouterProvider).go(AppRoutes.downloads),
            icon: const Icon(Icons.download_done_rounded),
            label: Text(
              AppI18n.tByLocaleCode(localeCode, 'download.tab.downloaded'),
            ),
          ),
        ],
      ),
    ],
  );
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
    final showLegacyGradient = theme.scaffoldBackgroundColor.a != 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: showLegacyGradient
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    theme.colorScheme.surface,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.24),
                    theme.colorScheme.surfaceContainerLowest,
                  ],
                )
              : null,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
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
