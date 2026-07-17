import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/startup/app_startup_provider.dart';
import '../../../../app/theme/skin/app_skin_background.dart';
import '../../../../core/device/device_info_provider.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/qr_login_state.dart';
import '../providers/qr_login_providers.dart';
import '../../../online/presentation/providers/online_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.redirectLocation, super.key});

  final String? redirectLocation;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  Timer? _authPollTimer;
  Timer? _qrPollTimer;
  bool _submitting = false;
  bool _loadingAuthProviders = true;
  bool _oauthBusy = false;
  bool _oauthPollingInFlight = false;
  bool _desktopQrInitializedInPage = false;
  List<String> _authProviders = const <String>[];
  String? _authProviderError;
  String? _oauthProvider;
  String? _oauthState;
  String? _oauthStatusText;
  int _oauthExpiresAt = 0;
  int _oauthCheckInterval = 0;
  _DesktopLoginTab _desktopLoginTab = _DesktopLoginTab.password;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    Future.microtask(_loadAuthProviders);
  }

  @override
  void dispose() {
    _authPollTimer?.cancel();
    _qrPollTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final qrState = ref.watch(qrLoginControllerProvider);
    final oauthStatusText = _oauthStatusText?.trim() ?? '';
    final isDesktopQr = _isDesktopQrPlatform;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'auth.login.title')),
        leading: AppBackButton(onPressed: _handleBack),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppSkinLegacyPageBackground(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    theme.colorScheme.surface,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.52),
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.92,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (isDesktopQr) ...<Widget>[
                              _DesktopLoginTabs(
                                config: config,
                                currentTab: _desktopLoginTab,
                                onTabChanged: _switchDesktopLoginTab,
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (!isDesktopQr ||
                                _desktopLoginTab == _DesktopLoginTab.password)
                              ..._buildPasswordLoginSection(config, theme),
                            if (isDesktopQr &&
                                _desktopLoginTab == _DesktopLoginTab.qr)
                              _DesktopQrLoginSection(
                                config: config,
                                state: qrState,
                                onRefresh: _refreshDesktopQrLogin,
                              ),
                          ],
                        ),
                      ),
                      if (oauthStatusText.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _oauthProvider == null
                                          ? AppI18n.t(
                                              config,
                                              'auth.oauth.title',
                                            )
                                          : '${AppI18n.t(config, 'auth.oauth.title')} · ${_oauthProvider!}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (_oauthBusy)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(oauthStatusText),
                              if (_oauthBusy) ...<Widget>[
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _cancelOAuthFlow,
                                  child: Text(
                                    AppI18n.t(config, 'auth.oauth.cancel'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAuthProviders() async {
    try {
      final providers = await ref
          .read(onlineApiClientProvider)
          .listAuthProviders();
      if (!mounted) {
        return;
      }
      setState(() {
        _authProviders = providers;
        _loadingAuthProviders = false;
        _authProviderError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingAuthProviders = false;
        _authProviderError =
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.load_failed');
      });
    }
  }

  bool get _isDesktopQrPlatform {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  void _switchDesktopLoginTab(_DesktopLoginTab nextTab) {
    if (_desktopLoginTab == nextTab) {
      return;
    }
    setState(() {
      _desktopLoginTab = nextTab;
    });
    if (nextTab == _DesktopLoginTab.qr) {
      if (!_desktopQrInitializedInPage) {
        _desktopQrInitializedInPage = true;
        unawaited(_refreshDesktopQrLogin());
        return;
      }
      unawaited(_restoreDesktopQrLogin());
    }
  }

  Future<void> _restoreDesktopQrLogin() async {
    final qrState = ref.read(qrLoginControllerProvider);
    final shouldCreate =
        qrState.sessionId.trim().isEmpty &&
        qrState.qrContent.trim().isEmpty &&
        !qrState.isBusy;
    if (shouldCreate) {
      await _refreshDesktopQrLogin();
      return;
    }
    if (_shouldKeepPolling(qrState.status)) {
      await _pollQrLoginStatus();
    }
  }

  Future<void> _refreshDesktopQrLogin() async {
    _qrPollTimer?.cancel();
    try {
      await ref
          .read(qrLoginControllerProvider.notifier)
          .createDesktopSession(
            clientType: 'flutter_desktop',
            clientName: 'HE Music ${Theme.of(context).platform.name}',
            scene: 'desktop_login',
          );
      if (!mounted) {
        return;
      }
      final qrState = ref.read(qrLoginControllerProvider);
      if (_shouldKeepPolling(qrState.status)) {
        _scheduleQrPolling(qrState.checkInterval);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.login.failed'),
      );
    }
  }

  void _scheduleQrPolling(int checkInterval) {
    _qrPollTimer?.cancel();
    final seconds = checkInterval > 0 ? checkInterval : 2;
    _qrPollTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_pollQrLoginStatus());
    });
  }

  Future<void> _pollQrLoginStatus() async {
    final qrState = ref.read(qrLoginControllerProvider);
    if (!_isDesktopQrPlatform ||
        qrState.sessionId.trim().isEmpty ||
        qrState.status == QrLoginWorkflowStatus.success ||
        qrState.status == QrLoginWorkflowStatus.expired ||
        qrState.status == QrLoginWorkflowStatus.cancelled) {
      return;
    }
    try {
      await ref
          .read(qrLoginControllerProvider.notifier)
          .pollDesktopSessionStatus();
      if (!mounted) {
        return;
      }
      final nextState = ref.read(qrLoginControllerProvider);
      final successToken = nextState.successToken?.trim() ?? '';
      if (successToken.isNotEmpty) {
        await ref
            .read(onlineControllerProvider.notifier)
            .loginWithToken(
              successToken,
              refreshToken: nextState.successRefreshToken,
              expiresAt: nextState.successExpiresAt,
            );
        await _finishLoginFlow();
        return;
      }
      if (_shouldKeepPolling(nextState.status)) {
        _scheduleQrPolling(nextState.checkInterval);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.login.failed'),
      );
    }
  }

  bool _shouldKeepPolling(QrLoginWorkflowStatus status) {
    return status == QrLoginWorkflowStatus.pending ||
        status == QrLoginWorkflowStatus.scanned ||
        status == QrLoginWorkflowStatus.confirmed;
  }

  List<Widget> _buildPasswordLoginSection(
    AppConfigState config,
    ThemeData theme,
  ) {
    return <Widget>[
      TextField(
        controller: _usernameController,
        textInputAction: TextInputAction.next,
        enabled: !_oauthBusy,
        decoration: InputDecoration(
          labelText: AppI18n.t(config, 'auth.login.username'),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordController,
        obscureText: true,
        enabled: !_oauthBusy,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: AppI18n.t(config, 'auth.login.password'),
          prefixIcon: const Icon(Icons.lock_outline_rounded),
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: (_submitting || _oauthBusy) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: Text(
            _submitting
                ? AppI18n.t(config, 'auth.login.submitting')
                : AppI18n.t(config, 'auth.login.submit'),
          ),
        ),
      ),
      if (_loadingAuthProviders ||
          _authProviders.isNotEmpty ||
          (_authProviderError?.trim().isNotEmpty ?? false)) ...<Widget>[
        const SizedBox(height: 18),
        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        if (_loadingAuthProviders)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_authProviders.isNotEmpty)
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _authProviders
                  .map((provider) {
                    return OutlinedButton(
                      onPressed: _oauthBusy
                          ? null
                          : () => _startOAuth(provider),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _AuthProviderIcon(provider: provider),
                          const SizedBox(width: 8),
                          Text(provider),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          )
        else if ((_authProviderError?.trim().isNotEmpty ?? false))
          Text(
            _authProviderError!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
      ],
    ];
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.trim().isEmpty) {
      AppMessageService.showError(
        AppI18n.t(ref.read(appConfigProvider), 'auth.login.empty'),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .login(username: username, password: password);
      await _finishLoginFlow();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.login.failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _startOAuth(String provider) async {
    _cancelOAuthFlow(clearStatusOnly: true);
    setState(() {
      _oauthBusy = true;
      _oauthProvider = provider;
      _oauthStatusText = AppI18n.t(
        ref.read(appConfigProvider),
        'auth.oauth.get_url',
      );
      _oauthState = null;
      _oauthExpiresAt = 0;
      _oauthCheckInterval = 0;
    });
    try {
      final deviceInfo = await ref.read(deviceInfoProvider.future);
      final result = await ref
          .read(onlineApiClientProvider)
          .getAuthCodeUrl(
            provider: provider,
            deviceInfo: deviceInfo.toApiMap(),
          );
      final authUrl = Uri.tryParse(result.url);
      if (result.url.isEmpty || result.state.isEmpty || authUrl == null) {
        throw StateError(
          AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.invalid_url'),
        );
      }
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError(
          AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.open_failed'),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _oauthState = result.state;
        _oauthExpiresAt = result.expiresAt;
        _oauthCheckInterval = result.checkInterval;
        _oauthStatusText = AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.opened',
        );
      });
      _scheduleAuthPolling(result.checkInterval);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _cancelOAuthFlow(
        statusText:
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.start_failed'),
      );
    }
  }

  void _scheduleAuthPolling(int checkInterval) {
    _authPollTimer?.cancel();
    final seconds = checkInterval > 0 ? checkInterval : 2;
    _authPollTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_pollAuthStatus());
    });
  }

  Future<void> _pollAuthStatus() async {
    final state = _oauthState?.trim() ?? '';
    if (!_oauthBusy || state.isEmpty || _oauthPollingInFlight) {
      return;
    }
    if (_isOAuthExpired()) {
      _cancelOAuthFlow(
        statusText: AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.expired',
        ),
      );
      return;
    }
    _oauthPollingInFlight = true;
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .getAuthStatus(state: state);
      if (!mounted) {
        return;
      }
      if (result.expiresAt > 0) {
        _oauthExpiresAt = result.expiresAt;
      }
      if (result.checkInterval > 0) {
        _oauthCheckInterval = result.checkInterval;
      }
      final normalizedStatus = result.status.trim().toLowerCase();
      if (_isOAuthSuccessStatus(normalizedStatus)) {
        setState(() {
          _oauthStatusText = AppI18n.t(
            ref.read(appConfigProvider),
            'auth.oauth.success',
          );
        });
        final authResult = await ref
            .read(onlineApiClientProvider)
            .exchangeAuthResult(state: state);
        if (authResult.accessToken.isEmpty) {
          throw StateError(
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.result_invalid'),
          );
        }
        await ref
            .read(onlineControllerProvider.notifier)
            .loginWithToken(
              authResult.accessToken,
              refreshToken: authResult.refreshToken,
              expiresAt: authResult.expiresAt,
            );
        if (!mounted) {
          return;
        }
        _cancelOAuthFlow(clearStatusOnly: true);
        await _finishLoginFlow();
        return;
      }
      if (_isOAuthFailedStatus(normalizedStatus)) {
        final message = result.error.trim().isNotEmpty
            ? result.error.trim()
            : AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.failed');
        _cancelOAuthFlow(statusText: message);
        return;
      }
      if (_isOAuthExpiredStatus(normalizedStatus)) {
        _cancelOAuthFlow(
          statusText: AppI18n.t(
            ref.read(appConfigProvider),
            'auth.oauth.expired',
          ),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _oauthStatusText = AppI18n.t(
          ref.read(appConfigProvider),
          'auth.oauth.waiting',
        );
      });
      _scheduleAuthPolling(
        result.checkInterval > 0 ? result.checkInterval : _oauthCheckInterval,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _cancelOAuthFlow(
        statusText:
            NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.oauth.status_failed'),
      );
    } finally {
      _oauthPollingInFlight = false;
    }
  }

  bool _isOAuthSuccessStatus(String status) {
    return status == 'success';
  }

  bool _isOAuthFailedStatus(String status) {
    return status == 'failed';
  }

  bool _isOAuthExpiredStatus(String status) {
    return status == 'expired';
  }

  bool _isOAuthExpired() {
    final expiresAt = _oauthExpiresAt;
    if (expiresAt <= 0) {
      return false;
    }
    return DateTime.now().isAfter(
      DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
  }

  void _cancelOAuthFlow({String? statusText, bool clearStatusOnly = false}) {
    _authPollTimer?.cancel();
    _authPollTimer = null;
    _oauthPollingInFlight = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _oauthBusy = false;
      _oauthState = null;
      _oauthExpiresAt = 0;
      _oauthCheckInterval = 0;
      if (clearStatusOnly) {
        _oauthStatusText = null;
        _oauthProvider = null;
      } else {
        _oauthStatusText = statusText;
      }
    });
  }

  Future<void> _finishLoginFlow() async {
    await _reloadPlatformsIfNeeded();
    if (!mounted) {
      return;
    }
    final redirect = widget.redirectLocation?.trim() ?? '';
    if (redirect.isNotEmpty && !redirect.startsWith(AppRoutes.login)) {
      context.go(redirect);
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _reloadPlatformsIfNeeded() async {
    final platformsAsync = ref.read(onlinePlatformsProvider);
    final shouldReload =
        platformsAsync.hasError || (platformsAsync.value?.isEmpty ?? true);
    if (shouldReload) {
      await ref.read(onlinePlatformsProvider.notifier).refresh();
    }
    ref.invalidate(appStartupProvider);
  }

  void _handleBack() {
    _authPollTimer?.cancel();
    _qrPollTimer?.cancel();
    final redirect = widget.redirectLocation?.trim() ?? '';
    if (redirect.isNotEmpty && !redirect.startsWith(AppRoutes.login)) {
      context.go(redirect);
      return;
    }
    context.go(AppRoutes.home);
  }
}

enum _DesktopLoginTab { password, qr }

class _DesktopLoginTabs extends StatelessWidget {
  const _DesktopLoginTabs({
    required this.config,
    required this.currentTab,
    required this.onTabChanged,
  });

  final AppConfigState config;
  final _DesktopLoginTab currentTab;
  final ValueChanged<_DesktopLoginTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primaryContainer;
    final unselectedColor = theme.colorScheme.surfaceContainerHighest;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _DesktopLoginTabButton(
              label: AppI18n.t(config, 'auth.tab.password'),
              selected: currentTab == _DesktopLoginTab.password,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTabChanged(_DesktopLoginTab.password),
            ),
          ),
          Expanded(
            child: _DesktopLoginTabButton(
              label: AppI18n.t(config, 'auth.tab.qr'),
              selected: currentTab == _DesktopLoginTab.qr,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTabChanged(_DesktopLoginTab.qr),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLoginTabButton extends StatelessWidget {
  const _DesktopLoginTabButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? selectedColor : unselectedColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopQrLoginSection extends StatelessWidget {
  const _DesktopQrLoginSection({
    required this.config,
    required this.state,
    required this.onRefresh,
  });

  final AppConfigState config;
  final QrLoginState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayText = _resolveOverlayText();
    final showRefresh = _shouldShowRefreshButton;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: state.qrContent.trim().isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : QrImageView(
                          data: state.qrContent,
                          backgroundColor: Colors.white,
                        ),
                ),
                if (overlayText != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          overlayText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showRefresh) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppI18n.t(config, 'auth.qr.refresh')),
            ),
          ),
        ],
      ],
    );
  }

  bool get _shouldShowRefreshButton {
    return state.status == QrLoginWorkflowStatus.expired ||
        state.status == QrLoginWorkflowStatus.cancelled ||
        state.status == QrLoginWorkflowStatus.failure;
  }

  String? _resolveOverlayText() {
    switch (state.status) {
      case QrLoginWorkflowStatus.scanned:
      case QrLoginWorkflowStatus.confirmed:
        return state.userHint.trim().isEmpty
            ? AppI18n.t(config, 'auth.qr.subtitle')
            : state.userHint;
      case QrLoginWorkflowStatus.expired:
        return AppI18n.t(config, 'auth.qr.expired');
      case QrLoginWorkflowStatus.cancelled:
        return AppI18n.t(config, 'auth.qr.cancelled');
      case QrLoginWorkflowStatus.failure:
        return state.errorMessage?.trim().isNotEmpty ?? false
            ? state.errorMessage
            : AppI18n.t(config, 'auth.qr.load_failed');
      case QrLoginWorkflowStatus.pending:
      case QrLoginWorkflowStatus.success:
      case QrLoginWorkflowStatus.idle:
      case QrLoginWorkflowStatus.creating:
        return null;
    }
  }
}

class _AuthProviderIcon extends StatelessWidget {
  const _AuthProviderIcon({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final assetPath = _providerAssetPath(provider);
    if (assetPath == null) {
      return Icon(
        Icons.public_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return SvgPicture.asset(
      assetPath,
      width: 18,
      height: 18,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Icon(
        Icons.public_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String? _providerAssetPath(String rawProvider) {
    final normalized = rawProvider.trim().toLowerCase();
    return switch (normalized) {
      'linuxdo' => 'assets/icons/auth/linuxdo.svg',
      _ => null,
    };
  }
}
