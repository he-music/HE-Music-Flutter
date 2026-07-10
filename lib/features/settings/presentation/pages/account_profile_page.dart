import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../my/domain/entities/my_overview_state.dart';
import '../../../my/domain/entities/my_profile.dart';
import '../../../my/presentation/providers/my_overview_providers.dart';
import '../../data/providers/account_settings_providers.dart';

class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _avatarController = TextEditingController();

  bool _loadRequested = false;
  bool _fieldsInitialized = false;
  bool _submitting = false;
  String _originalAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _avatarController.addListener(_handleAvatarChanged);
  }

  @override
  void dispose() {
    _avatarController
      ..removeListener(_handleAvatarChanged)
      ..dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final overviewState = ref.watch(myOverviewControllerProvider);
    final content = _buildContent(config, overviewState);

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'settings.profile.title')),
      ),
      body: content,
    );
  }

  Widget _buildContent(AppConfigState config, MyOverviewState overviewState) {
    if (!_isLoggedIn(config)) {
      return _buildSignedOut(config);
    }

    final profile = overviewState.overview?.profile;
    if (profile == null) {
      _requestProfileLoad(overviewState);
      if (overviewState.errorMessage != null && !overviewState.loading) {
        return _buildLoadError(config, overviewState.errorMessage!);
      }
      return const Center(child: CircularProgressIndicator());
    }
    _initializeFields(profile);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: <Widget>[
              Center(
                child: AppNetworkAvatar(
                  imageUrl: _avatarController.text.trim(),
                  radius: 44,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  fallbackIcon: Icons.person_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  iconSize: 38,
                ),
              ),
              if (profile.username.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '@${profile.username.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextFormField(
                key: const ValueKey<String>('account-profile-nickname'),
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: AppI18n.t(config, 'settings.profile.nickname'),
                  border: const OutlineInputBorder(),
                ),
                maxLength: 31,
                textInputAction: TextInputAction.next,
                validator: (value) => _validateNickname(config, value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('account-profile-avatar'),
                controller: _avatarController,
                decoration: InputDecoration(
                  labelText: AppI18n.t(config, 'settings.profile.avatar_url'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                validator: (value) => _validateAvatar(config, value),
                onFieldSubmitted: (_) => _submit(config),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey<String>('account-profile-submit'),
                onPressed: _submitting ? null : () => _submit(config),
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  AppI18n.t(
                    config,
                    _submitting
                        ? 'settings.profile.saving'
                        : 'settings.profile.save',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignedOut(AppConfigState config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline_rounded, size: 40),
            const SizedBox(height: 16),
            Text(
              AppI18n.t(config, 'settings.account.signed_out.title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppI18n.t(config, 'settings.account.signed_out.message'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openLogin(AppRoutes.settingsProfile),
              icon: const Icon(Icons.login_rounded),
              label: Text(AppI18n.t(config, 'settings.account.login')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(AppConfigState config, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loadRequested = false;
                });
                _requestProfileLoad(ref.read(myOverviewControllerProvider));
              },
              child: Text(AppI18n.t(config, 'common.retry')),
            ),
          ],
        ),
      ),
    );
  }

  void _requestProfileLoad(MyOverviewState state) {
    if (_loadRequested || state.loading) {
      return;
    }
    _loadRequested = true;
    Future.microtask(
      () => ref.read(myOverviewControllerProvider.notifier).refresh(),
    );
  }

  void _initializeFields(MyProfile profile) {
    if (_fieldsInitialized) {
      return;
    }
    _fieldsInitialized = true;
    _originalAvatarUrl = profile.avatarUrl.trim();
    _nicknameController.text = profile.nickname;
    _avatarController.text = _originalAvatarUrl;
  }

  void _handleAvatarChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _validateNickname(AppConfigState config, String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) {
      return AppI18n.t(config, 'settings.profile.nickname.required');
    }
    if (nickname.runes.length > 31) {
      return AppI18n.t(config, 'settings.profile.nickname.length');
    }
    return null;
  }

  String? _validateAvatar(AppConfigState config, String? value) {
    final avatarUrl = value?.trim() ?? '';
    if (avatarUrl.isEmpty) {
      return _originalAvatarUrl.isEmpty
          ? null
          : AppI18n.t(config, 'settings.profile.avatar.clear_unsupported');
    }
    if (avatarUrl.runes.length > 2048) {
      return AppI18n.t(config, 'settings.profile.avatar.length');
    }
    final uri = Uri.tryParse(avatarUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return AppI18n.t(config, 'settings.profile.avatar.invalid');
    }
    return null;
  }

  Future<void> _submit(AppConfigState config) async {
    if (!_isLoggedIn(ref.read(appConfigProvider)) ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final nickname = _nicknameController.text.trim();
      final avatarUrl = _avatarController.text.trim();
      await ref
          .read(accountSettingsApiClientProvider)
          .updateProfile(
            nickname: nickname,
            avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
          );
      await ref.read(myOverviewControllerProvider.notifier).refresh();
      final refreshError = ref
          .read(myOverviewControllerProvider)
          .errorMessage
          ?.trim();
      if (refreshError?.isNotEmpty ?? false) {
        throw StateError(refreshError!);
      }
      if (!mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.t(config, 'settings.profile.saved'),
      );
      if (context.canPop()) {
        context.pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error, localeCode: config.localeCode) ??
            AppI18n.t(config, 'settings.profile.save_failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  bool _isLoggedIn(AppConfigState config) {
    return config.authToken?.trim().isNotEmpty ?? false;
  }

  void _openLogin(String redirect) {
    context.push(
      Uri(
        path: AppRoutes.login,
        queryParameters: <String, String>{'redirect': redirect},
      ).toString(),
    );
  }
}
