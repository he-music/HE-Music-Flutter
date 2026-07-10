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
import '../../data/providers/account_settings_providers.dart';

class AccountPasswordPage extends ConsumerStatefulWidget {
  const AccountPasswordPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AccountPasswordPage> createState() =>
      _AccountPasswordPageState();
}

class _AccountPasswordPageState extends ConsumerState<AccountPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _submitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final content = _isLoggedIn(config)
        ? _buildForm(config)
        : _buildSignedOut(config);

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'settings.password.title')),
      ),
      body: content,
    );
  }

  Widget _buildForm(AppConfigState config) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: <Widget>[
              _buildPasswordField(
                key: const ValueKey<String>('account-password-old'),
                config: config,
                controller: _oldPasswordController,
                labelKey: 'settings.password.old',
                visible: _oldPasswordVisible,
                onToggle: () {
                  setState(() {
                    _oldPasswordVisible = !_oldPasswordVisible;
                  });
                },
                validator: (value) => _validatePassword(
                  config,
                  value,
                  lengthKey: 'settings.password.old.length',
                ),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                key: const ValueKey<String>('account-password-new'),
                config: config,
                controller: _newPasswordController,
                labelKey: 'settings.password.new',
                visible: _newPasswordVisible,
                onToggle: () {
                  setState(() {
                    _newPasswordVisible = !_newPasswordVisible;
                  });
                },
                validator: (value) => _validatePassword(
                  config,
                  value,
                  lengthKey: 'settings.password.new.length',
                ),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                key: const ValueKey<String>('account-password-confirm'),
                config: config,
                controller: _confirmPasswordController,
                labelKey: 'settings.password.confirm',
                visible: _confirmPasswordVisible,
                onToggle: () {
                  setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  });
                },
                validator: (value) {
                  final requiredError = _validatePassword(
                    config,
                    value,
                    lengthKey: 'settings.password.new.length',
                  );
                  if (requiredError != null) {
                    return requiredError;
                  }
                  if (value != _newPasswordController.text) {
                    return AppI18n.t(
                      config,
                      'settings.password.confirm.mismatch',
                    );
                  }
                  return null;
                },
                onSubmitted: (_) => _submit(config),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey<String>('account-password-submit'),
                onPressed: _submitting ? null : () => _submit(config),
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.password_rounded),
                label: Text(
                  AppI18n.t(
                    config,
                    _submitting
                        ? 'settings.password.saving'
                        : 'settings.password.save',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildPasswordField({
    required Key key,
    required AppConfigState config,
    required TextEditingController controller,
    required String labelKey,
    required bool visible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: AppI18n.t(config, labelKey),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: AppI18n.t(
            config,
            visible ? 'settings.password.hide' : 'settings.password.show',
          ),
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      validator: validator,
      onFieldSubmitted: onSubmitted,
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
              onPressed: () => _openLogin(AppRoutes.settingsPassword),
              icon: const Icon(Icons.login_rounded),
              label: Text(AppI18n.t(config, 'settings.account.login')),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePassword(
    AppConfigState config,
    String? value, {
    required String lengthKey,
  }) {
    if (value == null || value.isEmpty) {
      return AppI18n.t(config, 'settings.password.required');
    }
    if (value.runes.length < 6 || value.runes.length > 18) {
      return AppI18n.t(config, lengthKey);
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
      await ref
          .read(accountSettingsApiClientProvider)
          .updatePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.t(config, 'settings.password.saved'),
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
            AppI18n.t(config, 'settings.password.save_failed'),
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
