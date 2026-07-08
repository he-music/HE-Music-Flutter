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
import '../../domain/entities/qr_login_state.dart';
import '../providers/qr_login_providers.dart';

class QrLoginConfirmPage extends ConsumerWidget {
  const QrLoginConfirmPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final qrState = ref.watch(qrLoginControllerProvider);
    final theme = Theme.of(context);
    final hasToken = (config.authToken?.trim().isNotEmpty ?? false);
    final viewModel = _QrLoginConfirmViewModel.fromState(
      config: config,
      state: qrState,
      hasToken: hasToken,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'auth.qr.confirm_title')),
        leading: AppBackButton(onPressed: () => _handleBack(context)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: viewModel.accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        viewModel.icon,
                        size: 36,
                        color: viewModel.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    qrState.clientName.isEmpty
                        ? AppI18n.t(config, 'auth.qr.empty')
                        : qrState.clientName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (viewModel.detail?.trim().isNotEmpty ?? false) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: viewModel.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Text(
                        viewModel.detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: viewModel.accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: switch (viewModel.action) {
                      _QrLoginConfirmAction.login => FilledButton(
                        onPressed: () => _goToLogin(context),
                        child: Text(
                          AppI18n.t(config, 'auth.qr.confirm_need_login'),
                        ),
                      ),
                      _QrLoginConfirmAction.confirm => FilledButton(
                        onPressed: qrState.isBusy
                            ? null
                            : () => _confirm(context, ref),
                        child: Text(
                          AppI18n.t(config, 'auth.qr.confirm_submit'),
                        ),
                      ),
                      _QrLoginConfirmAction.backMy => FilledButton.tonal(
                        onPressed: () => _handleBack(context),
                        child: Text(
                          AppI18n.t(config, 'auth.qr.confirm_back_my'),
                        ),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(qrLoginControllerProvider.notifier)
          .confirmPendingSession();
      if (!context.mounted) {
        return;
      }
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.login.failed'),
      );
    }
  }

  void _goToLogin(BuildContext context) {
    context.go(
      Uri(
        path: AppRoutes.login,
        queryParameters: <String, String>{'redirect': AppRoutes.loginQrConfirm},
      ).toString(),
    );
  }

  void _handleBack(BuildContext context) {
    context.go(AppRoutes.homeMy);
  }
}

enum _QrLoginConfirmAction { login, confirm, backMy }

class _QrLoginConfirmViewModel {
  const _QrLoginConfirmViewModel({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.action,
    this.detail,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final String? detail;
  final _QrLoginConfirmAction action;

  factory _QrLoginConfirmViewModel.fromState({
    required AppConfigState config,
    required QrLoginState state,
    required bool hasToken,
  }) {
    final errorDetail = state.errorMessage?.trim();
    switch (state.status) {
      case QrLoginWorkflowStatus.scanned:
        return _QrLoginConfirmViewModel(
          icon: Icons.verified_user_rounded,
          accentColor: Colors.blue,
          title: AppI18n.t(config, 'auth.qr.confirm_status_scanned'),
          description: hasToken
              ? AppI18n.t(config, 'auth.qr.confirm_desc')
              : AppI18n.t(config, 'auth.qr.confirm_need_login'),
          detail: state.userHint.trim().isEmpty ? null : state.userHint.trim(),
          action: hasToken
              ? _QrLoginConfirmAction.confirm
              : _QrLoginConfirmAction.login,
        );
      case QrLoginWorkflowStatus.confirmed:
      case QrLoginWorkflowStatus.success:
        return _QrLoginConfirmViewModel(
          icon: Icons.task_alt_rounded,
          accentColor: Colors.green,
          title: AppI18n.t(config, 'auth.qr.confirm_status_success'),
          description: AppI18n.t(config, 'auth.qr.confirm_done'),
          action: _QrLoginConfirmAction.backMy,
        );
      case QrLoginWorkflowStatus.expired:
        return _QrLoginConfirmViewModel(
          icon: Icons.schedule_rounded,
          accentColor: Colors.orange,
          title: AppI18n.t(config, 'auth.qr.confirm_status_failed'),
          description: AppI18n.t(config, 'auth.qr.expired'),
          action: _QrLoginConfirmAction.backMy,
        );
      case QrLoginWorkflowStatus.cancelled:
        return _QrLoginConfirmViewModel(
          icon: Icons.block_rounded,
          accentColor: Colors.orange,
          title: AppI18n.t(config, 'auth.qr.confirm_status_failed'),
          description: AppI18n.t(config, 'auth.qr.cancelled'),
          action: _QrLoginConfirmAction.backMy,
        );
      case QrLoginWorkflowStatus.failure:
        return _QrLoginConfirmViewModel(
          icon: Icons.error_outline_rounded,
          accentColor: Colors.red,
          title: AppI18n.t(config, 'auth.qr.confirm_status_failed'),
          description: AppI18n.t(config, 'auth.qr.load_failed'),
          detail: errorDetail?.isEmpty ?? true ? null : errorDetail,
          action: _QrLoginConfirmAction.backMy,
        );
      case QrLoginWorkflowStatus.idle:
      case QrLoginWorkflowStatus.creating:
      case QrLoginWorkflowStatus.pending:
        return _QrLoginConfirmViewModel(
          icon: Icons.qr_code_2_rounded,
          accentColor: Colors.grey,
          title: AppI18n.t(config, 'auth.qr.empty'),
          description: AppI18n.t(config, 'auth.qr.confirm_status_failed'),
          action: _QrLoginConfirmAction.backMy,
        );
    }
  }
}
